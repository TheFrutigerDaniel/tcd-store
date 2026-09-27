//
//  TCDStoreGrid.m
//  TCD Store
//

#import "TCDStoreGrid.h"
#import "TCDTheme.h"

#pragma mark - the tile

/* Declared up here because the grid builds them; the implementation is below. */
@interface TCDTileView : NSView
@property (nonatomic, strong) TCDPackage *package;
@property (nonatomic, assign) CGFloat  iconSize;
@property (nonatomic, assign) BOOL     compact;
@property (nonatomic, copy)   void (^onOpen)(void);
@property (nonatomic, copy)   void (^onVersions)(NSPoint point);
@property (nonatomic, assign) BOOL     hot;
@property (nonatomic, assign) BOOL     hotCaret;
@end

#pragma mark - the grid

@interface TCDStoreGrid ()
@property (nonatomic, strong) NSMutableArray *tiles;    // TCDTileView
@property (nonatomic, assign) CGFloat contentHeight;
@property (nonatomic, assign) BOOL layingOut;
@end

@implementation TCDStoreGrid

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.tiles = [NSMutableArray array];
    self.packages = @[];
    self.density = TCDIconDensityMedium;
    return self;
}

- (BOOL)isFlipped { return YES; }

#pragma mark - metrics

- (NSUInteger)columns {
    return self.density == TCDIconDensityLarge ? 3
         : self.density == TCDIconDensityMedium ? 4 : 5;
}

- (CGFloat)iconSize {
    return self.density == TCDIconDensityLarge ? 128.0
         : self.density == TCDIconDensityMedium ? 96.0 : 64.0;
}

- (CGFloat)gap { return self.density == TCDIconDensitySmall ? 7.0 : 10.0; }
- (CGFloat)outerInset { return self.density == TCDIconDensitySmall ? 10.0 : 16.0; }

- (CGFloat)tileWidth {
    NSUInteger cols = [self columns];
    CGFloat inset = [self outerInset];
    CGFloat usable = NSWidth([self bounds]) - inset * 2.0;
    CGFloat total = usable - [self gap] * (CGFloat)(cols - 1);
    return floor(total / (CGFloat)cols);
}

- (CGFloat)tileHeight {
    CGFloat pad = self.density == TCDIconDensitySmall ? 12.0 : 18.0;
    return [self iconSize] + pad + 34.0;
}

#pragma mark - content

- (void)reload {
    for (TCDTileView *t in self.tiles) [t removeFromSuperview];
    [self.tiles removeAllObjects];

    if (self.packages.count) {
        for (TCDPackage *p in self.packages) {
            TCDTileView *t = [[TCDTileView alloc] initWithFrame:NSZeroRect];
            t.package = p;
            t.iconSize = [self iconSize];
            t.compact = (self.density == TCDIconDensitySmall);
            __weak TCDStoreGrid *weakSelf = self;
            t.onOpen = ^{ [weakSelf openTile:t]; };
            t.onVersions = ^(NSPoint pt) { [weakSelf versionsForTile:t at:pt]; };
            [self addSubview:t];
            [self.tiles addObject:t];
        }
        [self layoutTiles];
    } else {
        self.contentHeight = 0.0;
        [self setNeedsDisplay:YES];
    }
}

- (void)showEmptyStateWithMessage:(NSString *)message {
    self.emptyMessage = message;
    [self reload];
}

- (void)layoutTiles {
    if (self.layingOut) return;      // setFrameSize calls back into here
    self.layingOut = YES;

    NSUInteger cols = [self columns];
    CGFloat w = [self tileWidth];
    CGFloat h = [self tileHeight];
    CGFloat inset = [self outerInset];
    CGFloat y = inset;
    for (NSUInteger i = 0; i < self.tiles.count; i++) {
        NSUInteger col = i % cols;
        if (col == 0 && i > 0) y += h + [self gap];
        [self.tiles[i] setFrame:NSMakeRect(inset + (CGFloat)col * (w + [self gap]), y, w, h)];
    }
    self.contentHeight = self.tiles.count ? (y + h + inset) : 0.0;

    // The grid is its scroll view's document view, so growing itself is how the
    // content gets taller than the window.
    CGFloat wanted = self.tiles.count ? self.contentHeight : NSHeight([self superview]);
    if (NSHeight([self frame]) - wanted > 0.5 ||
        wanted - NSHeight([self frame]) > 0.5)
        [super setFrameSize:NSMakeSize(NSWidth([self frame]), wanted)];

    self.layingOut = NO;
    [self setNeedsDisplay:YES];
}

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    if (self.tiles.count) [self layoutTiles];
    else [self setNeedsDisplay:YES];
}

