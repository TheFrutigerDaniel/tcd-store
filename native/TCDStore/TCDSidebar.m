//
//  TCDSidebar.m
//  TCD Store
//
//  Structure: a clip view holding one content view that lays out its own rows.
//  An NSTableView would give scrolling and selection for free, but it forces a
//  single rowHeight for the whole table and this panel mixes 26pt headings, 30pt
//  cards and a 40pt density track. Laying the rows out by hand keeps the three
//  sizes honest and keeps the density control as a real view with real buttons,
//  which NSTableView reuse would fight.
//

#import "TCDSidebar.h"
#import "TCDTheme.h"

#import <math.h>   // M_PI, cos, sin for the star and gear glyphs

/* TCDSidebarRows (below) builds rows by asking the panel for its plan, and
   those methods live in the panel's own @implementation further down. The
   declarations have to come first or the compiler cannot see them yet. */
@interface TCDSidebar ()
- (NSArray *)rowPlan;
- (BOOL)isRowActiveForRoute:(TCDSidebarRoute)route section:(NSString *)section;
- (void)cardClicked:(id)sender;
- (void)densityTrackChanged:(id)sender;
@end

#pragma mark - glyphs

/* Vector marks, drawn rather than shipped as assets so the bundle stays
   self-contained. Each is drawn in the colour it is asked for. */
static NSImage *TCDGlyphImage(NSString *kind, NSColor *color) {
    NSImage *img = [[NSImage alloc] initWithSize:NSMakeSize(16.0, 16.0)];
    [img lockFocus];
    [color setStroke];
    [color setFill];
    CGFloat c = 8.0;
    if ([kind isEqualToString:@"star"]) {
        NSBezierPath *p = [NSBezierPath bezierPath];
        for (NSInteger i = 0; i < 10; i++) {
            double a = (M_PI / 5.0) * i - M_PI_2;
            double r = (i % 2 == 0) ? 6.2 : 2.6;
            NSPoint pt = NSMakePoint(c + r * cos(a), c + r * sin(a));
            if (i == 0) [p moveToPoint:pt]; else [p lineToPoint:pt];
        }
        [p closePath];
        [p fill];
    } else if ([kind isEqualToString:@"download"]) {
        NSBezierPath *p = [NSBezierPath bezierPath];
        [p moveToPoint:NSMakePoint(8, 13.5)];
        [p lineToPoint:NSMakePoint(8, 3.5)];
        [p setLineWidth:1.6];
        [p stroke];
        NSBezierPath *h = [NSBezierPath bezierPath];
        [h moveToPoint:NSMakePoint(5, 6.5)];
        [h lineToPoint:NSMakePoint(8, 3.5)];
        [h lineToPoint:NSMakePoint(11, 6.5)];
        [h closePath];
        [h fill];
    } else if ([kind isEqualToString:@"archive"]) {
        NSRect r = NSMakeRect(3, 4, 10, 8);
        [[NSBezierPath bezierPathWithRoundedRect:r xRadius:1.5 yRadius:1.5] fill];
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.85] setFill];
        NSRectFill(NSMakeRect(3, 9, 10, 1.2));
    } else if ([kind isEqualToString:@"server"]) {
        [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(3, 2, 10, 5)
                                          xRadius:1 yRadius:1] fill];
        [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(3, 8, 10, 5)
                                          xRadius:1 yRadius:1] fill];
    } else if ([kind isEqualToString:@"gear"]) {
        NSBezierPath *ring = [NSBezierPath bezierPathWithOvalInRect:
                              NSMakeRect(4.5, 4.5, 7, 7)];
        [ring setLineWidth:2.0];
        [ring stroke];
        for (NSInteger i = 0; i < 6; i++) {
            double a = (M_PI / 3.0) * i;
            NSBezierPath *t = [NSBezierPath bezierPath];
            [t moveToPoint:NSMakePoint(8 + 4.6 * cos(a), 8 + 4.6 * sin(a))];
            [t lineToPoint:NSMakePoint(8 + 6.6 * cos(a), 8 + 6.6 * sin(a))];
            [t setLineWidth:1.6];
            [t stroke];
        }
    } else {
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(4, 4, 8, 8)] fill];
    }
    [img unlockFocus];
    return img;
}

