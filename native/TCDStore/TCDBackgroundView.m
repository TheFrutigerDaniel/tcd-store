//
//  TCDBackgroundView.m
//  TCD Store
//

#import "TCDBackgroundView.h"

@implementation TCDBackgroundView

+ (id)viewWithFrame:(NSRect)frame color:(NSColor *)color {
    TCDBackgroundView *v =
        [[self alloc] initWithFrame:frame];
    [v setBackgroundColor:color];
    return v;
}

- (void)setBackgroundColor:(NSColor *)color {
    _backgroundColor = color;
    [self setNeedsDisplay:YES];
}

- (void)setCornerRadius:(CGFloat)radius {
    _cornerRadius = radius;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSColor *c = self.backgroundColor;
    if (!c) return;

    NSRect b = [self bounds];
    if (b.size.width <= 0.0 || b.size.height <= 0.0) return;

    if (self.cornerRadius > 0.0) {
        NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:b
                                                          xRadius:self.cornerRadius
                                                          yRadius:self.cornerRadius];
        [c setFill];
        [p fill];
    } else {
        [c setFill];
        NSRectFill(b);
    }
}

@end
