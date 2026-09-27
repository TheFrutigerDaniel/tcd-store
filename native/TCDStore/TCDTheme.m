//
//  TCDTheme.m
//  TCD Store
//

#import "TCDTheme.h"

@implementation TCDTheme

#pragma mark - metrics

+ (CGFloat)barLineOneHeight { return 46.0; }
+ (CGFloat)barLineTwoHeight { return 42.0; }
+ (CGFloat)barHeight        { return 88.0; }
+ (CGFloat)sidebarWidth     { return 216.0; }

#pragma mark - bar

+ (NSColor *)barBase           { return [NSColor colorWithCalibratedRed:0x3a/255.0 green:0x3f/255.0 blue:0x48/255.0 alpha:1.0]; }
+ (NSColor *)barLineOneTop     { return [NSColor colorWithCalibratedRed:0x4a/255.0 green:0x50/255.0 blue:0x5a/255.0 alpha:1.0]; }
+ (NSColor *)barLineOneMid     { return [NSColor colorWithCalibratedRed:0x44/255.0 green:0x4a/255.0 blue:0x54/255.0 alpha:1.0]; }
+ (NSColor *)barDivide         { return [NSColor colorWithCalibratedRed:0x2b/255.0 green:0x2f/255.0 blue:0x36/255.0 alpha:1.0]; }
+ (NSColor *)barLineTwoBottom  { return [NSColor colorWithCalibratedRed:0x19/255.0 green:0x1c/255.0 blue:0x20/255.0 alpha:1.0]; }
+ (NSColor *)barEdge           { return [NSColor colorWithCalibratedRed:0x0d/255.0 green:0x0f/255.0 blue:0x11/255.0 alpha:1.0]; }
+ (NSColor *)barInnerHighlight { return [NSColor colorWithCalibratedWhite:1.0 alpha:0.18]; }

#pragma mark - controls

+ (NSColor *)searchWell        { return [NSColor colorWithCalibratedRed:0x1c/255.0 green:0x1f/255.0 blue:0x25/255.0 alpha:1.0]; }
+ (NSColor *)searchWellBorder  { return [NSColor colorWithCalibratedWhite:0.0 alpha:0.62]; }
+ (NSColor *)searchText        { return [NSColor colorWithCalibratedRed:0xec/255.0 green:0xee/255.0 blue:0xf1/255.0 alpha:1.0]; }
+ (NSColor *)searchPlaceholder { return [NSColor colorWithCalibratedRed:0x86/255.0 green:0x8d/255.0 blue:0x97/255.0 alpha:1.0]; }
+ (NSColor *)roundButtonBase   { return [NSColor colorWithCalibratedRed:0x3d/255.0 green:0x43/255.0 blue:0x4c/255.0 alpha:1.0]; }
+ (NSColor *)roundButtonHi     { return [NSColor colorWithCalibratedRed:0x56/255.0 green:0x5d/255.0 blue:0x68/255.0 alpha:1.0]; }
+ (NSColor *)roundButtonLo     { return [NSColor colorWithCalibratedRed:0x2d/255.0 green:0x32/255.0 blue:0x38/255.0 alpha:1.0]; }
+ (NSColor *)roundGlyph        { return [NSColor colorWithCalibratedRed:0xe8/255.0 green:0xea/255.0 blue:0xed/255.0 alpha:1.0]; }
+ (NSColor *)roundGlyphDisabled{ return [NSColor colorWithCalibratedRed:0xe8/255.0 green:0xea/255.0 blue:0xed/255.0 alpha:0.42]; }

#pragma mark - pills

+ (NSColor *)pillFace       { return [NSColor colorWithCalibratedRed:0xdf/255.0 green:0xe2/255.0 blue:0xe7/255.0 alpha:1.0]; }
+ (NSColor *)pillFaceHi     { return [NSColor colorWithCalibratedRed:0xfd/255.0 green:0xfd/255.0 blue:0xfe/255.0 alpha:1.0]; }
+ (NSColor *)pillFaceLo     { return [NSColor colorWithCalibratedRed:0xc3/255.0 green:0xc8/255.0 blue:0xd0/255.0 alpha:1.0]; }
+ (NSColor *)pillLabel      { return [NSColor colorWithCalibratedRed:0x3c/255.0 green:0x40/255.0 blue:0x48/255.0 alpha:1.0]; }
+ (NSColor *)pillActiveFace { return [NSColor colorWithCalibratedRed:0x2f/255.0 green:0x7f/255.0 blue:0xd4/255.0 alpha:1.0]; }
+ (NSColor *)pillActiveHi   { return [NSColor colorWithCalibratedRed:0x5a/255.0 green:0xa6/255.0 blue:0xf2/255.0 alpha:1.0]; }
+ (NSColor *)pillActiveLo   { return [NSColor colorWithCalibratedRed:0x17/255.0 green:0x51/255.0 blue:0x95/255.0 alpha:1.0]; }
+ (NSColor *)white          { return [NSColor whiteColor]; }

