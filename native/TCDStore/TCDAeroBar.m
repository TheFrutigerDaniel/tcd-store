//
//  TCDAeroBar.m
//  TCD Store
//

#import "TCDAeroBar.h"
#import "TCDTheme.h"

#pragma mark - a glossy pill

@interface TCDAeroPill : NSButton
@property (nonatomic, assign) BOOL selected;
@property (nonatomic, assign) NSUInteger badgeCount;
@end

@implementation TCDAeroPill

- (void)drawRect:(NSRect)dirty {
    NSRect r = NSInsetRect([self bounds], 0.0, 1.0);
    if (self.selected) {
        [TCDTheme fillRoundedGradient:r radius:5.0
                           topColor:[TCDTheme pillActiveHi]
                           midColor:[TCDTheme pillActiveFace]
                           lowColor:[TCDTheme pillActiveLo]
                          baseColor:[TCDTheme pillActiveFace]
                         borderColor:[TCDTheme barEdge]
                      innerHighlight:YES];
        [TCDTheme fillGloss:r radius:5.0 strength:0.30];
    } else {
        [TCDTheme fillRoundedGradient:r radius:5.0
                           topColor:[TCDTheme pillFaceHi]
                           midColor:[TCDTheme pillFace]
                           lowColor:[TCDTheme pillFaceLo]
                          baseColor:[TCDTheme pillFace]
                         borderColor:[TCDTheme barEdge]
                      innerHighlight:YES];
        [TCDTheme fillGloss:r radius:5.0 strength:0.78];
    }

    NSString *title = [self title];
    if (self.badgeCount > 0) {
        title = [NSString stringWithFormat:@"%@  %lu", title,
                 (unsigned long)self.badgeCount];
    }
    NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
    [attrs setObject:[TCDTheme boldFontOfSize:12.0] forKey:NSFontAttributeName];
    [attrs setObject:(self.selected ? [TCDTheme white] : [TCDTheme pillLabel])
              forKey:NSForegroundColorAttributeName];
    NSSize size = [title sizeWithAttributes:attrs];
    [title drawAtPoint:NSMakePoint(NSMidX([self bounds]) - size.width / 2.0,
                                   NSMidY([self bounds]) - size.height / 2.0 + 1.0)
         withAttributes:attrs];
}

@end

#pragma mark - a round dark-glass toolbar button

typedef NS_ENUM(NSInteger, TCDAeroRoundGlyph) {
    TCDAeroRoundGlyphBack = 0,
    TCDAeroRoundGlyphRefresh
};

/* The titles on these are for tooltips and VoiceOver only — drawing the word
   "Back" inside a 26pt circle would be nonsense, so the glyphs are vectors. */
@interface TCDAeroRoundButton : NSButton
@property (nonatomic, assign) TCDAeroRoundGlyph glyph;
@property (nonatomic, assign) BOOL pressed;
@end

@implementation TCDAeroRoundButton

/* NSButton has no -isHighlighted to hang a gradient off, and the stock bezel
   is not what we want, so the press state is tracked by hand. */
- (void)mouseDown:(NSEvent *)e {
    (void)e;
    if (!self.isEnabled) return;
    self.pressed = YES;
    [self setNeedsDisplay:YES];
}
- (void)mouseUp:(NSEvent *)e {
    (void)e;
    self.pressed = NO;
    [self setNeedsDisplay:YES];
}
- (void)mouseExited:(NSEvent *)e {
    (void)e;
    if (self.pressed) { self.pressed = NO; [self setNeedsDisplay:YES]; }
}

