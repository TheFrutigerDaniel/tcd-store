//
//  TCDStoreGrid.m
//  TCD Store
//

#import "TCDStoreGrid.h"
#import "TCDTheme.h"

// Cocoa.h does not pull this one in on the 10.9 SDK
#import <AppKit/NSCollectionView.h>

#pragma mark - the version triangle

/* A real button, so the hover, the press and the cursor all come from AppKit.
   Only the face is drawn, because there is no stock control that looks like
   the Cydia version disclosure. */
@interface TCDVersionCaret : NSButton
@property (nonatomic, weak) TCDPackage *package;
@end

@implementation TCDVersionCaret

- (void)drawRect:(NSRect)dirty {
    (void)dirty;
    CGFloat side = NSWidth([self bounds]);
    if (side < 6.0) return;

    NSRect circle = NSInsetRect([self bounds], 0.5, 0.5);
    NSBezierPath *c = [NSBezierPath bezierPathWithOvalInRect:circle];
    [[TCDTheme caretBase] setFill];
    [c fill];
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.35] setStroke];
    [c setLineWidth:1.0];
    [c stroke];

    // the white triangle, pointing up
    CGFloat cx = NSMidX(circle), cy = NSMidY(circle), w = side * 0.26;
    NSBezierPath *tri = [NSBezierPath bezierPath];
    [tri moveToPoint:NSMakePoint(cx - w, cy + w * 0.55)];
    [tri lineToPoint:NSMakePoint(cx + w, cy + w * 0.55)];
    [tri lineToPoint:NSMakePoint(cx, cy - w * 0.7)];
    [tri closePath];
    [[NSColor whiteColor] setFill];
    [tri fill];
}

@end

#pragma mark - the tile

@interface TCDTileView : NSView
@property (nonatomic, strong) TCDPackage *package;
@property (nonatomic, assign) CGFloat iconSize;
@property (nonatomic, assign) BOOL compact;
@end

@implementation TCDTileView

/* No artwork ships with the demo source, so the icon slot draws a flat
   placeholder. It is deliberately plain: a grey plate that says "there is no
   icon here" rather than inventing artwork. */
- (void)drawIconPlaceholderInRect:(NSRect)icon {
    NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:icon
                                                       xRadius:NSWidth(icon) * 0.21
                                                       yRadius:NSWidth(icon) * 0.21];
    [[NSColor colorWithCalibratedWhite:0.62 alpha:1.0] setFill];
    [p fill];
    [[NSColor colorWithCalibratedWhite:0.52 alpha:1.0] setStroke];
    [p setLineWidth:1.0];
    [p stroke];
}

- (void)layout {
    NSRect b = [self bounds];
    CGFloat side = self.iconSize;
    CGFloat pad = self.compact ? 10.0 : 14.0;

    NSRect icon = NSMakeRect(NSMidX(b) - side / 2.0,
                             NSMaxY(b) - pad - side, side, side);
    [self drawIconPlaceholderInRect:icon];

    NSRect name = NSMakeRect(4.0, NSMinY(icon) - (self.compact ? 15.0 : 17.0),
                             NSWidth(b) - 8.0, 15.0);
    NSRect sub = NSMakeRect(4.0, NSMinY(name) - 12.0, NSWidth(b) - 8.0, 13.0);

    NSMutableParagraphStyle *centre = [[NSMutableParagraphStyle alloc] init];
    [centre setAlignment:NSCenterTextAlignment];
    [centre setLineBreakMode:NSLineBreakByTruncatingTail];

    NSDictionary *nameAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
        [TCDTheme boldFontOfSize:(self.compact ? 11.0 : 12.0)], NSFontAttributeName,
        [TCDTheme ink],             NSForegroundColorAttributeName,
        centre,                      NSParagraphStyleAttributeName, nil];
    [self.package.name drawInRect:name withAttributes:nameAttrs];

    NSString *subText = self.package.hasUpdate
        ? [NSString stringWithFormat:@"v%@ → v%@",
           self.package.installedVersion, self.package.version]
        : (self.package.installed
            ? [NSString stringWithFormat:@"v%@", self.package.installedVersion]
            : [NSString stringWithFormat:@"v%@", self.package.version]);

    NSDictionary *subAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
        [TCDTheme uiFontOfSize:(self.compact ? 10.0 : 11.0)], NSFontAttributeName,
        (self.package.hasUpdate ? [TCDTheme accent] : [TCDTheme inkTwo]),
                                                          NSForegroundColorAttributeName,
        centre,                      NSParagraphStyleAttributeName, nil];
    [subText drawInRect:sub withAttributes:subAttrs];
}

