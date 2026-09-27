//
//  TCDDownloadsView.m
//  TCD Store
//

#import "TCDDownloadsView.h"
#import "TCDTheme.h"

#pragma mark - model

@implementation TCDHistoryEntry
@end

@interface TCDTransfer ()
@property (nonatomic, copy) void (^onChange)(void);
@end

@implementation TCDTransfer

- (id)init {
    self = [super init];
    if (self) {
        _logLines = [NSMutableArray array];
        _startedAt = [NSDate date];
        // NSUUID is 10.8; this is the 10.7 answer.
        _identifier = [[NSProcessInfo processInfo] globallyUniqueString];
    }
    return self;
}

- (TCDPackage *)package { return self.session.primaryPackage; }
- (NSString *)verb { return self.session.verb ?: @"Install"; }
- (NSString *)displayVersion {
    NSString *v = self.session.targetVersion;
    return v.length ? v : (self.session.primaryPackage.version ?: @"");
}

- (NSString *)stepText {
    TCDInstallStep *last = self.session.steps.lastObject;
    if (last.finished) return @"Finishing…";
    return last.title.length ? last.title : @"Starting…";
}

- (double)fraction {
    TCDInstallStep *last = self.session.steps.lastObject;
    return last ? last.fraction : 0.0;
}

- (unsigned long long)totalSizeBytes { return self.session.primaryPackage.sizeBytes; }

- (void)beginObservingWithBlock:(void (^)(void))onChange {
    self.onChange = onChange;
    __weak TCDTransfer *weakSelf = self;
    [self.session setStepChanged:^(TCDInstallStep *step) {
        (void)step;
        if (weakSelf.onChange) weakSelf.onChange();
    }];
    [self.session setLogLine:^(NSString *line, BOOL isError) {
        (void)isError;
        if (!weakSelf) return;
        [weakSelf.logLines addObject:line];
        while (weakSelf.logLines.count > 4) [weakSelf.logLines removeObjectAtIndex:0];
        if (weakSelf.onChange) weakSelf.onChange();
    }];
}

@end

#pragma mark - small shared drawing

static void TCDFillBar(NSRect r, double fraction, NSColor *fill) {
    NSBezierPath *track = [NSBezierPath bezierPathWithRoundedRect:r xRadius:3 yRadius:3];
    [[NSColor colorWithCalibratedRed:0xe8/255.0 green:0xea/255.0 blue:0xee/255.0 alpha:1.0] setFill];
    [track fill];
    if (fraction > 0.001) {
        NSRect f = r;
        f.size.width = NSWidth(r) * (CGFloat)fraction;
        [fill setFill];
        [[NSBezierPath bezierPathWithRoundedRect:f xRadius:3 yRadius:3] fill];
    }
}

static NSColor *TCDFillForVerb(NSString *verb) {
    if ([verb isEqualToString:@"Install"])   return [TCDTheme ok];
    if ([verb isEqualToString:@"Update"])    return [TCDTheme accent];
    if ([verb isEqualToString:@"Downgrade"]) return [TCDTheme warn];
    if ([verb isEqualToString:@"Reinstall"]) return [NSColor colorWithCalibratedWhite:0.40 alpha:1.0];
    if ([verb isEqualToString:@"Remove"])    return [TCDTheme danger];
    return [TCDTheme accent];
}

static void TCDChipColours(NSString *verb, NSColor **bg, NSColor **fg) {
    if ([verb isEqualToString:@"Install"])   { *bg = [TCDTheme verbInstallBg];   *fg = [TCDTheme verbInstallFg]; }
    else if ([verb isEqualToString:@"Update"])    { *bg = [TCDTheme verbUpdateBg];    *fg = [TCDTheme verbUpdateFg]; }
    else if ([verb isEqualToString:@"Downgrade"]) { *bg = [TCDTheme verbDowngradeBg]; *fg = [TCDTheme verbDowngradeFg]; }
    else if ([verb isEqualToString:@"Reinstall"]) { *bg = [TCDTheme verbReinstallBg]; *fg = [TCDTheme verbReinstallFg]; }
    else if ([verb isEqualToString:@"Remove"])    { *bg = [TCDTheme verbRemoveBg];    *fg = [TCDTheme verbRemoveFg]; }
    else { *bg = [TCDTheme verbInstallBg]; *fg = [TCDTheme verbInstallFg]; }
}

#pragma mark - the transfer row

