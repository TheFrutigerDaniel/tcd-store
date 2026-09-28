// TCDSidebarView.m
#import "TCDSidebarView.h"
#import "TCDCatalogue.h"
#import "TCDBackgroundView.h"
#import "TCDTintButton.h"
#import "TCDAppItem.h"
#import "TCDDownloadManager.h"
#import "TCDStoreViewController.h"
#import "TCDDownloadsViewController.h"

static const CGFloat kSidebarW  = 150.0;
static const CGFloat kBtnH      =  30.0;
static const CGFloat kBtnGap    =   1.0;
static const CGFloat kDLBtnH    =  34.0;
static const CGFloat kStatusH   =  26.0;
static const CGFloat kBottomPad =   6.0;

@interface TCDSidebarView ()
// The scrollable area hosts search + category buttons
@property (strong) NSScrollView   *scrollView;
@property (strong) NSView         *scrollCanvas;
@property (strong) NSSearchField  *searchField;
@property (strong) NSMutableArray *categoryButtons;
// Fixed bottom strip (never scrolls)
@property (strong) TCDBackgroundView *bottomStrip;
@property (strong) TCDTintButton     *downloadsButton;
@property (strong) NSTextField    *statusLabel;
@property (strong) NSString       *activeCategory;
@end

@implementation TCDSidebarView

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _activeCategory  = @"All";
    _categoryButtons = [NSMutableArray array];
    [self buildSubviews];

    for (NSString *name in @[TCDDownloadProgressNotification,
                              TCDDownloadFinishedNotification,
                              TCDDownloadCancelledNotification,
                              TCDDownloadFailedNotification]) {
        [[NSNotificationCenter defaultCenter]
            addObserver:self selector:@selector(downloadActivity:)
                   name:name object:nil];
    }
    return self;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

// ── Build ─────────────────────────────────────────────────────────────────────

- (void)buildSubviews
{
    CGFloat H = NSHeight(self.bounds);
    CGFloat W = kSidebarW;

    // ── Fixed bottom strip ────────────────────────────────────────────────
    // Height: Downloads button + status label + padding
    CGFloat stripH = kDLBtnH + kStatusH + kBottomPad * 2;
    _bottomStrip = [TCDBackgroundView viewWithFrame:NSMakeRect(0, 0, W, stripH)
                                            color:[NSColor colorWithCalibratedWhite:0.86 alpha:1]];
    _bottomStrip.autoresizingMask = NSViewWidthSizable; // stick to bottom

    // Status label
    _statusLabel = [[NSTextField alloc]
        initWithFrame:NSMakeRect(4, kBottomPad, W - 8, kStatusH)];
    _statusLabel.editable = _statusLabel.selectable =
    _statusLabel.bordered = _statusLabel.drawsBackground = NO;
    _statusLabel.font      = [NSFont systemFontOfSize:9];
    _statusLabel.textColor = [NSColor darkGrayColor];
    _statusLabel.alignment = NSCenterTextAlignment;
    _statusLabel.stringValue = @"";
    [_bottomStrip addSubview:_statusLabel];

    // Downloads button sits above status label
    CGFloat dlY = kBottomPad + kStatusH + kBtnGap;
    _downloadsButton = [self makeSidebarBtn:@"⬇  Downloads"
                                      frame:NSMakeRect(0, dlY, W, kDLBtnH)
                                       bold:YES];
    _downloadsButton.tintColor = [NSColor colorWithCalibratedWhite:0.76 alpha:1];
    _downloadsButton.action = @selector(downloadsPressed:);
    [_bottomStrip addSubview:_downloadsButton];

    // Top separator line of the strip
    TCDBackgroundView *stripSep =
        [TCDBackgroundView viewWithFrame:NSMakeRect(0, stripH - 1, W, 1)
                                 color:[NSColor colorWithCalibratedWhite:0.70 alpha:1]];
    [_bottomStrip addSubview:stripSep];
    [self addSubview:_bottomStrip];

    // ── Scrollable area (search + categories) ─────────────────────────────
    CGFloat scrollH = H - stripH;
    _scrollView = [[NSScrollView alloc]
        initWithFrame:NSMakeRect(0, stripH, W, scrollH)];
    _scrollView.autoresizingMask      = NSViewWidthSizable | NSViewHeightSizable;
    _scrollView.hasVerticalScroller   = YES;
    _scrollView.hasHorizontalScroller = NO;
    _scrollView.borderType            = NSNoBorder;
    _scrollView.backgroundColor       =
        [NSColor colorWithCalibratedWhite:0.86 alpha:1];
    // Hide scroller visually — it's just there for overflow safety
    _scrollView.autohidesScrollers = YES;

    // Canvas height: search field + all category buttons
    NSArray *cats   = [TCDCatalogue categories];
    CGFloat sfH     = 22, sfPad = 8;
    CGFloat canvasH = sfH + sfPad*2 + (CGFloat)cats.count * (kBtnH + kBtnGap);
    canvasH = MAX(canvasH, scrollH); // at least fill visible area

    _scrollCanvas = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, W, canvasH)];

    // Search field — at the top of the canvas (Cocoa: high Y = top)
    _searchField = [[NSSearchField alloc]
        initWithFrame:NSMakeRect(sfPad, canvasH - sfH - sfPad,
                                 W - sfPad*2, sfH)];
    _searchField.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    _searchField.target = self;
    _searchField.action = @selector(searchChanged:);
    ((NSSearchFieldCell *)_searchField.cell).placeholderString = @"Search…";
    [_scrollCanvas addSubview:_searchField];

    // Category buttons below search
    CGFloat btnY = canvasH - sfH - sfPad*2 - kBtnH;
    for (NSString *cat in cats) {
        TCDTintButton *btn = [self makeSidebarBtn:cat
                                       frame:NSMakeRect(0, btnY, W, kBtnH)
                                        bold:NO];
        btn.action = @selector(categoryPressed:);
        [_categoryButtons addObject:btn];
        [_scrollCanvas addSubview:btn];
        btnY -= (kBtnH + kBtnGap);
    }
    [self highlightCategory:@"All"];

    [_scrollView setDocumentView:_scrollCanvas];
    [self addSubview:_scrollView];

    // Right separator (full height)
    TCDBackgroundView *sep =
        [TCDBackgroundView viewWithFrame:NSMakeRect(W - 1, 0, 1, H)
                                 color:[NSColor colorWithCalibratedWhite:0.70 alpha:1]];
    sep.autoresizingMask = NSViewHeightSizable | NSViewMinXMargin;
    [self addSubview:sep];
}

