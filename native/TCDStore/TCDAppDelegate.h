//
//  TCDAppDelegate.h
//  TCD Store
//
//  Owns the window and the top-level Store | Downloads switch. The engine
//  classes (database, parser, resolver, installer, authorizer, signer) are
//  unchanged; this is the layer that was missing — a window that looks like the
//  design, and an install that runs visibly on the Downloads screen.
//

#import <Cocoa/Cocoa.h>

@interface TCDAppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, strong) NSWindow *window;

@end
