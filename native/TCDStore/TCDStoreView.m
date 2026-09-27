//
//  TCDStoreView.m
//  TCD Store
//

#import "TCDStoreView.h"
#import "TCDTheme.h"

@interface TCDStoreView () <TCDSidebarDelegate, TCDStoreGridDelegate>
@property (nonatomic, strong) NSArray *allPackages;
@property (nonatomic, strong) NSArray *categories;     // NSString
@property (nonatomic, strong) NSArray *sourceItems;    // TCDPackage for the current route
@property (nonatomic, assign) TCDSidebarRoute route;
@property (nonatomic, copy)   NSString *section;
@property (nonatomic, copy)   NSString *query;
@property (nonatomic, strong) NSMutableArray *history;  // route/section pairs
@property (nonatomic, strong) NSScrollView *gridScroll;
@property (nonatomic, assign) BOOL restoringHistory;
@end

@implementation TCDStoreView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.history = [NSMutableArray array];
    self.route = TCDSidebarRouteFeatured;
    self.allPackages = @[];
    self.categories = @[];
    self.sourceItems = @[];

    self.sidebar = [[TCDSidebar alloc] initWithFrame:
        NSMakeRect(0.0, 0.0, [TCDTheme sidebarWidth], NSHeight(frame))];
    self.sidebar.delegate = self;
    [self addSubview:self.sidebar];

    self.grid = [[TCDStoreGrid alloc] initWithFrame:
        NSMakeRect([TCDTheme sidebarWidth], 0.0,
                   NSWidth(frame) - [TCDTheme sidebarWidth], NSHeight(frame))];
    self.grid.delegate = self;
    NSScrollView *gridScroll = [[NSScrollView alloc] initWithFrame:[self.grid frame]];
    [gridScroll setDocumentView:self.grid];
    [gridScroll setHasVerticalScroller:YES];
    [gridScroll setAutohidesScrollers:YES];
    [gridScroll setBorderType:NSNoBorder];
    [gridScroll setDrawsBackground:NO];
    [gridScroll setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self addSubview:gridScroll];
    self.gridScroll = gridScroll;

    [self setFrameSize:frame];
    return self;
}

- (BOOL)isFlipped { return YES; }

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    CGFloat sw = [TCDTheme sidebarWidth];
    [self.sidebar setFrame:NSMakeRect(0.0, 0.0, sw, NSHeight(newSize))];
    [self.gridScroll setFrame:NSMakeRect(sw, 0.0, NSWidth(newSize) - sw, NSHeight(newSize))];
    [self.grid setFrameSize:NSMakeSize(NSWidth(newSize) - sw, NSHeight([self.grid frame]))];
}

#pragma mark - data

- (void)setPackages:(NSArray *)packages
        categories:(NSArray *)categories
         sourceCount:(NSUInteger)sourceCount {
    self.allPackages = packages ?: @[];
    self.categories = categories ?: @[];

    self.sidebar.packages = self.allPackages;
    self.sidebar.sections = self.categories;
    self.sidebar.sourceCount = sourceCount;
    self.sidebar.installedCount = [self countWhere:^BOOL(TCDPackage *p) { return p.installed; }];
    self.sidebar.updatesCount   = [self countWhere:^BOOL(TCDPackage *p) { return p.hasUpdate; }];
    [self.sidebar reload];
    [self recompute];
}

- (NSUInteger)countWhere:(BOOL (^)(TCDPackage *))test {
    NSUInteger n = 0;
    for (TCDPackage *p in self.allPackages) if (test(p)) n++;
    return n;
}

- (void)reload { [self.sidebar reload]; [self recompute]; }

- (void)applyRoute:(TCDSidebarRoute)route section:(NSString *)section {
    if (!self.restoringHistory &&
        (self.route != route || ![self.section isEqualToString:section])) {
        [self.history addObject:@{ @"r": @(route), @"s": section ?: [NSNull null] }];
    }
    self.route = route;
    self.section = section;
    self.query = nil;
    self.sidebar.activeRoute = route;
    self.sidebar.activeSection = section;
    [self.sidebar reload];
    [self recompute];
}

- (void)applySearch:(NSString *)query {
    self.query = query;
    [self recompute];
}

- (BOOL)canGoBack { return self.history.count > 0; }

