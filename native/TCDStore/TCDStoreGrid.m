//
//  TCDStoreGrid.m
//  TCD Store
//
//  The large-icon grid.
//
//  This is an NSCollectionView, but note *which* NSCollectionView. The one in
//  the 10.9 SDK is NS_CLASS_AVAILABLE(10_5, NA): the original, pre-10.11
//  collection view. That matters, because it is a different API from the one
//  most people picture:
//
//    * there is no dataSource, and no NSCollectionViewDataSource protocol --
//      neither token appears anywhere in the SDK;
//    * there is no -reloadData;
//    * the delegate protocol is drag-and-drop only.
//
//  Content is handed over whole with -setContent:, item views come from an
//  -setItemPrototype: prototype that is cloned per object, and the layout is
//  driven by -setMinItemSize:/-setMaxItemSize: plus -setMaxNumberOfColumns:.
//  Cloning the prototype would share one view between every tile, so
//  -newItemForRepresentedObject: is overridden to build each tile directly.
//
//  It also wants to be the document view of a scroll view -- the ivars include
//  'superviewIsClipView' and 'observingScroll' for precisely that -- so unlike
//  the 10.11 collection view, it does not scroll itself.
//
//  Because that API exposes no selection callback, the tiles handle their own
//  clicks. That is deterministic: the tile is an ordinary view under the mouse,
//  so -mouseDown: is guaranteed to run, where an informal delegate method would
//  only run if the implementation still sent one.
//

#import "TCDStoreGrid.h"
#import "TCDTheme.h"

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

@class TCDTileView;

@protocol TCDTileClickHandler <NSObject>
- (void)tileView:(TCDTileView *)tile didClickPackage:(TCDPackage *)pkg;
@end

@interface TCDTileView : NSView
@property (nonatomic, weak)   id<TCDTileClickHandler> clickHandler;   // not retained
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

/* The collection view owns the tile's frame, so the triangle is positioned
   here rather than at creation time -- otherwise it would sit in the corner of
   whatever the first tile size happened to be. */
- (void)positionCaret {
    for (NSView *sub in [self subviews]) {
        if (![sub isKindOfClass:[TCDVersionCaret class]]) continue;
        CGFloat side = self.compact ? 14.0 : 18.0;
        [sub setFrame:NSMakeRect(NSWidth([self bounds]) - side - 2.0,
                                 2.0, side, side)];
    }
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

    [self positionCaret];
}

/* The tile is the view under the mouse, so this is the whole click path: the
   10.5 collection view has no selection delegate to tell us instead. */
- (void)mouseDown:(NSEvent *)event {
    (void)event;
    TCDPackage *pkg = self.package;
    if (pkg && [self.clickHandler respondsToSelector:@selector(tileView:didClickPackage:)])
        [self.clickHandler tileView:self didClickPackage:pkg];
}