#pragma mark - accent

+ (NSColor *)accent     { return [NSColor colorWithCalibratedRed:0x3b/255.0 green:0x8e/255.0 blue:0xde/255.0 alpha:1.0]; }
+ (NSColor *)accentDark { return [NSColor colorWithCalibratedRed:0x1a/255.0 green:0x5f/255.0 blue:0xae/255.0 alpha:1.0]; }
+ (NSColor *)accentHi   { return [NSColor colorWithCalibratedRed:0x6f/255.0 green:0xb2/255.0 blue:0xf7/255.0 alpha:1.0]; }

#pragma mark - sidebar

+ (NSColor *)sidebarBase    { return [NSColor colorWithCalibratedRed:0x13/255.0 green:0x13/255.0 blue:0x15/255.0 alpha:1.0]; }
+ (NSColor *)sidebarTop     { return [NSColor colorWithCalibratedRed:0x1a/255.0 green:0x1a/255.0 blue:0x1c/255.0 alpha:1.0]; }
+ (NSColor *)sidebarMid     { return [NSColor colorWithCalibratedRed:0x12/255.0 green:0x12/255.0 blue:0x14/255.0 alpha:1.0]; }
+ (NSColor *)sidebarBottom  { return [NSColor colorWithCalibratedRed:0x0c/255.0 green:0x0c/255.0 blue:0x0e/255.0 alpha:1.0]; }
+ (NSColor *)cardBase       { return [NSColor colorWithCalibratedRed:0x16/255.0 green:0x17/255.0 blue:0x1a/255.0 alpha:1.0]; }
+ (NSColor *)cardHi         { return [NSColor colorWithCalibratedRed:0x24/255.0 green:0x25/255.0 blue:0x28/255.0 alpha:1.0]; }
+ (NSColor *)cardLo         { return [NSColor colorWithCalibratedRed:0x0d/255.0 green:0x0e/255.0 blue:0x10/255.0 alpha:1.0]; }
+ (NSColor *)cardHoverBase  { return [NSColor colorWithCalibratedRed:0x1e/255.0 green:0x1f/255.0 blue:0x22/255.0 alpha:1.0]; }
+ (NSColor *)cardActiveBase { return [NSColor colorWithCalibratedRed:0x30/255.0 green:0x33/255.0 blue:0x3a/255.0 alpha:1.0]; }
+ (NSColor *)cardActiveHi   { return [NSColor colorWithCalibratedRed:0x4a/255.0 green:0x4e/255.0 blue:0x57/255.0 alpha:1.0]; }
+ (NSColor *)cardActiveLo   { return [NSColor colorWithCalibratedRed:0x24/255.0 green:0x26/255.0 blue:0x2b/255.0 alpha:1.0]; }
+ (NSColor *)cardLabel      { return [NSColor colorWithCalibratedRed:0xf4/255.0 green:0xf5/255.0 blue:0xf7/255.0 alpha:1.0]; }
+ (NSColor *)cardSub        { return [NSColor colorWithCalibratedRed:0x9a/255.0 green:0xa0/255.0 blue:0xaa/255.0 alpha:1.0]; }
+ (NSColor *)cardIcon       { return [NSColor colorWithCalibratedRed:0xd4/255.0 green:0xd9/255.0 blue:0xe0/255.0 alpha:1.0]; }
+ (NSColor *)sideHead       { return [NSColor colorWithCalibratedRed:0x8a/255.0 green:0x8f/255.0 blue:0x99/255.0 alpha:1.0]; }
+ (NSColor *)sideRowLabel   { return [NSColor colorWithCalibratedRed:0xf2/255.0 green:0xf3/255.0 blue:0xf5/255.0 alpha:1.0]; }
+ (NSColor *)sideRowIcon    { return [NSColor colorWithCalibratedRed:0xb9/255.0 green:0xbe/255.0 blue:0xc8/255.0 alpha:1.0]; }
+ (NSColor *)densityTrack   { return [NSColor colorWithCalibratedWhite:0.0 alpha:0.34]; }

#pragma mark - content