@interface TCDTransferRow : NSView
@property (nonatomic, strong) TCDTransfer *transfer;
@property (nonatomic, copy) void (^onCancel)(void);
@property (nonatomic, strong) NSButton *cancelButton;
- (id)initWithFrame:(NSRect)frame onCancel:(void (^)(void))onCancel;
@end

@implementation TCDTransferRow

- (id)initWithFrame:(NSRect)frame onCancel:(void (^)(void))onCancel {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _onCancel = [onCancel copy];
    self.cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 62, 18)];
    [self.cancelButton setTitle:@"Cancel"];
    [self.cancelButton setBezelStyle:NSRoundedBezelStyle];
    [self.cancelButton setFont:[TCDTheme uiFontOfSize:10.5]];
    [self.cancelButton setTarget:self];
    [self.cancelButton setAction:@selector(cancelClicked:)];
    [self addSubview:self.cancelButton];
    return self;
}

- (void)setTransfer:(TCDTransfer *)t { _transfer = t; [self setNeedsDisplay:YES]; }
- (void)cancelClicked:(id)sender { if (self.onCancel) self.onCancel(); }
- (BOOL)isFlipped { return YES; }

- (void)layout {
    self.cancelButton.frame = NSMakeRect(NSWidth([self bounds]) - 76.0, 10.0, 62.0, 18.0);
}

- (void)drawRect:(NSRect)dirty {
    (void)dirty;
    [self layout];
    NSRect b = [self bounds];
    TCDTransfer *t = self.transfer;
    if (!t) return;

    NSRect card = NSInsetRect(b, 0.0, 3.0);
    [TCDTheme fillRoundedGradient:card radius:8.0
                       topColor:[TCDTheme content]
                       midColor:[TCDTheme content]
                       lowColor:[NSColor colorWithCalibratedRed:0xf6/255.0 green:0xf7/255.0 blue:0xf8/255.0 alpha:1.0]
                      baseColor:[TCDTheme content]
                     borderColor:[TCDTheme line]
                  innerHighlight:NO];

    CGFloat pad = 14.0;
    CGFloat x = NSMinX(card) + pad;
    CGFloat top = NSMaxY(card) - pad;

    NSDictionary *va = @{
        NSFontAttributeName: [TCDTheme boldFontOfSize:9.5],
        NSForegroundColorAttributeName: [TCDTheme white] };
    NSString *verb = [t verb];
    NSSize vs = [verb sizeWithAttributes:va];
    NSRect chip = NSMakeRect(x, top - 15.0, vs.width + 12.0, 15.0);
    [TCDFillForVerb(verb) setFill];
    [[NSBezierPath bezierPathWithRoundedRect:chip xRadius:3 yRadius:3] fill];
    [verb drawAtPoint:NSMakePoint(NSMinX(chip) + 6.0, NSMidY(chip) - vs.height / 2.0)
       withAttributes:va];
    x = NSMaxX(chip) + 8.0;

    NSDictionary *na = @{
        NSFontAttributeName: [TCDTheme boldFontOfSize:13.5],
        NSForegroundColorAttributeName: [TCDTheme ink] };
    [t.package.name drawAtPoint:NSMakePoint(x, NSMaxY(chip) + 1.0) withAttributes:na];
    x += [t.package.name sizeWithAttributes:na].width + 6.0;

    if ([t displayVersion].length) {
        NSDictionary *a2 = @{
            NSFontAttributeName: [TCDTheme uiFontOfSize:12.0],
            NSForegroundColorAttributeName: [TCDTheme inkThree] };
        [[NSString stringWithFormat:@"v%@", [t displayVersion]]
            drawAtPoint:NSMakePoint(x, NSMaxY(chip) + 2.0) withAttributes:a2];
    }

    NSDictionary *sa = @{
        NSFontAttributeName: [TCDTheme uiFontOfSize:11.5],
        NSForegroundColorAttributeName: [TCDTheme inkTwo] };
    [[t stepText] drawAtPoint:NSMakePoint(NSMinX(card) + pad, NSMaxY(chip) - 16.0)
                withAttributes:sa];

    NSDictionary *ma = @{
        NSFontAttributeName: [TCDTheme uiFontOfSize:11.0],
        NSForegroundColorAttributeName: [TCDTheme inkThree] };
    NSString *meta = [NSString stringWithFormat:@"%llu KB", t.totalSizeBytes / 1024ULL];
    NSSize ms = [meta sizeWithAttributes:ma];
    [meta drawAtPoint:NSMakePoint(NSMaxX(card) - pad - ms.width, NSMaxY(chip) - 15.0)
       withAttributes:ma];

    // bar, percentage, cancel
    NSRect bar = NSMakeRect(NSMinX(card) + pad, NSMaxY(chip) - 36.0,
                            NSWidth(card) - pad * 2.0 - 150.0, 6.0);
    TCDFillBar(bar, [t fraction], [TCDTheme accent]);
    NSString *pct = [NSString stringWithFormat:@"%.0f%%", [t fraction] * 100.0];
    [pct drawAtPoint:NSMakePoint(NSMaxX(bar) + 8.0, NSMinY(bar) - 4.0)
       withAttributes:ma];

    // the log: real installer output in a dark well
    if (t.logLines.count) {
        NSRect log = NSMakeRect(NSMinX(card) + pad, NSMinY(card) + 8.0,
                                NSWidth(card) - pad * 2.0, 30.0);
        NSBezierPath *lp = [NSBezierPath bezierPathWithRoundedRect:log xRadius:5 yRadius:5];
        [[TCDTheme logBackground] setFill];
        [lp fill];
        [[TCDTheme logBorder] setStroke];
        [lp setLineWidth:1.0];
        [lp stroke];
        NSDictionary *la = @{
            NSFontAttributeName: [TCDTheme monoFontOfSize:10.0],
            NSForegroundColorAttributeName: [TCDTheme logText] };
        CGFloat ly = NSMaxY(log) - 4.0;
        for (NSString *line in t.logLines) {
            [line drawAtPoint:NSMakePoint(NSMinX(log) + 7.0, ly) withAttributes:la];
            ly -= 12.0;
        }
    }
}