- (void)drawRect:(NSRect)dirty {
    NSRect r = NSInsetRect([self bounds], 0.0, 0.5);
    BOOL live = self.isEnabled && self.pressed;
    [TCDTheme fillRoundedGradient:r radius:13.0
                       topColor:(live ? [NSColor colorWithCalibratedWhite:0.55 alpha:1.0]
                                      : [TCDTheme roundButtonHi])
                       midColor:[TCDTheme roundButtonBase]
                       lowColor:[TCDTheme roundButtonLo]
                      baseColor:[TCDTheme roundButtonBase]
                     borderColor:[TCDTheme barEdge]
                  innerHighlight:YES];

    NSColor *ink = self.isEnabled ? [TCDTheme roundGlyph] : [TCDTheme roundGlyphDisabled];
    [ink setStroke];
    [ink setFill];

    CGFloat cx = NSMidX(r), cy = NSMidY(r);
    if (self.glyph == TCDAeroRoundGlyphBack) {
        NSBezierPath *chevron = [NSBezierPath bezierPath];
        [chevron moveToPoint:NSMakePoint(cx + 3.0, cy + 4.5)];
        [chevron lineToPoint:NSMakePoint(cx - 2.5, cy)];
        [chevron lineToPoint:NSMakePoint(cx + 3.0, cy - 4.5)];
        [chevron setLineWidth:1.7];
        [chevron stroke];
    } else {
        NSBezierPath *arc = [NSBezierPath bezierPath];
        [arc appendBezierPathWithArcWithCenter:NSMakePoint(cx, cy)
                                        radius:4.6
                                    startAngle:40.0
                                      endAngle:320.0];
        [arc setLineWidth:1.6];
        [arc stroke];
        // the arrowhead that makes it read as "refresh" and not a broken ring
        NSBezierPath *head = [NSBezierPath bezierPath];
        [head moveToPoint:NSMakePoint(cx + 5.4, cy + 3.6)];
        [head lineToPoint:NSMakePoint(cx + 5.4, cy - 0.6)];
        [head lineToPoint:NSMakePoint(cx + 1.6, cy + 1.4)];
        [head closePath];
        [head fill];
    }
}

@end

#pragma mark - the bar

@interface TCDAeroBar ()
@property (nonatomic, strong) NSTextField *wordmark;
@property (nonatomic, strong) TCDAeroPill *storePill;
@property (nonatomic, strong) TCDAeroPill *downloadsPill;
@property (nonatomic, strong) NSSearchField *searchField;
@property (nonatomic, strong) NSButton *clearButton;
@property (nonatomic, strong) TCDAeroRoundButton *backButton;
@property (nonatomic, strong) TCDAeroRoundButton *refreshButton;
@property (nonatomic, strong) NSButton *updateAllButton;
@end

@implementation TCDAeroBar

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    [self buildBar];
    return self;
}

- (void)buildBar {
    // No geometry here: every frame is set by -layoutBar once the views exist,
    // so a later resize or metric change has exactly one place to go.

    // ---- line one: wordmark left, pills right ----
    self.wordmark = [self labelWithString:@"TCD store"
                                     font:[TCDTheme boldFontOfSize:14.0]
                                    color:[TCDTheme white]
                                    frame:NSMakeRect(14.0, 0.0, 200.0, 18.0)];
    [self addSubview:self.wordmark];

    self.storePill = [self pillWithTitle:@"Store"
                                 action:@selector(storePillClicked:)];
    self.downloadsPill = [self pillWithTitle:@"Downloads"
                                    action:@selector(downloadsPillClicked:)];
    [self addSubview:self.storePill];
    [self addSubview:self.downloadsPill];

    // ---- line two: the search well, then the round buttons ----
    self.searchField = [[NSSearchField alloc] initWithFrame:
        NSMakeRect(18.0, 0.0, 300.0, 25.0)];
    [self.searchField setBezeled:NO];
    [self.searchField setDrawsBackground:NO];
    [self.searchField setEditable:YES];
    [self.searchField setSelectable:YES];
    [self.searchField setFont:[TCDTheme uiFontOfSize:12.5]];
    [self.searchField setTextColor:[TCDTheme searchText]];
    // the stock search bezel is a white pill; the field inside a black bar
    // must not be, so the bezel goes and the well is painted in -drawRect:
    [self.searchField setBordered:NO];
    [[self.searchField cell] setPlaceholderString:@"search..."];
    [self.searchField setTarget:self];
    [self.searchField setAction:@selector(searchFieldChanged:)];
    [self addSubview:self.searchField];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(searchFieldChanged:)
                                                 name:NSControlTextDidChangeNotification
                                               object:self.searchField];

    self.clearButton = [[NSButton alloc] initWithFrame:NSMakeRect(300.0, 5.0, 16.0, 16.0)];
    [self.clearButton setTitle:@"×"];
    [self.clearButton setBezelStyle:NSRegularSquareBezelStyle];
    [self.clearButton setFont:[TCDTheme boldFontOfSize:12.0]];
    [self.clearButton setTarget:self];
    [self.clearButton setAction:@selector(clearButtonClicked:)];
    [self.clearButton setHidden:YES];
    [self addSubview:self.clearButton];

    self.backButton = [self roundButtonWithGlyph:TCDAeroRoundGlyphBack
                                     tooltip:@"Back"
                                     action:@selector(backClicked:)];
    self.refreshButton = [self roundButtonWithGlyph:TCDAeroRoundGlyphRefresh
                                         tooltip:@"Refresh sources"
                                         action:@selector(refreshClicked:)];
    [self addSubview:self.backButton];
    [self addSubview:self.refreshButton];

    self.updateAllButton = [[NSButton alloc] initWithFrame:NSMakeRect(0.0, 0.0, 108.0, 25.0)];
    [self.updateAllButton setTitle:@"⇩  Update All"];
    [self.updateAllButton setBezelStyle:NSRoundedBezelStyle];
    [self.updateAllButton setFont:[TCDTheme boldFontOfSize:12.0]];
    [self.updateAllButton setTarget:self];
    [self.updateAllButton setAction:@selector(updateAllClicked:)];
    [self.updateAllButton setHidden:YES];
    [self addSubview:self.updateAllButton];

    self.activeView = TCDAeroViewStore;
    [self layoutBar];
}

