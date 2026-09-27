//
//  TCDAeroBar.m
//  TCD Store
//
//  Every control here is a stock one: NSSegmentedControl for Store | Downloads,
//  NSSearchField for the search, plain NSButtons for the rest. The first
//  version drew its own pills, its own round buttons and its own search well,
//  and it looked wrong — hand-rolled skeuomorphism never quite matches the real
//  thing, because the real thing has correct hairlines, correct pressed states
//  and a 1px border that sits exactly on the pixel grid.
//
//  What is left hand-drawn is the background: a black bar with a vertical ramp.
//  That is a surface, not a control, and it is the one part of the design that
//  has no stock equivalent.
//
//  10.7 notes:
//    · no NSStackView, so subviews are positioned by frame in -layoutBar
//    · NSSegmentedControl carries the Store | Downloads pair
//

#import "TCDAeroBar.h"
#import "TCDTheme.h"

@interface TCDAeroBar ()
@property (nonatomic, strong) NSTextField *wordmark;
@property (nonatomic, strong) NSSegmentedControl *viewSwitch;
@property (nonatomic, strong) NSSearchField *searchField;
@property (nonatomic, strong) NSButton *backButton;
@property (nonatomic, strong) NSButton *refreshButton;
@property (nonatomic, strong) NSButton *updateAllButton;
@end

@implementation TCDAeroBar

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    [self buildBar];
    return self;
}

#pragma mark - building

/* No geometry here. Every frame is set by -layoutBar once the views exist, so
   there is exactly one place to change when the bar is resized. */
- (void)buildBar {
    // ---- line one: wordmark left, Store | Downloads right ----
    self.wordmark = [[NSTextField alloc] initWithFrame:NSMakeRect(14.0, 0.0, 200.0, 18.0)];
    [self.wordmark setStringValue:@"TCD store"];
    [self.wordmark setBezeled:NO];
    [self.wordmark setDrawsBackground:NO];
    [self.wordmark setEditable:NO];
    [self.wordmark setSelectable:NO];
    [self.wordmark setFont:[TCDTheme boldFontOfSize:14.0]];
    [[self.wordmark cell] setTextColor:[TCDTheme white]];
    [self addSubview:self.wordmark];

    self.viewSwitch = [[NSSegmentedControl alloc]
        initWithFrame:NSMakeRect(0.0, 0.0, 180.0, 24.0)];
    // NSSegmentStyleRounded is the Snow Leopard capsule; the textured styles
    // are the older Aqua look and read as period detail rather than restraint
    [self.viewSwitch setSegmentStyle:NSSegmentStyleRounded];
    [self.viewSwitch setSegmentCount:2];
    [self.viewSwitch setLabel:@"Store" forSegment:0];
    [self.viewSwitch setLabel:@"Downloads" forSegment:1];
    [self.viewSwitch setTrackingMode:NSSegmentSwitchTrackingSelectOne];
    [self.viewSwitch setSelectedSegment:0];
    [self.viewSwitch setTarget:self];
    [self.viewSwitch setAction:@selector(viewSwitchChanged:)];
    [self addSubview:self.viewSwitch];

    // ---- line two: the search field, then the buttons ----
    self.searchField = [[NSSearchField alloc]
        initWithFrame:NSMakeRect(18.0, 0.0, 260.0, 22.0)];
    [self.searchField setTarget:self];
    [self.searchField setAction:@selector(searchFieldChanged:)];
    [[self.searchField cell] setPlaceholderString:@"search packages"];
    [self addSubview:self.searchField];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(searchFieldChanged:)
                                                 name:NSControlTextDidChangeNotification
                                               object:self.searchField];

    // Titles rather than drawn glyphs: the stock bezel comes with a correct
    // pressed and disabled look, and a label reads without a tooltip.
    self.backButton = [self buttonWithTitle:@"Back"
                                  action:@selector(backClicked:)
                                    width:54.0];
    self.refreshButton = [self buttonWithTitle:@"Refresh"
                                      action:@selector(refreshClicked:)
                                        width:68.0];
    [self addSubview:self.backButton];
    [self addSubview:self.refreshButton];

    self.updateAllButton = [self buttonWithTitle:@"Update All"
                                        action:@selector(updateAllClicked:)
                                          width:92.0];
    [self.updateAllButton setHidden:YES];
    [self addSubview:self.updateAllButton];

    self.activeView = TCDAeroViewStore;
    [self layoutBar];
}

- (NSButton *)buttonWithTitle:(NSString *)title action:(SEL)action width:(CGFloat)width {
    NSButton *b = [[NSButton alloc]
        initWithFrame:NSMakeRect(0.0, 0.0, width, 22.0)];
    [b setTitle:title];
    [b setBezelStyle:NSRoundedBezelStyle];
    [b setFont:[TCDTheme uiFontOfSize:12.0]];
    [b setTarget:self];
    [b setAction:action];
    return b;
}

