//
//  TCDTintButton.h
//  TCD Store
//
//  A borderless button that paints a background colour behind its title.
//
//  Same reason as TCDBackgroundView: the base branch tints its shadowless
//  buttons with -wantsLayer / -layer.backgroundColor, which does not exist on
//  10.7. The fill goes in -drawRect: before [super drawRect:], so the title is
//  still drawn on top of it.
//

#import <Cocoa/Cocoa.h>

@interface TCDTintButton : NSButton

/* nil or clearColor draws nothing, which is how the sidebar shows that no
   category is currently selected. */
@property (nonatomic, strong) NSColor *tintColor;

@end
