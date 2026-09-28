//
//  TCDTintButton.m
//  TCD Store
//

#import "TCDTintButton.h"

@implementation TCDTintButton

- (void)setTintColor:(NSColor *)color {
    _tintColor = color;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    NSColor *c = self.tintColor;
    if (c && c != [NSColor clearColor]) {
        NSRect b = [self bounds];
        if (b.size.width > 0.0 && b.size.height > 0.0) {
            [c setFill];
            NSRectFill(b);
        }
    }
    // After the fill, so the title lands on top of the tint rather than
    // underneath it. A borderless button still draws its title from here.
    [super drawRect:dirtyRect];
}

@end