+ (NSColor *)content { return [NSColor colorWithCalibratedRed:0xff/255.0 green:0xff/255.0 blue:0xff/255.0 alpha:1.0]; }
+ (NSColor *)chrome  { return [NSColor colorWithCalibratedRed:0xf0/255.0 green:0xf1/255.0 blue:0xf2/255.0 alpha:1.0]; }
+ (NSColor *)ink     { return [NSColor colorWithCalibratedRed:0x1d/255.0 green:0x1d/255.0 blue:0x1f/255.0 alpha:1.0]; }
+ (NSColor *)inkTwo  { return [NSColor colorWithCalibratedRed:0x5a/255.0 green:0x5c/255.0 blue:0x60/255.0 alpha:1.0]; }
+ (NSColor *)inkThree{ return [NSColor colorWithCalibratedRed:0x8d/255.0 green:0x90/255.0 blue:0x95/255.0 alpha:1.0]; }
+ (NSColor *)line    { return [NSColor colorWithCalibratedWhite:0.0 alpha:0.11]; }
+ (NSColor *)lineSoft{ return [NSColor colorWithCalibratedWhite:0.0 alpha:0.055]; }

#pragma mark - status

+ (NSColor *)ok     { return [NSColor colorWithCalibratedRed:0x2e/255.0 green:0xa0/255.0 blue:0x43/255.0 alpha:1.0]; }
+ (NSColor *)warn   { return [NSColor colorWithCalibratedRed:0xd1/255.0 green:0x8b/255.0 blue:0x00/255.0 alpha:1.0]; }
+ (NSColor *)danger { return [NSColor colorWithCalibratedRed:0xd0/255.0 green:0x34/255.0 blue:0x2c/255.0 alpha:1.0]; }

#pragma mark - caret and log

+ (NSColor *)caretBase    { return [NSColor colorWithCalibratedRed:0x4a/255.0 green:0x90/255.0 blue:0xe2/255.0 alpha:1.0]; }
+ (NSColor *)caretHi      { return [NSColor colorWithCalibratedRed:0x8f/255.0 green:0xb8/255.0 blue:0xf5/255.0 alpha:1.0]; }
+ (NSColor *)caretLo      { return [NSColor colorWithCalibratedRed:0x2f/255.0 green:0x7f/255.0 blue:0xd4/255.0 alpha:1.0]; }
+ (NSColor *)logBackground{ return [NSColor colorWithCalibratedRed:0x14/255.0 green:0x16/255.0 blue:0x1a/255.0 alpha:1.0]; }
+ (NSColor *)logBorder    { return [NSColor colorWithCalibratedRed:0x2a/255.0 green:0x2e/255.0 blue:0x35/255.0 alpha:1.0]; }
+ (NSColor *)logText      { return [NSColor colorWithCalibratedRed:0x9f/255.0 green:0xe8/255.0 blue:0xa8/255.0 alpha:1.0]; }
+ (NSColor *)logTextLast  { return [NSColor colorWithCalibratedRed:0xe6/255.0 green:0xf7/255.0 blue:0xea/255.0 alpha:1.0]; }

#pragma mark - verb chips

+ (NSColor *)verbInstallBg     { return [NSColor colorWithCalibratedRed:0xe6/255.0 green:0xf4/255.0 blue:0xea/255.0 alpha:1.0]; }
+ (NSColor *)verbInstallFg     { return [NSColor colorWithCalibratedRed:0x1d/255.0 green:0x7a/255.0 blue:0x35/255.0 alpha:1.0]; }
+ (NSColor *)verbUpdateBg      { return [NSColor colorWithCalibratedRed:0xfd/255.0 green:0xf0/255.0 blue:0xd8/255.0 alpha:1.0]; }
+ (NSColor *)verbUpdateFg      { return [NSColor colorWithCalibratedRed:0x9a/255.0 green:0x63/255.0 blue:0x00/255.0 alpha:1.0]; }
+ (NSColor *)verbDowngradeBg   { return [NSColor colorWithCalibratedRed:0xef/255.0 green:0xe7/255.0 blue:0xfb/255.0 alpha:1.0]; }
+ (NSColor *)verbDowngradeFg   { return [NSColor colorWithCalibratedRed:0x6a/255.0 green:0x3f/255.0 blue:0xa5/255.0 alpha:1.0]; }
+ (NSColor *)verbReinstallBg   { return [NSColor colorWithCalibratedRed:0xe8/255.0 green:0xee/255.0 blue:0xf8/255.0 alpha:1.0]; }
+ (NSColor *)verbReinstallFg   { return [NSColor colorWithCalibratedRed:0x2a/255.0 green:0x5f/255.0 blue:0xa5/255.0 alpha:1.0]; }
+ (NSColor *)verbRemoveBg      { return [NSColor colorWithCalibratedRed:0xfd/255.0 green:0xe8/255.0 blue:0xe6/255.0 alpha:1.0]; }
+ (NSColor *)verbRemoveFg      { return [NSColor colorWithCalibratedRed:0xa8/255.0 green:0x27/255.0 blue:0x1f/255.0 alpha:1.0]; }

#pragma mark - type

+ (NSFont *)uiFontOfSize:(CGFloat)size {
    return [NSFont fontWithName:@"Lucida Grande" size:size]
        ?: [NSFont systemFontOfSize:size];
}

