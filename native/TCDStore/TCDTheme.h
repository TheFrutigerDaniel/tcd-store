//
//  TCDTheme.h
//  TCD Store
//
//  The design tokens, transcribed from prototype/css/app.css so the native
//  window is pixel-for-pixel the design you approved. When the CSS changes,
//  this is the only file that should need to follow it.
//
//  Colours are declared as plain functions rather than constants because AppKit
//  has no compile-time colour type before 10.9 (no NSColor literal syntax);
//  every call site would otherwise build an autoreleased colour inline.
//

#import <Cocoa/Cocoa.h>

#pragma mark - the black bar (aero chrome)

/* The whole bar is one element in the prototype: wordmark and pills on the
   first line, search and buttons on the second, sharing one surface. These
   stops are that surface's ramp, top to bottom. */
@interface TCDTheme : NSObject

+ (CGFloat)barLineOneHeight;    // 46
+ (CGFloat)barLineTwoHeight;    // 42
+ (CGFloat)barHeight;           // both lines, 88
+ (CGFloat)sidebarWidth;        // 216

/* bar */
+ (NSColor *)barBase;           // #3a3f48
+ (NSColor *)barLineOneTop;     // #4a505a
+ (NSColor *)barLineOneMid;     // #444a54
+ (NSColor *)barDivide;         // #2b2f36 — the 53% stop
+ (NSColor *)barLineTwoBottom;  // #191c20
+ (NSColor *)barEdge;           // #0d0f11
+ (NSColor *)barInnerHighlight; // white @ 0.18

/* The Vista gloss that the bar is painted with: black at the top edge, a broad
   silver band through the middle, black again at the bottom. Read bottom to
   top, so the band sits just below the halfway point. */
+ (NSColor *)barGlossBottom;     // #0b0d0f
+ (NSColor *)barGlossLower;      // #6e747c
+ (NSColor *)barGlossBand;       // #b9bfc7 — the brightest stop
+ (NSColor *)barGlossUpper;      // #7a808a
+ (NSColor *)barGlossTop;        // #05060a

/* controls inside the bar */
+ (NSColor *)searchWell;        // #1c1f25 — a dark inset, not a white box
+ (NSColor *)searchWellBorder;  // black @ 0.62
+ (NSColor *)searchText;        // #eceef1
+ (NSColor *)searchPlaceholder; // #868d97
+ (NSColor *)roundButtonBase;   // #3d434c
+ (NSColor *)roundButtonHi;     // #565d68
+ (NSColor *)roundButtonLo;     // #2d3238
+ (NSColor *)roundGlyph;        // #e8eaed
+ (NSColor *)roundGlyphDisabled;

/* glossy segmented pills */
+ (NSColor *)pillFace;          // #dfe2e7
+ (NSColor *)pillFaceHi;        // #fdfdfe
+ (NSColor *)pillFaceLo;        // #c3c8d0
+ (NSColor *)pillLabel;         // #3c4048
+ (NSColor *)pillActiveFace;    // #2f7fd4
+ (NSColor *)pillActiveHi;      // #5aa6f2
+ (NSColor *)pillActiveLo;      // #175195
+ (NSColor *)white;

/* the accent, and the one place it is allowed */
+ (NSColor *)accent;            // #3b8ede
+ (NSColor *)accentDark;        // #1a5fae
+ (NSColor *)accentHi;          // #6fb2f7

/* sidebar: black with white text */
+ (NSColor *)sidebarBase;       // #131315
+ (NSColor *)sidebarTop;        // #1a1a1c
+ (NSColor *)sidebarMid;        // #121214
+ (NSColor *)sidebarBottom;     // #0c0c0e
+ (NSColor *)cardBase;          // #16171a
+ (NSColor *)cardHi;            // #242528
+ (NSColor *)cardLo;            // #0d0e10
+ (NSColor *)cardHoverBase;     // #1e1f22
+ (NSColor *)cardActiveBase;    // #30333a
+ (NSColor *)cardActiveHi;      // #4a4e57
+ (NSColor *)cardActiveLo;      // #24262b
+ (NSColor *)cardLabel;         // #f4f5f7
+ (NSColor *)cardSub;           // #9aa0aa
+ (NSColor *)cardIcon;          // #d4d9e0
+ (NSColor *)sideHead;          // #8a8f99
+ (NSColor *)sideRowLabel;      // #f2f3f5
+ (NSColor *)sideRowIcon;       // #b9bec8
+ (NSColor *)densityTrack;      // black @ 0.34