@end

#pragma mark - the history row

@interface TCDHistoryRow : NSView
@property (nonatomic, strong) TCDHistoryEntry *entry;
@end

@implementation TCDHistoryRow

- (void)setEntry:(TCDHistoryEntry *)e { _entry = e; [self setNeedsDisplay:YES]; }
- (BOOL)isFlipped { return YES; }

- (void)drawRect:(NSRect)dirty {
    (void)dirty;
    NSRect b = [self bounds];
    [[TCDTheme content] setFill];
    NSRectFill(b);
    [[TCDTheme lineSoft] setFill];
    NSRectFill(NSMakeRect(14.0, NSMinY(b), NSWidth(b) - 28.0, 1.0));

    NSColor *bg, *fg;
    TCDChipColours(self.entry.verb, &bg, &fg);
    NSDictionary *va = @{
        NSFontAttributeName: [TCDTheme boldFontOfSize:10.5],
        NSForegroundColorAttributeName: fg };
    NSSize vs = [self.entry.verb sizeWithAttributes:va];
    NSRect chip = NSMakeRect(14.0, NSMidY(b) - 9.0, vs.width + 14.0, 18.0);
    [bg setFill];
    [[NSBezierPath bezierPathWithRoundedRect:chip xRadius:4 yRadius:4] fill];
    [self.entry.verb drawAtPoint:NSMakePoint(NSMinX(chip) + 7.0,
                                             NSMidY(chip) - vs.height / 2.0)
                   withAttributes:va];

    CGFloat x = NSMaxX(chip) + 12.0;
    NSDictionary *na = @{
        NSFontAttributeName: [TCDTheme uiFontOfSize:12.5],
        NSForegroundColorAttributeName: [TCDTheme ink] };
    [self.entry.name drawAtPoint:NSMakePoint(x, NSMidY(b) - 8.0) withAttributes:na];
    x += [self.entry.name sizeWithAttributes:na].width + 8.0;

    NSDictionary *a2 = @{
        NSFontAttributeName: [TCDTheme uiFontOfSize:12.0],
        NSForegroundColorAttributeName: [TCDTheme inkThree] };
    [[NSString stringWithFormat:@"v%@", self.entry.version]
        drawAtPoint:NSMakePoint(x, NSMidY(b) - 8.0) withAttributes:a2];

    NSDictionary *da = @{
        NSFontAttributeName: [TCDTheme uiFontOfSize:11.0],
        NSForegroundColorAttributeName: [TCDTheme inkThree] };
    NSString *when = [self relativeTime];
    NSSize ds = [when sizeWithAttributes:da];
    [when drawAtPoint:NSMakePoint(NSMaxX(b) - 14.0 - ds.width, NSMidY(b) - 7.0)
       withAttributes:da];
}