- (void)setFrameSize:(NSSize)size {
    [super setFrameSize:size];
    [self positionCaret];
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
    [self positionCaret];
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirty {
    (void)dirty;
    if (!self.package) return;
    [self layout];
}

@end

#pragma mark - the grid

@interface TCDStoreGrid () <TCDTileClickHandler>
@property (nonatomic, strong) NSScrollView *scroll;
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

    // The collection view is the document view; it sizes itself to the number
    // of items once it has been given a width.
    self.collection = [[NSCollectionView alloc] initWithFrame:frame];
    [self.collection setAutoresizingMask:NSViewNotSizable];
    [self.collection setSelectable:NO];
    [self.collection setAllowsMultipleSelection:NO];
    [self.collection setBackgroundColors:
        [NSArray arrayWithObject:[TCDTheme content]]];

    // The prototype is never copied -- -newItemForRepresentedObject: builds
    // each tile directly -- but it is still worth setting rather than leaving
    // the ivar nil, since the collection view reads it during layout.
    [self.collection setItemPrototype:[[NSCollectionViewItem alloc]
        initWithNibName:nil bundle:nil]];

    self.scroll = [[NSScrollView alloc] initWithFrame:frame];
    [self.scroll setHasVerticalScroller:YES];
    [self.scroll setHasHorizontalScroller:NO];
    [self.scroll setAutohidesScrollers:YES];
    [self.scroll setDrawsBackground:NO];
    [self.scroll setBorderType:NSNoBorder];
    [self.scroll setDocumentView:self.collection];
    [self.scroll setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self addSubview:self.scroll];

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

- (NSSize)tileSize {
    CGFloat inset = [self inset];
    CGFloat gap = [self gap];
    CGFloat usable = [self clipWidth] - inset * 2.0;
    CGFloat cols = (CGFloat)[self columns];
    CGFloat w = (usable - gap * (cols - 1)) / cols;
    if (w < 40.0) w = 40.0;
    return NSMakeSize(floor(w), floor([self tileHeight]));
}

/* The usable width is the clip view's, not the scroll's: the scroll view keeps
   a couple of points of slack for the scroller, and dividing that into columns
   leaves the last column short. */
- (CGFloat)clipWidth {
    CGFloat w = NSWidth([[self.scroll contentView] bounds]);
    if (w <= 0.0) w = NSWidth([self bounds]);
    return w;
}

/* The collection view lays its own items out, so all this has to do is hand it
   a tile size that divides the width into the right number of columns, and cap
   the columns to match. min == max makes the size exact rather than a range. */
- (void)applyDensity {
    NSSize size = [self tileSize];
    [self.collection setMinItemSize:size];
    [self.collection setMaxItemSize:size];
    [self.collection setMaxNumberOfColumns:(NSUInteger)[self columns]];
    [self.collection setMaxNumberOfRows:0];             // 0 means no limit

    NSRect e = [self.emptyLabel frame];
    e.origin = NSMakePoint(NSMinX([self bounds]),
                           NSMidY([self bounds]) - NSHeight(e) / 2.0);
    [self.emptyLabel setFrame:e];

    [self layoutCollectionWidth];
    [self pushContent];
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

/* The width has to be settled before the content is set, because the
   collection view decides how many rows fit from the width it has at the
   moment it lays itself out. */
- (void)layoutCollectionWidth {
    NSRect f = [self.collection frame];
    if (f.size.width == [self clipWidth] && f.size.height > 0.0)
        return;
    f.origin = NSZeroPoint;
    f.size.width = [self clipWidth];
    f.size.height = NSHeight([[self.scroll contentView] bounds]);
    if (f.size.height <= 0.0) f.size.height = NSHeight([self bounds]);
    [self.collection setFrame:f];
}

- (void)setPackages:(NSArray *)packages {
    _packages = [packages copy] ?: [NSArray array];
    [self reload];
}

- (void)pushContent {
    [self layoutCollectionWidth];
    [self.collection setContent:self.packages];
}

- (void)reload {
    /* Tiles capture the icon size and the caret at creation, so a density
       change has to rebuild them. Emptying the content first guarantees the
       next -setContent: creates fresh items rather than reusing the old ones. */
    [self.collection setContent:[NSArray array]];
    [self pushContent];

    BOOL empty = self.packages.count == 0;
    [self.emptyLabel setHidden:!empty];
    [self.emptyLabel setStringValue:self.emptyMessage ?: @""];
    [self setNeedsDisplay:YES];
}

- (void)showEmptyStateWithMessage:(NSString *)message {
    self.emptyMessage = [message copy];
    [self reload];
}

#pragma mark - items

/* Overrides the prototype cloning. The prototype is only a template as far as
   the frame goes; the tile is built here so that each item owns its own view
   and its own version triangle. */
- (NSCollectionViewItem *)newItemForRepresentedObject:(id)object {
    if (![object isKindOfClass:[TCDPackage class]]) return nil;
    TCDPackage *pkg = (TCDPackage *)object;

    NSSize size = [self tileSize];
    TCDTileView *tile = [[TCDTileView alloc]
        initWithFrame:NSMakeRect(0.0, 0.0, size.width, size.height)];
    [tile setAutoresizingMask:NSViewNotSizable];
    [tile setClickHandler:self];
    [tile setIconSize:[self iconSize]];
    [tile setCompact:(self.density == TCDIconDensitySmall)];
    [tile setPackage:pkg];

    CGFloat caretSide = (self.density == TCDIconDensitySmall) ? 14.0 : 18.0;
    TCDVersionCaret *caret = [[TCDVersionCaret alloc]
        initWithFrame:NSMakeRect(size.width - caretSide - 2.0, 2.0,
                                 caretSide, caretSide)];
    [caret setBezelStyle:NSRegularSquareBezelStyle];
    [caret setTitle:@""];
    [caret setToolTip:[NSString stringWithFormat:@"Versions available for %@",
                      pkg.name]];
    caret.package = pkg;
    [caret setTarget:self];
    [caret setAction:@selector(versionCaretClicked:)];
    [tile addSubview:caret];

    // NSCollectionViewItem is an NSViewController, so it has no -initWithFrame:.
    // The tile already knows its package, so there is nothing to set on the
    // item itself and no reason to depend on -representedObject being declared.
    NSCollectionViewItem *item = [[NSCollectionViewItem alloc]
        initWithNibName:nil bundle:nil];
    [item setView:tile];
    return item;
}

/* The triangle is a real button, so AppKit gives us its hover, its press and
   its cursor; all that is left is to say which package it belongs to. */
- (void)versionCaretClicked:(id)sender {
    TCDPackage *pkg = [(TCDVersionCaret *)sender package];
    if (pkg && [self.delegate respondsToSelector:@selector(grid:didTapVersionsForPackage:)])
        [self.delegate grid:self didTapVersionsForPackage:pkg];
}

#pragma mark - TCDTileClickHandler

- (void)tileView:(TCDTileView *)tile didClickPackage:(TCDPackage *)pkg {
    (void)tile;
    if (pkg && [self.delegate respondsToSelector:@selector(grid:didSelectPackage:)])
        [self.delegate grid:self didSelectPackage:pkg];
}

@end