- (TCDAeroPill *)pillWithTitle:(NSString *)title action:(SEL)action {
    TCDAeroPill *b = [[TCDAeroPill alloc] initWithFrame:NSMakeRect(0.0, 0.0, 88.0, 26.0)];
    [b setTitle:title];
    [b setTarget:self];
    [b setAction:action];
    [b setBezelStyle:NSRoundedBezelStyle];
    [b setFont:[TCDTheme boldFontOfSize:12.0]];
    [b setKeyEquivalent:@""];
    [b setToolTip:title];
    return b;
}

- (TCDAeroRoundButton *)roundButtonWithGlyph:(TCDAeroRoundGlyph)glyph
                                   tooltip:(NSString *)tooltip
                                     action:(SEL)action {
    TCDAeroRoundButton *b = [[TCDAeroRoundButton alloc] initWithFrame:
        NSMakeRect(0.0, 0.0, 26.0, 25.0)];
    b.glyph = glyph;
    [b setTitle:tooltip];          // VoiceOver and the tooltip, nothing else
    [b setBezelStyle:NSRoundedBezelStyle];
    [b setTarget:self];
    [b setAction:action];
    [b setToolTip:tooltip];
    return b;
}

- (NSTextField *)labelWithString:(NSString *)s
                            font:(NSFont *)f
                           color:(NSColor *)c
                           frame:(NSRect)frame {
    NSTextField *l = [[NSTextField alloc] initWithFrame:frame];
    [l setStringValue:s];
    [l setBezeled:NO];
    [l setDrawsBackground:NO];
    [l setEditable:NO];
    [l setSelectable:NO];
    [l setFont:f];
    [[l cell] setTextColor:c];
    return l;
}

#pragma mark - painting