- (void)setDensity:(TCDIconDensity)density {
    if (_density == density) return;
    _density = density;
    for (TCDTileView *t in self.tiles) {
        t.iconSize = [self iconSize];
        t.compact = (density == TCDIconDensitySmall);
    }
    [self layoutTiles];
    if ([self.delegate respondsToSelector:@selector(grid:didChangeDensity:)])
        [self.delegate grid:self didChangeDensity:density];
}

#pragma mark - drawing

- (void)drawRect:(NSRect)dirty {
    (void)dirty;
    [[TCDTheme content] setFill];
    NSRectFill([self bounds]);
    if (self.packages.count) return;

    NSRect plate = NSMakeRect(NSMidX([self bounds]) - 200.0,
                              NSMidY([self bounds]) - 70.0, 400.0, 140.0);
    [TCDTheme fillRoundedGradient:plate radius:12.0
                       topColor:[NSColor colorWithCalibratedRed:0xee/255.0 green:0xf0/255.0 blue:0xf2/255.0 alpha:1.0]
                       midColor:[NSColor colorWithCalibratedRed:0xee/255.0 green:0xf0/255.0 blue:0xf2/255.0 alpha:1.0]
                       lowColor:[NSColor colorWithCalibratedRed:0xdf/255.0 green:0xe2/255.0 blue:0xe6/255.0 alpha:1.0]
                      baseColor:[NSColor colorWithCalibratedRed:0xe8/255.0 green:0xea/255.0 blue:0xee/255.0 alpha:1.0]
                     borderColor:[TCDTheme line]
                  innerHighlight:NO];
    [TCDTheme drawString:(self.emptyMessage ?: @"")
                  inRect:NSInsetRect(plate, 20.0, 20.0)
                    font:[TCDTheme uiFontOfSize:13.0]
                   color:[TCDTheme inkThree]
                  center:YES];
}

#pragma mark - actions

- (void)openTile:(TCDTileView *)t {
    if ([self.delegate respondsToSelector:@selector(grid:didSelectPackage:)])
        [self.delegate grid:self didSelectPackage:t.package];
}

- (void)versionsForTile:(TCDTileView *)t at:(NSPoint)point {
    if ([self.delegate respondsToSelector:@selector(grid:didTapVersionsForPackage:atPoint:)])
        [self.delegate grid:self didTapVersionsForPackage:t.package atPoint:point];
}

@end

#pragma mark - the tile, for real

@implementation TCDTileView

- (void)setPackage:(TCDPackage *)p { _package = p; [self setNeedsDisplay:YES]; }
- (void)setIconSize:(CGFloat)s { _iconSize = s; [self setNeedsDisplay:YES]; }
- (void)setCompact:(BOOL)c { _compact = c; [self setNeedsDisplay:YES]; }
- (void)setHot:(BOOL)h { _hot = h; [self setNeedsDisplay:YES]; }
- (void)setHotCaret:(BOOL)h { _hotCaret = h; [self setNeedsDisplay:YES]; }

- (BOOL)isFlipped { return YES; }

- (NSTrackingAreaOptions)trackingAreaOptions {
    return NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved |
           NSTrackingActiveInKeyWindow;
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea *a in [self trackingAreas]) [self removeTrackingArea:a];
    NSTrackingArea *area = [[NSTrackingArea alloc]
        initWithRect:[self bounds]
             options:[self trackingAreaOptions]
               owner:self
            userInfo:nil];
    [self addTrackingArea:area];
}

- (void)mouseEntered:(NSEvent *)e { (void)e; self.hot = YES; }
- (void)mouseExited:(NSEvent *)e  { (void)e; self.hot = NO; }

- (NSRect)caretRect {
    CGFloat side = self.compact ? 16.0 : 22.0;
    return NSMakeRect(NSWidth([self bounds]) - side - 6.0, 6.0, side, side);
}

- (BOOL)hitCaret:(NSPoint)p { return NSPointInRect(p, [self caretRect]); }

- (void)mouseMoved:(NSEvent *)e {
    self.hotCaret = [self hitCaret:[self convertPoint:[e locationInWindow] fromView:nil]];
}

- (void)mouseUp:(NSEvent *)e {
    NSPoint local = [self convertPoint:[e locationInWindow] fromView:nil];
    if ([self hitCaret:local] && self.onVersions) { self.onVersions(local); return; }
    if (self.onOpen) self.onOpen();
}

