// TCDDownloadsViewController.m
#import "TCDDownloadsViewController.h"
#import "TCDBackgroundView.h"
#import "TCDAppItem.h"
#import "TCDDownloadRowView.h"
#import "TCDDownloadManager.h"

static const CGFloat kRowH = 56.0;

@interface TCDDownloadsViewController ()
@property (strong) NSView               *view;
@property (strong) NSScrollView         *scrollView;
@property (strong) NSView               *rowContainer;
@property (strong) NSTextField          *emptyLabel;
@property (strong) NSMutableArray       *rows;        // TCDDownloadRowView
@property (strong) NSMutableArray       *items;       // TCDAppItem
@end

@implementation TCDDownloadsViewController

- (instancetype)init
{
    self = [super init];
    if (!self) return nil;
    _rows  = [NSMutableArray array];
    _items = [NSMutableArray array];
    [self buildView];

    [[NSNotificationCenter defaultCenter]
        addObserver:self selector:@selector(progressUpdated:)
               name:TCDDownloadProgressNotification object:nil];
    [[NSNotificationCenter defaultCenter]
        addObserver:self selector:@selector(progressUpdated:)
               name:TCDDownloadFinishedNotification object:nil];
    return self;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

// ── View ─────────────────────────────────────────────────────────────────────

- (void)buildView
{
    // A local, because the controller's own -view is typed NSView * and
    // -backgroundColor only exists on TCDBackgroundView.
    TCDBackgroundView *v =
        [[TCDBackgroundView alloc] initWithFrame:NSMakeRect(0, 0, 772, 385)];
    v.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    v.backgroundColor = [NSColor colorWithCalibratedWhite:0.93 alpha:1];
    _view = v;

    // "Nothing here" placeholder
    _emptyLabel = [[NSTextField alloc] initWithFrame:
                   NSMakeRect(0, 160, 772, 40)];
    _emptyLabel.stringValue     = @"No downloads yet.";
    _emptyLabel.editable        = NO;
    _emptyLabel.selectable      = NO;
    _emptyLabel.bordered        = NO;
    _emptyLabel.drawsBackground = NO;
    _emptyLabel.alignment       = NSCenterTextAlignment;
    _emptyLabel.textColor       = [NSColor grayColor];
    _emptyLabel.font            = [NSFont systemFontOfSize:16];
    _emptyLabel.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin | NSViewMaxYMargin;
    [_view addSubview:_emptyLabel];

    // Scroll view that holds the rows
    _scrollView = [[NSScrollView alloc] initWithFrame:_view.bounds];
    _scrollView.autoresizingMask      = NSViewWidthSizable | NSViewHeightSizable;
    _scrollView.hasVerticalScroller   = YES;
    _scrollView.hasHorizontalScroller = NO;
    _scrollView.borderType            = NSNoBorder;
    _scrollView.backgroundColor       = [NSColor colorWithCalibratedWhite:0.93 alpha:1];
    _scrollView.hidden                = YES; // shown once first item arrives

    _rowContainer = [[NSView alloc] initWithFrame:_scrollView.bounds];
    [_scrollView setDocumentView:_rowContainer];
    [_view addSubview:_scrollView];
}

// ── Public ────────────────────────────────────────────────────────────────────

- (void)addDownloadItem:(TCDAppItem *)item
{
    // Don't add the same item twice
    if ([_items containsObject:item]) return;

    [_items addObject:item];

    TCDDownloadRowView *row = [[TCDDownloadRowView alloc] initWithItem:item];
    [_rows addObject:row];

    [self relayoutRows];

    _emptyLabel.hidden  = YES;
    _scrollView.hidden  = NO;
}

// ── Layout ────────────────────────────────────────────────────────────────────

- (void)relayoutRows
{
    CGFloat W         = NSWidth(_scrollView.bounds);
    NSInteger count   = (NSInteger)_rows.count;
    CGFloat totalH    = MAX(count * kRowH, NSHeight(_scrollView.bounds));

    _rowContainer.frame = NSMakeRect(0, 0, W, totalH);

    // Rows stacked top → bottom (Cocoa is bottom-up, so row 0 is at the top)
    for (NSInteger i = 0; i < count; i++) {
        TCDDownloadRowView *row = _rows[(NSUInteger)i];
        CGFloat y = totalH - (i + 1) * kRowH;
        row.frame = NSMakeRect(0, y, W, kRowH);
        if (!row.superview) [_rowContainer addSubview:row];
    }

    // Scroll to top so newest row is visible
    [_rowContainer scrollPoint:NSMakePoint(0, NSHeight(_rowContainer.bounds))];
}

// ── Notification ──────────────────────────────────────────────────────────────

- (void)progressUpdated:(NSNotification *)note
{
    TCDAppItem *item = (TCDAppItem *)note.object;
    NSInteger idx = (NSInteger)[_items indexOfObject:item];
    if (idx == NSNotFound) return;
    TCDDownloadRowView *row = _rows[(NSUInteger)idx];
    [row updateProgress];
}

@end