- (void)setFrameSize:(NSSize)size {
    [super setFrameSize:size];
    [self setNeedsDisplay:YES];
}

- (void)setPackage:(TCDPackage *)p {
    _package = p;
    [self setNeedsDisplay:YES];
}

- (void)setIconSize:(CGFloat)s {
    _iconSize = s;
    [self setNeedsDisplay:YES];
}

- (void)setCompact:(BOOL)c {
    _compact = c;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirty {
    (void)dirty;
    if (!self.package) return;
    [self layout];
}

@end

#pragma mark - the grid

@interface TCDStoreGrid () <NSCollectionViewDataSource, NSCollectionViewDelegate>
@property (nonatomic, strong) NSCollectionView *collection;
@property (nonatomic, strong) NSTextField *emptyLabel;
@property (nonatomic, copy)   NSString *emptyMessage;
@end

@implementation TCDStoreGrid

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.packages = @[];
    self.density = TCDIconDensityMedium;

    self.collection = [[NSCollectionView alloc] initWithFrame:frame];
    [self.collection setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self.collection setDataSource:self];
    [self.collection setDelegate:self];
    [self.collection setAllowsMultipleSelection:NO];
    [self.collection setBackgroundColors:
        [NSArray arrayWithObject:[TCDTheme content]]];
    [self addSubview:self.collection];

    self.emptyLabel = [[NSTextField alloc] initWithFrame:
        NSMakeRect(0.0, 0.0, 300.0, 20.0)];
    [self.emptyLabel setBezeled:NO];
    [self.emptyLabel setDrawsBackground:NO];
    [self.emptyLabel setEditable:NO];
    [self.emptyLabel setSelectable:NO];
    [self.emptyLabel setAlignment:NSCenterTextAlignment];
    [self.emptyLabel setTextColor:[TCDTheme inkThree]];
    [self.emptyLabel setFont:[TCDTheme uiFontOfSize:13.0]];
    [self.emptyLabel setHidden:YES];
    [self addSubview:self.emptyLabel];

    [self applyDensity];
    return self;
}

#pragma mark - metrics

- (NSUInteger)columns {
    return self.density == TCDIconDensityLarge  ? 3
         : self.density == TCDIconDensityMedium ? 4 : 5;
}

- (CGFloat)iconSize {
    return self.density == TCDIconDensityLarge  ? 128.0
         : self.density == TCDIconDensityMedium ?  96.0 : 64.0;
}

- (CGFloat)gap       { return self.density == TCDIconDensitySmall ? 6.0 : 10.0; }
- (CGFloat)inset     { return self.density == TCDIconDensitySmall ? 8.0 : 14.0; }

- (CGFloat)tileHeight {
    CGFloat pad = self.density == TCDIconDensitySmall ? 10.0 : 14.0;
    return [self iconSize] + pad + 30.0 + 12.0;   // icon, name, version, bottom
}

/* The collection view lays its own items out, so all this has to do is hand it
   a tile size that divides the width into the right number of columns. */
- (void)applyDensity {
    CGFloat inset = [self inset];
    CGFloat gap = [self gap];
    CGFloat usable = NSWidth([self bounds]) - inset * 2.0;
    CGFloat cols = (CGFloat)[self columns];
    CGFloat w = (usable - gap * (cols - 1)) / cols;
    if (w < 40.0) w = 40.0;
    [self.collection setItemSize:NSMakeSize(floor(w), [self tileHeight])];
    [self.collection setMinItemSize:NSMakeSize(floor(w), [self tileHeight])];
    [self.collection setMaxItemSize:NSMakeSize(floor(w), [self tileHeight])];

    NSRect e = [self.emptyLabel frame];
    e.origin = NSMakePoint(NSMinX([self bounds]),
                           NSMidY([self bounds]) - NSHeight(e) / 2.0);
    [self.emptyLabel setFrame:e];
    [self.collection reloadData];
}

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [self applyDensity];
}