+ (NSFont *)boldFontOfSize:(CGFloat)size {
    return [NSFont fontWithName:@"Lucida Grande Bold" size:size]
        ?: [NSFont boldSystemFontOfSize:size];
}

/* Call sites uppercase their own strings; synthesising small caps from an
   empty attributed string is not worth the round trip. */
+ (NSFont *)smallCapsFontOfSize:(CGFloat)size {
    return [self boldFontOfSize:size];
}

+ (NSFont *)monoFontOfSize:(CGFloat)size {
    return [NSFont fontWithName:@"Menlo" size:size]
        ?: [NSFont fontWithName:@"Monaco" size:size]
        ?: [NSFont userFixedPitchFontOfSize:size];
}

#pragma mark - drawing

+ (void)fillVerticalGradient:(NSRect)rect stops:(NSArray *)stops {
    // `stops` is an even-length array of NSColor, NSNumber(0..1) pairs. The
    // bar needs five stops; NSGradient wants colours plus one parallel array
    // of locations, which is why this is a small loop rather than a literal.
    NSMutableArray *colors = [NSMutableArray arrayWithCapacity:stops.count / 2];
    NSMutableArray *locations = [NSMutableArray arrayWithCapacity:stops.count / 2];
    for (NSUInteger i = 0; i + 1 < stops.count; i += 2) {
        [colors addObject:stops[i]];
        [locations addObject:stops[i + 1]];
    }
    NSGradient *g = [[NSGradient alloc] initWithColors:colors
                                             atLocations:locations
                                              colorSpace:[NSColorSpace genericRGBColorSpace]];
    [g drawInRect:rect angle:90.0];
}

+ (void)fillRoundedGradient:(NSRect)rect
                     radius:(CGFloat)radius
                   topColor:(NSColor *)top
                   midColor:(NSColor *)mid
                   lowColor:(NSColor *)low
                  baseColor:(NSColor *)base
                 borderColor:(NSColor *)border
              innerHighlight:(BOOL)highlight {
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius];

    // base first, so a stroke drawn on top always has something to sit on
    [base setFill];
    [path fill];

    if (top && mid && low) {
        [NSGraphicsContext saveGraphicsState];
        [path addClip];
        NSArray *stops = @[top, @(0.48), mid, @(0.52), low, @(1.0)];
        [self fillVerticalGradient:rect stops:stops];
        [NSGraphicsContext restoreGraphicsState];
    }

    if (border) {
        [border setStroke];
        [path setLineWidth:1.0];
        [path stroke];
    }

    if (highlight) {
        [NSGraphicsContext saveGraphicsState];
        [path addClip];
        NSRect inner = NSInsetRect(rect, 0.0, 0.0);
        inner.size.height = NSHeight(rect) - 1.0;
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.20] setFill];
        NSRectFill(NSMakeRect(NSMinX(inner), NSMaxY(inner) - 1.0,
                            NSWidth(inner), 1.0));
        [NSGraphicsContext restoreGraphicsState];
    }
}

+ (void)fillGloss:(NSRect)rect radius:(CGFloat)radius strength:(CGFloat)strength {
    [NSGraphicsContext saveGraphicsState];
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect
                                                        xRadius:radius yRadius:radius];
    [path addClip];
    NSRect top = NSMakeRect(NSMinX(rect), NSMidY(rect),
                            NSWidth(rect), NSHeight(rect) / 2.0);
    [self fillVerticalGradient:top
                         stops:@[[NSColor colorWithCalibratedWhite:1.0 alpha:strength],
                                 @(0.0),
                                 [NSColor colorWithCalibratedWhite:1.0 alpha:strength * 0.08],
                                 @(1.0)]];
    [NSGraphicsContext restoreGraphicsState];
}

+ (void)drawString:(NSString *)s
             inRect:(NSRect)rect
               font:(NSFont *)font
              color:(NSColor *)color
             center:(BOOL)center {
    if (!s.length) return;
    NSDictionary *attrs = @{ NSFontAttributeName: font,
                             NSForegroundColorAttributeName: color };
    NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
    ps.alignment = center ? NSCenterTextAlignment : NSLeftTextAlignment;
    ps.lineBreakMode = NSLineBreakByTruncatingTail;
    [attrs setObject:ps forKey:NSParagraphStyleAttributeName];

    NSSize size = [s sizeWithAttributes:attrs];
    NSRect r = rect;
    if (center) r.origin.x = NSMinX(rect) + (NSWidth(rect) - size.width) / 2.0;
    r.size.height = size.height;
    r.origin.y = NSMidY(rect) - size.height / 2.0;
    [s drawInRect:r withAttributes:attrs];
}

@end
