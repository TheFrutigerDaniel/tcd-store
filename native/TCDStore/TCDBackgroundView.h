//
//  TCDBackgroundView.h
//  TCD Store
//
//  A plain view that fills itself with a colour.
//
//  The tcd-store-beta base paints its panels with layer backing:
//
//      v.wantsLayer = YES;
//      v.layer.backgroundColor = colour.CGColor;
//
//  -wantsLayer is 10.8+, and the app targets 10.7, where the setter does not
//  exist and AppKit raises doesNotRecognizeSelector: at launch. So the colour
//  is drawn in -drawRect: instead, which is the same code path the rest of the
//  chrome already uses.
//

#import <Cocoa/Cocoa.h>

@interface TCDBackgroundView : NSView

@property (nonatomic, strong) NSColor *backgroundColor;

/* 0 for a square corner. Anything else draws a rounded rect of that radius,
   which is what the status dot in a card uses. */
@property (nonatomic, assign) CGFloat cornerRadius;

/* Convenience for the common case: a one-liner at the call site. */
+ (id)viewWithFrame:(NSRect)frame color:(NSColor *)color;

@end