/* The Finder-style density glyph: n columns of little squares. */
static NSImage *TCDDensityImage(NSUInteger columns, NSColor *color) {
    CGFloat unit = 4.0, gap = 1.2;
    NSUInteger rows = 2;
    CGFloat w = columns * unit + (columns - 1) * gap;
    CGFloat h = rows * unit + (rows - 1) * gap;
    NSImage *img = [[NSImage alloc] initWithSize:NSMakeSize(w, h)];
    [img lockFocus];
    [color setFill];
    for (NSUInteger y = 0; y < rows; y++) {
        for (NSUInteger x = 0; x < columns; x++) {
            NSRect r = NSMakeRect(x * (unit + gap), y * (unit + gap), unit, unit);
            [[NSBezierPath bezierPathWithRoundedRect:r xRadius:1 yRadius:1] fill];
        }
    }
    [img unlockFocus];
    return img;
}

#pragma mark - row views

@interface TCDSidebarHeading : NSView
@property (nonatomic, copy) NSString *heading;
@end

@implementation TCDSidebarHeading
- (void)setHeading:(NSString *)h { _heading = [h copy]; [self setNeedsDisplay:YES]; }
- (void)drawRect:(NSRect)dirty {
    (void)dirty;
    NSDictionary *attrs = @{
        NSFontAttributeName: [TCDTheme smallCapsFontOfSize:10.5],
        NSForegroundColorAttributeName: [TCDTheme sideHead],
        NSKernAttributeName: @(0.6) };
    [[_heading uppercaseString] drawAtPoint:
        NSMakePoint(14.0, NSMidY([self bounds]) - 6.0) withAttributes:attrs];
}
@end

@interface TCDSidebarCard : NSView
@property (nonatomic, copy)   NSString *label;
@property (nonatomic, copy)   NSString *sub;
@property (nonatomic, copy)   NSString *glyph;
@property (nonatomic, assign) BOOL activeRow;
@property (nonatomic, assign) BOOL hotRow;
@property (nonatomic, copy)   void (^onClick)(void);
@property (nonatomic, assign) BOOL pressed;
@end

@implementation TCDSidebarCard

- (void)setLabel:(NSString *)v { _label = [v copy]; [self setNeedsDisplay:YES]; }
- (void)setSub:(NSString *)v { _sub = [v copy]; [self setNeedsDisplay:YES]; }
- (void)setGlyph:(NSString *)v { _glyph = [v copy]; [self setNeedsDisplay:YES]; }
- (void)setActiveRow:(BOOL)v { _activeRow = v; [self setNeedsDisplay:YES]; }
- (void)setHotRow:(BOOL)v { _hotRow = v; [self setNeedsDisplay:YES]; }

- (void)mouseDown:(NSEvent *)e {
    (void)e;
    self.pressed = YES;
    [self setNeedsDisplay:YES];
}
- (void)mouseUp:(NSEvent *)e {
    (void)e;
    self.pressed = NO;
    [self setNeedsDisplay:YES];
    if (self.onClick) self.onClick();
}
- (void)mouseEntered:(NSEvent *)e {
    (void)e; self.hotRow = YES; [self setNeedsDisplay:YES];
}
- (void)mouseExited:(NSEvent *)e {
    (void)e; self.hotRow = NO; [self setNeedsDisplay:YES];
}
- (NSTrackingAreaOptions)trackingAreaOptions {
    return NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved |
           NSTrackingActiveInKeyWindow;
}
- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea *a in [self trackingAreas]) [self removeTrackingArea:a];
    [self addTrackingArea:[[NSTrackingArea alloc]
        initWithRect:[self bounds]
             options:[self trackingAreaOptions]
               owner:self
            userInfo:nil]];
}

