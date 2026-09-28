// TCDDownloadsViewController.h
#import <Foundation/Foundation.h>
// Cocoa, not Foundation: this header uses NSWindow. The beta branch was
// built with an Xcode prefix header that supplied AppKit implicitly; the
// Makefile build has no prefix header, so the import has to be explicit.
#import <Cocoa/Cocoa.h>

@interface TCDDownloadsViewController : NSObject
@property (strong, readonly) NSView *view;
- (void)addDownloadItem:(id)item; // TCDAppItem*
@end