- (NSString *)relativeTime {
    NSTimeInterval secs = -[self.entry.when timeIntervalSinceNow];
    if (secs < 45)    return @"just now";
    if (secs < 3600)  return [NSString stringWithFormat:@"%.0f min ago", secs / 60.0];
    if (secs < 86400) return [NSString stringWithFormat:@"%.0f h ago", secs / 3600.0];
    return [NSString stringWithFormat:@"%.0f d ago", secs / 86400.0];
}

@end

#pragma mark - the empty plate

@interface TCDEmptyPlate : NSView
@property (nonatomic, copy) NSString *message;
@end

@implementation TCDEmptyPlate
- (void)setMessage:(NSString *)m { _message = [m copy]; [self setNeedsDisplay:YES]; }
- (void)drawRect:(NSRect)dirty {
    (void)dirty;
    NSRect r = NSInsetRect([self bounds], 0.0, 0.0);
    [TCDTheme fillRoundedGradient:r radius:8.0
                       topColor:[TCDTheme content]
                       midColor:[TCDTheme content]
                       lowColor:[NSColor colorWithCalibratedRed:0xf6/255.0 green:0xf7/255.0 blue:0xf8/255.0 alpha:1.0]
                      baseColor:[TCDTheme content]
                     borderColor:[TCDTheme line]
                  innerHighlight:NO];
    [TCDTheme drawString:self.message ?: @""
                  inRect:NSInsetRect(r, 16.0, 16.0)
                    font:[TCDTheme uiFontOfSize:12.0]
                   color:[TCDTheme inkThree]
                  center:YES];
}
@end

#pragma mark - a flipped canvas, so y grows downward like the design

@interface TCDDownloadsCanvas : NSView
@end

@implementation TCDDownloadsCanvas
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirty { (void)dirty; [[TCDTheme content] setFill]; NSRectFill([self bounds]); }
@end

#pragma mark - the view

@interface TCDDownloadsView ()
@property (nonatomic, strong) NSMutableArray *transfers;
@property (nonatomic, strong) NSMutableArray *history;
@property (nonatomic, strong) NSScrollView *scroll;
@property (nonatomic, strong) TCDDownloadsCanvas *canvas;
@property (nonatomic, strong) NSButton *clearButton;
@end

@implementation TCDDownloadsView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.transfers = [NSMutableArray array];
    self.history = [NSMutableArray array];

    self.canvas = [[TCDDownloadsCanvas alloc] initWithFrame:
        NSMakeRect(0.0, 0.0, NSWidth(frame), 0.0)];

    self.scroll = [[NSScrollView alloc] initWithFrame:frame];
    [self.scroll setDocumentView:self.canvas];
    [self.scroll setHasVerticalScroller:YES];
    [self.scroll setAutohidesScrollers:YES];
    [self.scroll setBorderType:NSNoBorder];
    [self.scroll setDrawsBackground:NO];
    [self.scroll setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self addSubview:self.scroll];

    self.clearButton = [[NSButton alloc] initWithFrame:NSMakeRect(0.0, 0.0, 110.0, 20.0)];
    [self.clearButton setTitle:@"Clear History"];
    [self.clearButton setBezelStyle:NSRoundedBezelStyle];
    [self.clearButton setFont:[TCDTheme uiFontOfSize:11.0]];
    [self.clearButton setTarget:self];
    [self.clearButton setAction:@selector(clearHistoryClicked:)];

    [self relayout];
    return self;
}

- (BOOL)isFlipped { return YES; }

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [self relayout];
}

#pragma mark - queue

- (void)addTransfer:(TCDTransfer *)transfer {
    if (!transfer) return;
    [self.transfers addObject:transfer];
    __weak TCDDownloadsView *weakSelf = self;
    [transfer beginObservingWithBlock:^{ [weakSelf relayout]; }];
    [self relayout];
    if (self.onBecameNonEmpty) self.onBecameNonEmpty(YES);
}

- (void)removeTransferWithIdentifier:(NSString *)identifier {
    NSUInteger i = [self indexOfTransfer:identifier];
    if (i == NSNotFound) return;
    TCDTransfer *t = self.transfers[i];
    [self.transfers removeObjectAtIndex:i];

    // A run that finished becomes a history row; a cancelled one does not.
    if (t.session.finished && !t.session.cancelled) {
        TCDHistoryEntry *e = [[TCDHistoryEntry alloc] init];
        e.name = t.package.name;
        e.version = [t displayVersion];
        e.verb = [t verb];
        e.when = [NSDate date];
        [self.history insertObject:e atIndex:0];
    }
    [self relayout];
    if (self.onBecameNonEmpty) self.onBecameNonEmpty(self.transfers.count > 0);
}