- (void)drawRect:(NSRect)dirty {
    (void)dirty;
    NSRect r = NSInsetRect([self bounds], 10.0, 2.5);
    if (self.activeRow) {
        [TCDTheme fillRoundedGradient:r radius:6.0
                           topColor:[TCDTheme cardActiveHi]
                           midColor:[TCDTheme cardActiveBase]
                           lowColor:[TCDTheme cardActiveLo]
                          baseColor:[TCDTheme cardActiveBase]
                         borderColor:[NSColor blackColor]
                      innerHighlight:YES];
    } else if (self.hotRow) {
        [TCDTheme fillRoundedGradient:r radius:6.0
                           topColor:[TCDTheme cardHoverBase]
                           midColor:[TCDTheme cardHoverBase]
                           lowColor:[TCDTheme cardBase]
                          baseColor:[TCDTheme cardHoverBase]
                         borderColor:[NSColor blackColor]
                      innerHighlight:NO];
    } else {
        [TCDTheme fillRoundedGradient:r radius:6.0
                           topColor:[TCDTheme cardHi]
                           midColor:[TCDTheme cardBase]
                           lowColor:[TCDTheme cardLo]
                          baseColor:[TCDTheme cardBase]
                         borderColor:[NSColor blackColor]
                      innerHighlight:YES];
    }

    NSRect content = NSInsetRect(r, 11.0, 0.0);
    if (self.activeRow) {
        // the one blue in the panel: where you are
        [[TCDTheme accent] setFill];
        NSRectFill(NSMakeRect(NSMinX(content) - 8.0, NSMinY(content) + 6.0, 2.0,
                              NSHeight(content) - 12.0));
    }

    if (self.glyph) {
        NSImage *img = TCDGlyphImage(self.glyph,
                    self.activeRow ? [TCDTheme white] : [TCDTheme cardIcon]);
        [img drawInRect:NSMakeRect(NSMinX(content), NSMidY(content) - 7.5, 15.0, 15.0)
               fromRect:NSZeroRect
              operation:NSCompositingOperationSourceOver
               fraction:1.0];
    }

    NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
    [attrs setObject:[TCDTheme boldFontOfSize:12.5] forKey:NSFontAttributeName];
    [attrs setObject:(self.activeRow ? [TCDTheme white] : [TCDTheme cardLabel])
              forKey:NSForegroundColorAttributeName];
    NSSize ls = [_label sizeWithAttributes:attrs];
    [_label drawAtPoint:NSMakePoint(NSMinX(content) + 22.0,
                                    NSMidY(content) - ls.height / 2.0)
          withAttributes:attrs];

    if (_sub.length) {
        NSMutableDictionary *sa = [NSMutableDictionary dictionary];
        [sa setObject:[TCDTheme boldFontOfSize:10.5] forKey:NSFontAttributeName];
        [sa setObject:(self.activeRow ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.85]
                                      : [TCDTheme cardSub])
               forKey:NSForegroundColorAttributeName];
        NSSize ss = [_sub sizeWithAttributes:sa];
        [_sub drawAtPoint:NSMakePoint(NSMaxX(r) - 11.0 - ss.width,
                                      NSMidY(content) - ss.height / 2.0)
            withAttributes:sa];
    }
}
@end

#pragma mark - density control

@interface TCDDensityButton : NSButton
@property (nonatomic, strong) NSImage *idleImage;
@property (nonatomic, strong) NSImage *chosenImage;
@property (nonatomic, assign) BOOL chosen;
@end

@implementation TCDDensityButton

- (void)setIdleImage:(NSImage *)i { _idleImage = i; [self setNeedsDisplay:YES]; }
- (void)setChosenImage:(NSImage *)i { _chosenImage = i; [self setNeedsDisplay:YES]; }
- (void)setChosen:(BOOL)v { _chosen = v; [self setNeedsDisplay:YES]; }

