// TCDSettingsWindowController.h
// A lightweight settings panel — no NIB, built entirely in code.
// Currently exposes one setting: the download directory.
#import <Cocoa/Cocoa.h>

@interface TCDSettingsWindowController : NSWindowController

// Convenience: alloc+init and keep a strong reference in AppDelegate.
+ (instancetype)sharedController;

// The directory where downloaded .tcdpkg files are saved.
// Defaults to ~/Downloads. Persisted in NSUserDefaults.
@property (copy, readonly) NSString *downloadDirectory;

@end