- (void)drawRect:(NSRect)dirty {
    (void)dirty;
    NSRect b = [self bounds];

    if (self.hot) {
        NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:b
                                                           xRadius:10 yRadius:10];
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.035] setFill];
        [p fill];
    }

    CGFloat side = self.iconSize;
    NSRect icon = NSMakeRect(NSMidX(b) - side / 2.0,
                             NSMaxY(b) - side - (self.compact ? 12.0 : 18.0),
                             side, side);
    NSBezierPath *plate = [NSBezierPath bezierPathWithRoundedRect:icon
                                                          xRadius:side * 0.21
                                                          yRadius:side * 0.21];
    [NSGraphicsContext saveGraphicsState];
    [plate addClip];
    [TCDTheme fillVerticalGradient:icon
        stops:@[[NSColor colorWithCalibratedWhite:1.0 alpha:0.30], @(0.0),
                [NSColor colorWithCalibratedWhite:1.0 alpha:0.03], @(0.48),
                [NSColor colorWithCalibratedWhite:0.0 alpha:0.06], @(0.52),
                [NSColor colorWithCalibratedWhite:0.0 alpha:0.12], @(1.0)]];
    [NSGraphicsContext restoreGraphicsState];
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.18] setStroke];
    [plate setLineWidth:1.0];
    [plate stroke];

    NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
    ps.alignment = NSCenterTextAlignment;
    ps.lineBreakMode = NSLineBreakByTruncatingTail;

    NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
    [attrs setObject:[TCDTheme boldFontOfSize:(self.compact ? 11.0 : 12.0)]
              forKey:NSFontAttributeName];
    [attrs setObject:[TCDTheme ink] forKey:NSForegroundColorAttributeName];
    [attrs setObject:ps forKey:NSParagraphStyleAttributeName];
    NSRect nameRect = NSMakeRect(NSMinX(b), NSMinY(icon) - (self.compact ? 15.0 : 17.0),
                                 NSWidth(b), 15.0);
    [self.package.name drawInRect:nameRect withAttributes:attrs];

    NSString *sub = self.package.hasUpdate
        ? [NSString stringWithFormat:@"v%@ → v%@",
           self.package.installedVersion, self.package.version]
        : (self.package.installed
            ? [NSString stringWithFormat:@"v%@", self.package.installedVersion]
            : [NSString stringWithFormat:@"v%@", self.package.version]);
    NSMutableDictionary *sa = [NSMutableDictionary dictionaryWithDictionary:attrs];
    [sa setObject:[TCDTheme uiFontOfSize:(self.compact ? 10.0 : 11.0)]
            forKey:NSFontAttributeName];
    [sa setObject:(self.package.hasUpdate ? [TCDTheme accent] : [TCDTheme inkTwo])
            forKey:NSForegroundColorAttributeName];
    [sub drawInRect:NSMakeRect(NSMinX(b), NSMinY(nameRect) - 12.0, NSWidth(b), 13.0)
      withAttributes:sa];

    // the blue triangle: the version disclosure
    if (self.hot || self.package.hasUpdate || self.hotCaret) {
        NSRect cr = [self caretRect];
        NSBezierPath *cp = [NSBezierPath bezierPathWithOvalInRect:cr];
        if (self.hotCaret) {
            [TCDTheme fillRoundedGradient:cr radius:NSWidth(cr) / 2.0
                               topColor:[TCDTheme accentHi]
                               midColor:[TCDTheme caretBase]
                               lowColor:[TCDTheme accentDark]
                              baseColor:[TCDTheme caretBase]
                             borderColor:[NSColor blackColor]
                          innerHighlight:YES];
        } else {
            [[TCDTheme caretBase] setFill];
            [cp fill];
        }
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.35] setStroke];
        [cp setLineWidth:1.0];
        [cp stroke];

        CGFloat cx = NSMidX(cr), cy = NSMidY(cr), w = NSWidth(cr) * 0.26;
        NSBezierPath *tri = [NSBezierPath bezierPath];
        [tri moveToPoint:NSMakePoint(cx - w, cy + w * 0.55)];
        [tri lineToPoint:NSMakePoint(cx + w, cy + w * 0.55)];
        [tri lineToPoint:NSMakePoint(cx, cy - w * 0.7)];
        [tri closePath];
        [[NSColor whiteColor] setFill];
        [tri fill];
    }
}

@end