- (void)drawRect:(NSRect)dirtyRect {
    NSRect b = [self bounds];

    // The ramp is the whole point: one surface, light at the top, dark at the
    // bottom, with the 53% stop sitting on the seam between the two lines so
    // the eye reads a single bar rather than two stacked strips.
    [TCDTheme fillVerticalGradient:b
        stops:@[[TCDTheme barLineOneTop],   @(0.0),
                [TCDTheme barLineOneMid],   @(0.26),
                [TCDTheme barBase],         @(0.47),
                [TCDTheme barDivide],       @(0.53),
                [TCDTheme barLineTwoBottom], @(1.0)]];

    [[TCDTheme barInnerHighlight] setFill];
    NSRectFill(NSMakeRect(0.0, NSMaxY(b) - 1.0, NSWidth(b), 1.0));

    // The search well is painted here so the field itself can stay borderless.
    NSRect well = NSInsetRect([self.searchField frame], -6.0, -3.0);
    NSBezierPath *wp = [NSBezierPath bezierPathWithRoundedRect:well
                                                       xRadius:13.0 yRadius:13.0];
    [[TCDTheme searchWell] setFill];
    [wp fill];
    [[TCDTheme searchWellBorder] setStroke];
    [wp setLineWidth:1.0];
    [wp stroke];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.10] setFill];
    NSRectFill(NSMakeRect(NSMinX(well) + 1.0, NSMaxY(well) - 1.0,
                          NSWidth(well) - 2.0, 1.0));

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

    [self.wordmark setFrameOrigin:NSMakePoint(14.0, h2 + (h1 - 18.0) / 2.0)];

    CGFloat dlW = 100.0, stW = 88.0, right = w - 14.0;
    [self.downloadsPill setFrame:NSMakeRect(right - dlW, h2 + (h1 - 26.0) / 2.0, dlW, 26.0)];
    [self.storePill setFrame:NSMakeRect(right - 6.0 - dlW - stW,
                                        h2 + (h1 - 26.0) / 2.0, stW, 26.0)];

    CGFloat y = (h2 - 25.0) / 2.0;
    CGFloat x = right - 108.0;
    [self.updateAllButton setFrame:NSMakeRect(x, y, 108.0, 25.0)];
    x -= 6.0 + 26.0;
    [self.refreshButton setFrame:NSMakeRect(x, y, 26.0, 25.0)];
    x -= 6.0 + 26.0;
    [self.backButton setFrame:NSMakeRect(x, y, 26.0, 25.0)];

    [self.searchField setFrameOrigin:NSMakePoint(18.0, y)];
    [self.clearButton setFrameOrigin:NSMakePoint(
        NSMaxX([self.searchField frame]) - 16.0, y + 5.0)];
}

#pragma mark - state

- (void)setActiveView:(TCDAeroView)activeView {
    _activeView = activeView;
    self.storePill.selected = (activeView == TCDAeroViewStore);
    self.downloadsPill.selected = (activeView == TCDAeroViewDownloads);
    [self.storePill setNeedsDisplay:YES];
    [self.downloadsPill setNeedsDisplay:YES];
}

- (void)setDownloadCount:(NSUInteger)downloadCount {
    _downloadCount = downloadCount;
    self.downloadsPill.badgeCount = downloadCount;
    [self.downloadsPill setNeedsDisplay:YES];
}

- (void)setUpdateAllVisible:(BOOL)visible {
    _updateAllVisible = visible;
    [self.updateAllButton setHidden:!visible];
}

- (void)focusSearch { [self.window makeFirstResponder:self.searchField]; }

- (void)clearSearch {
    [self.searchField setStringValue:@""];
    [self.clearButton setHidden:YES];
    [self searchFieldChanged:self.searchField];
}

#pragma mark - actions

- (void)storePillClicked:(id)sender {
    [self setActiveView:TCDAeroViewStore];
    if ([self.delegate respondsToSelector:@selector(aeroBar:didSelectView:)])
        [self.delegate aeroBar:self didSelectView:TCDAeroViewStore];
}

- (void)downloadsPillClicked:(id)sender {
    [self setActiveView:TCDAeroViewDownloads];
    if ([self.delegate respondsToSelector:@selector(aeroBar:didSelectView:)])
        [self.delegate aeroBar:self didSelectView:TCDAeroViewDownloads];
}

- (void)searchFieldChanged:(id)sender {
    [self.clearButton setHidden:self.searchField.stringValue.length == 0];
    if ([self.delegate respondsToSelector:@selector(aeroBar:didChangeSearch:)])
        [self.delegate aeroBar:self didChangeSearch:self.searchField.stringValue];
}

- (void)clearButtonClicked:(id)sender { [self clearSearch]; }

- (void)backClicked:(id)sender {
    if ([self.delegate respondsToSelector:@selector(aeroBarDidGoBack:)])
        [self.delegate aeroBarDidGoBack:self];
}

- (void)refreshClicked:(id)sender {
    if ([self.delegate respondsToSelector:@selector(aeroBarDidRefresh:)])
        [self.delegate aeroBarDidRefresh:self];
}

- (void)updateAllClicked:(id)sender {
    if ([self.delegate respondsToSelector:@selector(aeroBarDidUpdateAll:)])
        [self.delegate aeroBarDidUpdateAll:self];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