- (void)drawRect:(NSRect)dirty {
    (void)dirty;
    NSRect r = NSInsetRect([self bounds], 0.0, 0.5);
    if (self.chosen) {
        [TCDTheme fillRoundedGradient:r radius:5.0
                           topColor:[TCDTheme cardActiveHi]
                           midColor:[TCDTheme cardActiveBase]
                           lowColor:[TCDTheme cardActiveLo]
                          baseColor:[TCDTheme cardActiveBase]
                         borderColor:[NSColor blackColor]
                      innerHighlight:YES];
    } else if (self.pressed) {
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.09] setFill];
        [[NSBezierPath bezierPathWithRoundedRect:r xRadius:5 yRadius:5] fill];
    }
    NSImage *img = self.chosen ? self.chosenImage : self.idleImage;
    if (img) {
        NSRect ir = [img size];
        ir.origin.x = NSMidX(r) - NSWidth(ir) / 2.0;
        ir.origin.y = NSMidY(r) - NSHeight(ir) / 2.0;
        [img drawInRect:ir fromRect:NSZeroRect
              operation:NSCompositingOperationSourceOver fraction:1.0];
    }
}
@end

@interface TCDDensityTrack : NSView
@property (nonatomic, strong) NSMutableArray *buttons;
@property (nonatomic, assign) TCDIconDensity chosenDensity;
@property (nonatomic, weak) id trackTarget;
@property (nonatomic, assign) SEL trackAction;
@end

@implementation TCDDensityTrack

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    NSMutableArray *bs = [NSMutableArray array];
    NSUInteger columns[3] = { 3, 4, 5 };
    NSString *tips[3] = { @"Large — 3 per row",
                          @"Medium — 4 per row",
                          @"Small — 5 per row" };
    for (NSInteger i = 0; i < 3; i++) {
        TCDDensityButton *b = [[TCDDensityButton alloc] initWithFrame:NSZeroRect];
        b.idleImage  = TCDDensityImage(columns[i], [TCDTheme sideRowIcon]);
        b.chosenImage = TCDDensityImage(columns[i], [TCDTheme white]);
        b.tag = i;
        [b setTarget:self];
        [b setAction:@selector(clicked:)];
        [b setToolTip:tips[i]];
        [bs addObject:b];
        [self addSubview:b];
    }
    self.buttons = bs;
    self.chosenDensity = TCDIconDensityMedium;
    return self;
}

- (void)setChosenDensity:(TCDIconDensity)d {
    _chosenDensity = d;
    for (NSInteger i = 0; i < (NSInteger)self.buttons.count; i++) {
        [(TCDDensityButton *)self.buttons[(NSUInteger)i] setChosen:(i == (NSInteger)d)];
    }
}

- (void)clicked:(id)sender {
    self.chosenDensity = (TCDIconDensity)[sender tag];
    if ([self.trackTarget respondsToSelector:self.trackAction])
        [self.trackTarget performSelector:self.trackAction withObject:self];
}

- (void)layoutButtons {
    NSRect r = [self bounds];
    CGFloat x = NSMinX(r) + 13.0;
    CGFloat w = (NSWidth(r) - 26.0 - 8.0 - 2 * 4.0) / 3.0;
    for (TCDDensityButton *b in self.buttons) {
        [b setFrame:NSMakeRect(x, NSMinY(r) + 8.0, w, NSHeight(r) - 16.0)];
        x += w + 4.0;
    }
}

- (void)drawRect:(NSRect)dirty {
    (void)dirty;
    NSBezierPath *track = [NSBezierPath bezierPathWithRoundedRect:
        NSInsetRect([self bounds], 10.0, 4.0) xRadius:7 yRadius:7];
    [[TCDTheme densityTrack] setFill];
    [track fill];
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] setStroke];
    [track setLineWidth:1.0];
    [track stroke];
    [self layoutButtons];
}

- (void)setFrameSize:(NSSize)s {
    [super setFrameSize:s];
    [self layoutButtons];
}
@end

#pragma mark - the content view that lays the rows out