- (void)goBack {
    if (!self.history.count) return;
    NSDictionary *prev = self.history.lastObject;
    [self.history removeLastObject];
    self.restoringHistory = YES;
    [self applyRoute:([prev[@"r"] integerValue])
             section:(prev[@"s"] == [NSNull null] ? nil : prev[@"s"])];
    self.restoringHistory = NO;
}

#pragma mark - the current slice

- (void)recompute {
    NSArray *items = nil;
    NSString *empty = nil;

    if (self.query.length) {
        // search is case-insensitive and matches name, identifier and summary
        NSMutableArray *hits = [NSMutableArray array];
        for (TCDPackage *p in self.allPackages) {
            NSString *n = p.name.lowercaseString;
            if ([n containsString:self.query.lowercaseString] ||
                [p.identifier.lowercaseString containsString:self.query.lowercaseString] ||
                [(p.packageSummary ?: @"") containsString:self.query.lowercaseString])
                [hits addObject:p];
        }
        items = hits;
        if (!items.count) empty = @"No packages match that search.";
    } else {
        switch (self.route) {
            case TCDSidebarRouteFeatured: {
                // "featured" is a curated-feeling slice: anything the source
                // marks as a system component or that is simply new
                NSMutableArray *f = [NSMutableArray array];
                for (TCDPackage *p in self.allPackages) if (!p.installed) [f addObject:p];
                items = f;
                if (!items.count) empty = @"Everything is installed. Nothing new to show.";
                break;
            }
            case TCDSidebarRouteUpdates:
                items = [self allPackagesWhere:^BOOL(TCDPackage *p) { return p.hasUpdate; }];
                if (!items.count) empty = @"No updates. Your software is current.";
                break;
            case TCDSidebarRouteInstalled:
                items = [self allPackagesWhere:^BOOL(TCDPackage *p) { return p.installed; }];
                if (!items.count) empty = @"Nothing is installed yet.";
                break;
            case TCDSidebarRouteSources:
                // the source list is a screen of its own in the full port; the
                // grid stands in for it here with the packages each source owns
                items = self.allPackages;
                if (!items.count) empty = @"No sources are configured.";
                break;
            case TCDSidebarRouteSettings:
                items = @[];
                empty = @"Settings is presented as a sheet.";
                break;
            case TCDSidebarRouteCategory: {
                NSString *want = self.section;
                items = [self allPackagesWhere:^BOOL(TCDPackage *p) {
                    return [p.section isEqualToString:want];
                }];
                if (!items.count) empty = @"That category is empty.";
                break;
            }
        }
    }

    self.sourceItems = items ?: @[];
    self.grid.packages = self.sourceItems;
    [self.grid showEmptyStateWithMessage:empty];
}

- (NSArray *)allPackagesWhere:(BOOL (^)(TCDPackage *))test {
    NSMutableArray *out = [NSMutableArray array];
    for (TCDPackage *p in self.allPackages) if (test(p)) [out addObject:p];
    return out;
}

#pragma mark - TCDSidebarDelegate

- (void)sidebar:(TCDSidebar *)sidebar didSelectRoute:(TCDSidebarRoute)route
                                          section:(NSString *)section {
    if ([self.delegate respondsToSelector:@selector(storeViewDidSelectRoute:route:section:)])
        [self.delegate storeView:self didSelectRoute:route section:section];
}

- (void)sidebar:(TCDSidebar *)sidebar didSelectDensity:(TCDIconDensity)density {
    self.grid.density = density;   // the grid tells its own delegate; the grid
                                   // is the thing that actually reflows
    if ([self.delegate respondsToSelector:@selector(storeView:didSelectDensity:)])
        [self.delegate storeView:self didSelectDensity:density];
}

#pragma mark - TCDStoreGridDelegate

- (void)grid:(TCDStoreGrid *)grid didSelectPackage:(TCDPackage *)pkg {
    if ([self.delegate respondsToSelector:@selector(storeView:didSelectPackage:)])
        [self.delegate storeView:self didSelectPackage:pkg];
}

- (void)grid:(TCDStoreGrid *)grid didTapVersionsForPackage:(TCDPackage *)pkg
                                              atPoint:(NSPoint)point {
    (void)point;
    if ([self.delegate respondsToSelector:@selector(storeView:didTapVersionsForPackage:)])
        [self.delegate storeView:self didTapVersionsForPackage:pkg];
}

- (void)grid:(TCDStoreGrid *)grid didChangeDensity:(TCDIconDensity)density {
    (void)grid; (void)density;
}

@end