- (void)setDensity:(TCDIconDensity)density {
    if (_density == density) return;
    _density = density;
    [self applyDensity];
    if ([self.delegate respondsToSelector:@selector(grid:didChangeDensity:)])
        [self.delegate grid:self didChangeDensity:density];
}

#pragma mark - content

- (void)setPackages:(NSArray *)packages {
    _packages = [packages copy] ?: [NSArray array];
    [self reload];
}

- (void)reload {
    [self.collection reloadData];
    [self.collection setNeedsDisplay:YES];
    BOOL empty = self.packages.count == 0;
    [self.emptyLabel setHidden:!empty];
    [self.emptyLabel setStringValue:self.emptyMessage ?: @""];
    [self setNeedsDisplay:YES];
}

- (void)showEmptyStateWithMessage:(NSString *)message {
    self.emptyMessage = [message copy];
    [self reload];
}

#pragma mark - NSCollectionViewDataSource

- (NSInteger)numberOfItemsInSection:(NSInteger)section {
    (void)section;
    return (NSInteger)self.packages.count;
}

- (id)collectionView:(NSCollectionView *)collectionView
    representedObjectAtIndexPath:(NSIndexPath *)indexPath {
    (void)collectionView;
    NSInteger i = (NSInteger)[indexPath indexAtPosition:0];
    if (i < 0 || (NSUInteger)i >= self.packages.count) return nil;
    return [self.packages objectAtIndex:(NSUInteger)i];
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView
                  itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    TCDPackage *pkg = [self collectionView:collectionView
                   representedObjectAtIndexPath:indexPath];
    if (!pkg) return nil;

    CGFloat side = NSWidth([collectionView itemSize]) - 8.0;
    TCDTileView *tile = [[TCDTileView alloc]
        initWithFrame:NSMakeRect(0.0, 0.0, side, NSHeight([collectionView itemSize]))];
    [tile setAutoresizingMask:NSViewNotSizable];
    tile.package = pkg;
    tile.iconSize = [self iconSize];
    tile.compact = (self.density == TCDIconDensitySmall);

    CGFloat caretSide = (self.density == TCDIconDensitySmall) ? 14.0 : 18.0;
    TCDVersionCaret *caret = [[TCDVersionCaret alloc]
        initWithFrame:NSMakeRect(side - caretSide - 2.0, 2.0, caretSide, caretSide)];
    [caret setBezelStyle:NSRegularSquareBezelStyle];
    [caret setTitle:@""];
    [caret setToolTip:[NSString stringWithFormat:@"Versions available for %@",
                      pkg.name]];
    caret.package = pkg;
    [caret setTarget:self];
    [caret setAction:@selector(versionCaretClicked:)];
    [tile addSubview:caret];
    [tile setNeedsDisplay:YES];

    NSCollectionViewItem *item = [[NSCollectionViewItem alloc]
        initWithFrame:tile.frame];
    [item setView:tile];
    [item setRepresentedObject:pkg];
    return item;
}

/* The triangle is a real button, so AppKit gives us its hover, its press and
   its cursor; all that is left is to say which package it belongs to. */
- (void)versionCaretClicked:(id)sender {
    TCDPackage *pkg = [(TCDVersionCaret *)sender package];
    if (pkg && [self.delegate respondsToSelector:@selector(grid:didTapVersionsForPackage:)])
        [self.delegate grid:self didTapVersionsForPackage:pkg];
}

#pragma mark - NSCollectionViewDelegate

- (void)collectionView:(NSCollectionView *)collectionView
    didSelectItemsAtIndexPaths:(NSSet *)indexPaths {
    (void)collectionView;
    NSIndexPath *first = [indexPaths anyObject];
    if (!first) return;
    NSInteger i = (NSInteger)[first indexAtPosition:0];
    if (i < 0 || (NSUInteger)i >= self.packages.count) return;
    if ([self.delegate respondsToSelector:@selector(grid:didSelectPackage:)])
        [self.delegate grid:self didSelectPackage:[self.packages objectAtIndex:(NSUInteger)i]];
}

- (void)collectionView:(NSCollectionView *)collectionView
    doubleClickOnItemsAtIndexPaths:(NSSet *)indexPaths {
    [self collectionView:collectionView didSelectItemsAtIndexPaths:indexPaths];
}

@end