@class TCDSidebar;

@interface TCDSidebarRows : NSView
@property (nonatomic, weak) TCDSidebar *owner;
- (void)relayout;
@end

@implementation TCDSidebarRows

- (BOOL)isFlipped { return YES; }

- (void)relayout {
    for (NSView *v in [[self subviews] copy]) {
        if ([v isKindOfClass:[TCDSidebarCard class]] || [v isKindOfClass:[TCDSidebarHeading class]])
            [v removeFromSuperview];
    }

    TCDSidebar *o = self.owner;
    CGFloat w = NSWidth([self bounds]);
    CGFloat y = 6.0;

    NSArray *plan = o.rowPlan;
    for (NSDictionary *item in plan) {
        NSString *k = item[@"k"];
        if ([k isEqualToString:@"h"]) {
            TCDSidebarHeading *h = [[TCDSidebarHeading alloc] initWithFrame:
                NSMakeRect(0.0, y, w, 26.0)];
            h.heading = item[@"t"];
            [self addSubview:h];
            y += 26.0;
        } else if ([k isEqualToString:@"d"]) {
            TCDDensityTrack *t = [[TCDDensityTrack alloc] initWithFrame:
                NSMakeRect(0.0, y, w, 40.0)];
            t.chosenDensity = o.density;
            t.trackTarget = o;
            t.trackAction = @selector(densityTrackChanged:);
            [self addSubview:t];
            y += 40.0;
        } else {
            TCDSidebarCard *c = [[TCDSidebarCard alloc] initWithFrame:
                NSMakeRect(0.0, y, w, 30.0)];
            c.label = item[@"l"];
            c.sub = item[@"s"];
            c.glyph = item[@"i"];
            c.activeRow = [item[@"on"] boolValue];
            c.tag = [item[@"row"] integerValue];
            __weak TCDSidebar *weakOwner = o;
            c.onClick = ^{ [weakOwner cardClicked:c]; };
            [self addSubview:c];
            y += 30.0;
        }
    }
    [self setFrameSize:NSMakeSize(w, y + 12.0)];
}
@end

#pragma mark - the panel

@interface TCDSidebar ()
@property (nonatomic, strong) NSScrollView *scroll;
@property (nonatomic, strong) TCDSidebarRows *rows;
@end

@implementation TCDSidebar

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.packages = @[];
    self.sections = @[];

    self.rows = [[TCDSidebarRows alloc] initWithFrame:
        NSMakeRect(0.0, 0.0, NSWidth(frame), 0.0)];
    self.rows.owner = self;

    self.scroll = [[NSScrollView alloc] initWithFrame:frame];
    [self.scroll setDocumentView:self.rows];
    [self.scroll setHasVerticalScroller:YES];
    [self.scroll setAutohidesScrollers:YES];
    [self.scroll setBorderType:NSNoBorder];
    [self.scroll setDrawsBackground:NO];
    [self.scroll setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self addSubview:self.scroll];
    return self;
}

#pragma mark - drawing

- (void)drawRect:(NSRect)dirty {
    (void)dirty;
    [TCDTheme fillVerticalGradient:[self bounds]
        stops:@[[TCDTheme sidebarTop], @(0.0),
                [TCDTheme sidebarMid], @(0.60),
                [TCDTheme sidebarBottom], @(1.0)]];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.06] setFill];
    NSRectFill(NSMakeRect(NSMaxX([self bounds]) - 1.0, 0.0, 1.0, NSHeight([self bounds])));
}

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [self.rows setFrameSize:NSMakeSize(NSWidth(newSize), NSHeight([self.rows frame]))];
    [self.rows relayout];
}

#pragma mark - model

- (void)reload {
    [self.rows setFrameSize:NSMakeSize(NSWidth([self bounds]), NSHeight([self.rows frame]))];
    [self.rows relayout];
}

