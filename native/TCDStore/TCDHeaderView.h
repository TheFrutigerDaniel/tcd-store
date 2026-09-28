// TCDHeaderView.h
// Header bar: title, version label, and a settings/gear popup menu on the right.
#import <Cocoa/Cocoa.h>

// Posted when the user picks a grid column count from the menu.
// object = NSNumber with the chosen column count.
extern NSString * const TCDGridColumnsChangedNotification;

@interface TCDHeaderView : NSView
@end