// ── Drawing ───────────────────────────────────────────────────────────────────

- (void)drawRect:(NSRect)dirtyRect
{
    [[NSColor colorWithCalibratedWhite:0.86 alpha:1] setFill];
    NSRectFill(self.bounds);
}

// ── Button factory ────────────────────────────────────────────────────────────

- (TCDTintButton *)makeSidebarBtn:(NSString *)title
                                frame:(NSRect)frame
                                 bold:(BOOL)bold
{
    TCDTintButton *btn = [[TCDTintButton alloc] initWithFrame:frame];
    btn.bezelStyle = NSShadowlessSquareBezelStyle;
    btn.buttonType = NSMomentaryLightButton;
    btn.bordered   = NO;
    btn.target     = self;
    [self styleButton:btn title:title bold:bold];
    return btn;
}

- (void)styleButton:(NSButton *)btn title:(NSString *)title bold:(BOOL)bold
{
    NSFont *f = bold ? [NSFont boldSystemFontOfSize:12]
                     : [NSFont systemFontOfSize:12];
    NSMutableAttributedString *as = [[NSMutableAttributedString alloc]
        initWithString:[NSString stringWithFormat:@"  %@", title]];
    [as addAttribute:NSFontAttributeName value:f range:NSMakeRange(0, as.length)];
    btn.attributedTitle = as;
}

- (void)highlightCategory:(NSString *)category
{
    NSArray *cats = [TCDCatalogue categories];
    for (NSUInteger i = 0; i < _categoryButtons.count; i++) {
        TCDTintButton *btn = _categoryButtons[i];
        NSString *cat = cats[i];
        BOOL on = [cat isEqualToString:category];
        btn.tintColor = on
            ? [NSColor colorWithCalibratedWhite:0.74 alpha:1]
            : [NSColor clearColor];
        [self styleButton:btn title:cat bold:on];
    }
}

// ── Download status ───────────────────────────────────────────────────────────

- (void)downloadActivity:(NSNotification *)note
{
    NSInteger active = [[TCDDownloadManager sharedManager] activeDownloadCount];
    if (active > 0) {
        CGFloat p = [[TCDDownloadManager sharedManager] totalProgress];
        _statusLabel.stringValue =
            [NSString stringWithFormat:@"Downloading… %d%%", (int)(p * 100)];
        _statusLabel.textColor = [NSColor darkGrayColor];
    } else {
        BOOL anyDone = NO;
        for (TCDAppItem *item in [TCDCatalogue allItems]) {
            if (item.downloadState == TCDDownloadStateDone) { anyDone = YES; break; }
        }
        _statusLabel.stringValue = anyDone ? @"Complete!" : @"";
        _statusLabel.textColor   = anyDone
            ? [NSColor colorWithCalibratedRed:0.1 green:0.55 blue:0.1 alpha:1]
            : [NSColor darkGrayColor];
    }
}

// ── Actions ───────────────────────────────────────────────────────────────────

- (void)categoryPressed:(NSButton *)sender
{
    [_tabView selectTabViewItemAtIndex:0];
    NSArray *cats = [TCDCatalogue categories];
    NSUInteger idx = [_categoryButtons indexOfObject:sender];
    if (idx == NSNotFound) return;
    _activeCategory = cats[idx];
    [self highlightCategory:_activeCategory];
    [_storeVC filterByCategory:_activeCategory];
}

- (void)searchChanged:(id)sender
{
    [_tabView selectTabViewItemAtIndex:0];
    [_storeVC filterBySearch:[_searchField stringValue]];
}

- (void)downloadsPressed:(id)sender
{
    [_tabView selectTabViewItemAtIndex:1];
}

@end