- (NSArray *)rowPlan {
    NSMutableArray *plan = [NSMutableArray array];
    [plan addObject:@{ @"k": @"h", @"t": @"Store" }];
    NSArray *store = @[ @{ @"r": @(TCDSidebarRouteFeatured),  @"i": @"star",     @"l": @"Featured" },
                        @{ @"r": @(TCDSidebarRouteUpdates),   @"i": @"download", @"l": @"Updates"  },
                        @{ @"r": @(TCDSidebarRouteInstalled), @"i": @"archive",  @"l": @"Installed"},
                        @{ @"r": @(TCDSidebarRouteSources),   @"i": @"server",   @"l": @"Sources"  },
                        @{ @"r": @(TCDSidebarRouteSettings),  @"i": @"gear",     @"l": @"Settings" } ];
    NSUInteger i = 0;
    for (NSDictionary *d in store) {
        TCDSidebarRoute r = (TCDSidebarRoute)[d[@"r"] integerValue];
        NSString *sub = nil;
        if (r == TCDSidebarRouteUpdates)
            sub = self.updatesCount ? [NSString stringWithFormat:@"%lu",
                                      (unsigned long)self.updatesCount] : nil;
        else if (r == TCDSidebarRouteInstalled)
            sub = [NSString stringWithFormat:@"%lu", (unsigned long)self.installedCount];
        else if (r == TCDSidebarRouteSources)
            sub = [NSString stringWithFormat:@"%lu", (unsigned long)self.sourceCount];
        [plan addObject:@{ @"k": @"c", @"r": @(r), @"i": d[@"i"], @"l": d[@"l"], @"s": sub,
                           @"row": @(i++),
                           @"on": @([self isRowActiveForRoute:r section:nil]) }];
    }
    [plan addObject:@{ @"k": @"h", @"t": @"View" }];
    [plan addObject:@{ @"k": @"d" }];
    [plan addObject:@{ @"k": @"h", @"t": @"Categories" }];
    NSUInteger catIndex = 0;
    for (NSString *section in self.sections) {
        NSUInteger n = 0;
        for (TCDPackage *p in self.packages) if ([p.section isEqualToString:section]) n++;
        if (!n) continue;
        [plan addObject:@{ @"k": @"c", @"r": @(TCDSidebarRouteCategory), @"i": @"dot",
                           @"l": section, @"s": [NSString stringWithFormat:@"%lu", (unsigned long)n],
                           @"row": @(5 + catIndex++),
                           @"on": @([self isRowActiveForRoute:TCDSidebarRouteCategory
                                                   section:section]) }];
    }
    return plan;
}

- (BOOL)isRowActiveForRoute:(TCDSidebarRoute)route section:(NSString *)section {
    if (self.activeRoute != route) return NO;
    if (route != TCDSidebarRouteCategory) return self.activeSection.length == 0;
    return [self.activeSection isEqualToString:section];
}

#pragma mark - actions

- (void)cardClicked:(id)sender {
    TCDSidebarCard *c = (TCDSidebarCard *)sender;
    NSInteger row = c.tag;
    NSDictionary *item = nil;
    for (NSDictionary *p in [self rowPlan]) {
        if ([p[@"k"] isEqualToString:@"c"] && [p[@"row"] integerValue] == row) {
            item = p;
            break;
        }
    }
    if (!item) return;
    TCDSidebarRoute r = (TCDSidebarRoute)[item[@"r"] integerValue];
    self.activeRoute = r;
    self.activeSection = (r == TCDSidebarRouteCategory) ? item[@"l"] : nil;
    [self reload];
    if ([self.delegate respondsToSelector:@selector(sidebar:didSelectRoute:section:)])
        [self.delegate sidebar:self didSelectRoute:r section:self.activeSection];
}

- (void)densityTrackChanged:(id)sender {
    TCDIconDensity d = ((TCDDensityTrack *)sender).chosenDensity;
    if (d == self.density) return;
    self.density = d;
    if ([self.delegate respondsToSelector:@selector(sidebar:didSelectDensity:)])
        [self.delegate sidebar:self didSelectDensity:d];
}

@end