#pragma mark - painting

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect b = [self bounds];

    // A surface, not a control: one black block with a vertical ramp, light at
    // the top, dark at the bottom, and a 1px top highlight and bottom edge.
    [TCDTheme fillVerticalGradient:b
        stops:@[[TCDTheme barLineOneTop],   @(0.0),
                [TCDTheme barLineOneMid],   @(0.26),
                [TCDTheme barBase],         @(0.47),
                [TCDTheme barDivide],       @(0.53),
                [TCDTheme barLineTwoBottom], @(1.0)]];

    [[TCDTheme barInnerHighlight] setFill];
    NSRectFill(NSMakeRect(0.0, NSMaxY(b) - 1.0, NSWidth(b), 1.0));

    [[TCDTheme barEdge] setFill];
    NSRectFill(NSMakeRect(0.0, 0.0, NSWidth(b), 1.0));
}

#pragma mark - layout

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [self layoutBar];
    [self setNeedsDisplay:YES];
}

- (void)layoutBar {
    CGFloat w = NSWidth([self bounds]);
    CGFloat h1 = [TCDTheme barLineOneHeight];
    CGFloat h2 = [TCDTheme barLineTwoHeight];
    CGFloat right = w - 14.0;

    [self.wordmark setFrameOrigin:NSMakePoint(14.0, h2 + (h1 - 18.0) / 2.0)];

    CGFloat switchW = 180.0;
    [self.viewSwitch setFrame:NSMakeRect(right - switchW,
                                         h2 + (h1 - 24.0) / 2.0,
                                         switchW, 24.0)];

    CGFloat y = (h2 - 22.0) / 2.0;
    CGFloat x = right;
    x -= NSWidth([self.updateAllButton frame]);
    [self.updateAllButton setFrameOrigin:NSMakePoint(x, y)];
    x -= 8.0;
    x -= NSWidth([self.refreshButton frame]);
    [self.refreshButton setFrameOrigin:NSMakePoint(x, y)];
    x -= 8.0;
    x -= NSWidth([self.backButton frame]);
    [self.backButton setFrameOrigin:NSMakePoint(x, y)];

    // The search field takes whatever is left, so it grows with the window
    CGFloat fieldRight = x - 10.0;
    NSRect r = [self.searchField frame];
    r.origin.y = y;
    r.size.width = MAX(120.0, fieldRight - 18.0);
    [self.searchField setFrame:r];
}

#pragma mark - state

/* A segmented control has nowhere to hang a badge, so a non-zero count goes
   into the segment label instead. Zero puts the plain label back rather than
   leaving a stale "Downloads (3)" around. */
- (void)setDownloadCount:(NSUInteger)downloadCount {
    _downloadCount = downloadCount;
    [self.viewSwitch setLabel:(downloadCount
                          ? [NSString stringWithFormat:@"Downloads (%lu)",
                             (unsigned long)downloadCount]
                          : @"Downloads")
                    forSegment:1];
    [self layoutBar];
}

- (void)setActiveView:(TCDAeroView)activeView {
    _activeView = activeView;
    [self.viewSwitch setSelectedSegment:(activeView == TCDAeroViewStore) ? 0 : 1];
}

- (void)setUpdateAllVisible:(BOOL)visible {
    _updateAllVisible = visible;
    [self.updateAllButton setHidden:!visible];
    [self layoutBar];
}

- (void)focusSearch { [self.window makeFirstResponder:self.searchField]; }

- (void)clearSearch {
    [self.searchField setStringValue:@""];
    [self searchFieldChanged:self.searchField];
}

#pragma mark - actions

- (void)viewSwitchChanged:(id)sender {
    [self setActiveView:[sender selectedSegment] == 0 ? TCDAeroViewStore
                                                     : TCDAeroViewDownloads];
    if ([self.delegate respondsToSelector:@selector(aeroBar:didSelectView:)])
        [self.delegate aeroBar:self didSelectView:self.activeView];
}

- (void)searchFieldChanged:(id)sender {
    (void)sender;
    if ([self.delegate respondsToSelector:@selector(aeroBar:didChangeSearch:)])
        [self.delegate aeroBar:self didChangeSearch:self.searchField.stringValue];
}

- (void)backClicked:(id)sender {
    (void)sender;
    if ([self.delegate respondsToSelector:@selector(aeroBarDidGoBack:)])
        [self.delegate aeroBarDidGoBack:self];
}

- (void)refreshClicked:(id)sender {
    (void)sender;
    if ([self.delegate respondsToSelector:@selector(aeroBarDidRefresh:)])
        [self.delegate aeroBarDidRefresh:self];
}

- (void)updateAllClicked:(id)sender {
    (void)sender;
    if ([self.delegate respondsToSelector:@selector(aeroBarDidUpdateAll:)])
        [self.delegate aeroBarDidUpdateAll:self];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