- (NSUInteger)indexOfTransfer:(NSString *)identifier {
    for (NSUInteger i = 0; i < self.transfers.count; i++) {
        // -objectAtIndexedSubscript: returns id, and dot syntax on id has no
        // declared property to resolve, so the element needs a type first.
        TCDTransfer *t = self.transfers[i];
        if ([t.identifier isEqualToString:identifier]) return i;
    }
    return NSNotFound;
}

- (NSUInteger)activeCount { return self.transfers.count; }

- (void)addHistoryEntry:(TCDHistoryEntry *)entry {
    if (entry) [self.history insertObject:entry atIndex:0];
    [self relayout];
}

- (void)clearHistory {
    [self.history removeAllObjects];
    [self relayout];
}

- (void)clearHistoryClicked:(id)sender { [self clearHistory]; }

#pragma mark - layout

- (void)relayout {
    for (NSView *v in [[self.canvas subviews] copy]) [v removeFromSuperview];

    CGFloat w = NSWidth([self bounds]);
    CGFloat inset = 24.0;
    CGFloat contentW = w - inset * 2.0;
    CGFloat y = 20.0;

    [self.canvas addSubview:[self headingWithTitle:@"Active" y:y width:w inset:inset]];
    y += 32.0;

    if (!self.transfers.count) {
        TCDEmptyPlate *p = [[TCDEmptyPlate alloc] initWithFrame:
            NSMakeRect(inset, y, contentW, 64.0)];
        p.message = @"Nothing in flight. Install something and it runs here.";
        [self.canvas addSubview:p];
        y += 64.0 + 14.0;
    } else {
        for (TCDTransfer *t in self.transfers) {
            __weak TCDDownloadsView *weakSelf = self;
            NSString *ident = t.identifier;
            TCDTransferRow *r = [[TCDTransferRow alloc] initWithFrame:
                NSMakeRect(inset, y, contentW, 124.0)
                                                   onCancel:^{
                if (weakSelf.onCancelTransfer) weakSelf.onCancelTransfer(ident);
            }];
            r.transfer = t;
            [self.canvas addSubview:r];
            y += 124.0 + 8.0;
        }
    }

    y += 10.0;
    [self.canvas addSubview:[self headingWithTitle:@"History" y:y width:w inset:inset]];
    y += 32.0;

    [self.clearButton setHidden:!self.history.count];
    [self.clearButton setFrameOrigin:NSMakePoint(w - inset - 110.0, y - 24.0)];
    [self.canvas addSubview:self.clearButton];

    if (self.history.count) {
        for (TCDHistoryEntry *e in self.history) {
            TCDHistoryRow *r = [[TCDHistoryRow alloc] initWithFrame:
                NSMakeRect(inset, y, contentW, 30.0)];
            r.entry = e;
            [self.canvas addSubview:r];
            y += 30.0;
        }
    } else {
        NSTextField *none = [[NSTextField alloc] initWithFrame:
            NSMakeRect(inset, y, contentW, 20.0)];
        [none setStringValue:@"Nothing installed or removed yet."];
        [none setBezeled:NO];
        [none setDrawsBackground:NO];
        [none setEditable:NO];
        [none setSelectable:NO];
        [none setFont:[TCDTheme uiFontOfSize:11.5]];
        [[none cell] setTextColor:[TCDTheme inkThree]];
        [self.canvas addSubview:none];
        y += 26.0;
    }

    [self.canvas setFrameSize:NSMakeSize(w, y + 20.0)];
}

- (NSTextField *)headingWithTitle:(NSString *)title y:(CGFloat)y width:(CGFloat)w inset:(CGFloat)inset {
    NSTextField *l = [[NSTextField alloc] initWithFrame:
        NSMakeRect(inset, y, w - inset * 2.0, 22.0)];
    [l setStringValue:title];
    [l setBezeled:NO];
    [l setDrawsBackground:NO];
    [l setEditable:NO];
    [l setSelectable:NO];
    [l setFont:[TCDTheme boldFontOfSize:15.0]];
    [[l cell] setTextColor:[TCDTheme ink]];
    return l;
}

@end