/* content, the light area */
+ (NSColor *)content;           // #ffffff
+ (NSColor *)chrome;            // #f0f1f2
+ (NSColor *)ink;               // #1d1d1f
+ (NSColor *)inkTwo;            // #5a5c60
+ (NSColor *)inkThree;          // #8d9095
+ (NSColor *)line;              // black @ 0.11
+ (NSColor *)lineSoft;          // black @ 0.055

/* status */
+ (NSColor *)ok;                // #2ea043
+ (NSColor *)warn;              // #d18b00
+ (NSColor *)danger;            // #d0342c

/* the blue version disclosure, and the log it prints into */
+ (NSColor *)caretBase;         // #4a90e2
+ (NSColor *)caretHi;           // #8fb8f5
+ (NSColor *)caretLo;           // #2f7fd4
+ (NSColor *)logBackground;     // #14161a
+ (NSColor *)logBorder;         // #2a2e35
+ (NSColor *)logText;           // #9fe8a8
+ (NSColor *)logTextLast;       // #e6f7ea

/* history verb chips */
+ (NSColor *)verbInstallBg;     + (NSColor *)verbInstallFg;
+ (NSColor *)verbUpdateBg;      + (NSColor *)verbUpdateFg;
+ (NSColor *)verbDowngradeBg;   + (NSColor *)verbDowngradeFg;
+ (NSColor *)verbReinstallBg;   + (NSColor *)verbReinstallFg;
+ (NSColor *)verbRemoveBg;      + (NSColor *)verbRemoveFg;

#pragma mark - type

+ (NSFont *)uiFontOfSize:(CGFloat)size;
+ (NSFont *)boldFontOfSize:(CGFloat)size;
+ (NSFont *)smallCapsFontOfSize:(CGFloat)size;   // group headings
+ (NSFont *)monoFontOfSize:(CGFloat)size;       // the install log

#pragma mark - drawing helpers

/* A vertical multi-stop gradient. The bar needs more than two stops, and
   NSGradient's initWithColors:atLocations: is 10.0 but awkward for five. */
+ (void)fillVerticalGradient:(NSRect)rect stops:(NSArray *)stops;

/* The same thing with the two ends named as points instead of as an angle, and
   the end colours extended past them so the whole rect is covered.

   NSGradient draws location 0.0 at the start of the angle, and for a positive
   angle that is the bottom of the rect — but reading it as a half-remembered
   convention is exactly how the bar ends up upside down, so this form spells
   the start and the end out. `stops` is the same even-length array of NSColor
   and NSNumber(0..1) pairs: 0.0 lands on `start`, 1.0 on `end`. */
+ (void)fillGradientInRect:(NSRect)rect
                      from:(NSPoint)start
                        to:(NSPoint)end
                     stops:(NSArray *)stops;

/* A rounded-rect gradient with a 1px border and an optional inner top
   highlight — the card look, used by the sidebar and the pills alike. */
+ (void)fillRoundedGradient:(NSRect)rect
                     radius:(CGFloat)radius
                     topColor:(NSColor *)top
                   midColor:(NSColor *)mid
                   lowColor:(NSColor *)low
                   baseColor:(NSColor *)base
                  borderColor:(NSColor *)border
               innerHighlight:(BOOL)highlight;

/* The Aqua gloss: the top half washed white, which is what sells the era. */
+ (void)fillGloss:(NSRect)rect radius:(CGFloat)radius strength:(CGFloat)strength;

/* A centred glyph drawn from a block, used for the Finder-style density
   icons and the empty-state marks. */
+ (void)drawString:(NSString *)s
             inRect:(NSRect)rect
               font:(NSFont *)font
              color:(NSColor *)color
             center:(BOOL)center;

@end
