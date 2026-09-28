// TCDStoreViewController.m
#import "TCDStoreViewController.h"
#import "TCDAppItem.h"
#import "TCDAppCardView.h"
#import "TCDCatalogue.h"
#import "TCDCatalogueManager.h"
#import "TCDDownloadManager.h"
#import "TCDDownloadsViewController.h"
#import "TCDHeaderView.h"

static const CGFloat kCardW    = 160.0;
static const CGFloat kCardH    = 210.0;
static const CGFloat kCardGapX =  12.0;
static const CGFloat kCardGapY =  14.0;
static const CGFloat kGridPad  =  14.0;
static const CGFloat kSidebarW = 150.0;

@interface TCDStoreViewController () <TCDAppCardViewDelegate>
@property (strong) NSView         *view;
@property (strong) NSScrollView   *gridScroll;
@property (strong) NSView         *gridCanvas;
@property (strong) NSMutableArray *allItems;
@property (strong) NSMutableArray *shownItems;
@property (strong) NSString       *activeCategory;
@property (strong) NSString       *searchQuery;
@property (assign) NSInteger       targetColumns;
@end

@implementation TCDStoreViewController

- (instancetype)init
{
    self = [super init];
    if (!self) return nil;
    _allItems       = [[TCDCatalogue allItems] mutableCopy];
    _shownItems     = [_allItems mutableCopy];
    _activeCategory = @"All";
    _searchQuery    = @"";
    _targetColumns  = 5;
    [self buildView];

    [[NSNotificationCenter defaultCenter]
        addObserver:self selector:@selector(gridColumnsChanged:)
               name:TCDGridColumnsChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter]
        addObserver:self selector:@selector(catalogueChanged:)
               name:TCDCatalogueDidChangeNotification object:nil];
    return self;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)buildView
{
    _view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 750, 492)];
    _view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    _gridScroll = [[NSScrollView alloc] initWithFrame:_view.bounds];
    _gridScroll.autoresizingMask      = NSViewWidthSizable | NSViewHeightSizable;
    _gridScroll.hasVerticalScroller   = YES;
    _gridScroll.hasHorizontalScroller = NO;
    _gridScroll.borderType            = NSNoBorder;
    _gridScroll.backgroundColor       =
        [NSColor colorWithCalibratedWhite:0.93 alpha:1];
    _gridCanvas = [[NSView alloc] initWithFrame:_gridScroll.bounds];
    [_gridScroll setDocumentView:_gridCanvas];
    [_view addSubview:_gridScroll];
    [self layoutCards];
}

- (void)layoutCards
{
    for (NSView *v in [_gridCanvas.subviews copy]) [v removeFromSuperview];

    CGFloat visW      = NSWidth(_gridScroll.bounds);
    NSInteger cols    = _targetColumns;
    NSInteger count   = (NSInteger)_shownItems.count;
    NSInteger rows    = count ? (count + cols - 1) / cols : 0;
    CGFloat   canvasH = MAX(rows*(kCardH+kCardGapY) + kGridPad*2,
                            NSHeight(_gridScroll.bounds));
    _gridCanvas.frame = NSMakeRect(0, 0, visW, canvasH);

    CGFloat blockW  = cols*kCardW + (cols-1)*kCardGapX;
    CGFloat offsetX = MAX(kGridPad, (visW - blockW) / 2.0);

    for (NSInteger i = 0; i < count; i++) {
        NSInteger col = i % cols, row = i / cols;
        CGFloat x = offsetX + col*(kCardW+kCardGapX);
        CGFloat y = canvasH - kGridPad - (row+1)*kCardH - row*kCardGapY;
        TCDAppItem     *item = _shownItems[(NSUInteger)i];
        TCDAppCardView *card = [[TCDAppCardView alloc] initWithItem:item];
        card.frame    = NSMakeRect(x, y, kCardW, kCardH);
        card.delegate = self;
        [_gridCanvas addSubview:card];
    }
    [_gridCanvas scrollPoint:NSMakePoint(0, NSHeight(_gridCanvas.bounds))];
}

- (void)enforceMinWindowWidth
{
    NSWindow *win = _view.window;
    if (!win) return;
    CGFloat minW = kSidebarW + kGridPad*2
                   + _targetColumns*(kCardW+kCardGapX) - kCardGapX;
    win.minSize = NSMakeSize(minW, win.minSize.height);
}

- (void)gridColumnsChanged:(NSNotification *)note
{
    _targetColumns = [(NSNumber *)note.object integerValue];
    [self enforceMinWindowWidth];
    [self layoutCards];
}

// Reload everything when catalogue is replaced by an import
- (void)catalogueChanged:(NSNotification *)note
{
    _allItems       = [[TCDCatalogue allItems] mutableCopy];
    _activeCategory = @"All";
    _searchQuery    = @"";
    [self applyFilter];
}

- (void)filterByCategory:(NSString *)category
{
    _activeCategory = category ?: @"All";
    [self applyFilter];
}

- (void)filterBySearch:(NSString *)query
{
    _searchQuery = query ?: @"";
    [self applyFilter];
}

- (void)applyFilter
{
    NSString *q = [_searchQuery stringByTrimmingCharactersInSet:
                   [NSCharacterSet whitespaceCharacterSet]];
    _shownItems = [NSMutableArray array];
    for (TCDAppItem *item in _allItems) {
        if (![_activeCategory isEqualToString:@"All"] &&
            ![item.category isEqualToString:_activeCategory]) continue;
        if (q.length > 0 &&
            [item.name rangeOfString:q
                             options:NSCaseInsensitiveSearch].location == NSNotFound)
            continue;
        [_shownItems addObject:item];
    }
    [self layoutCards];
}

- (void)cardViewDidRequestDownload:(TCDAppItem *)item version:(NSString *)version
{
    item.selectedVersion = version;
    [_downloadsVC addDownloadItem:item];
    [[TCDDownloadManager sharedManager] startDownload:item];
}

@end
