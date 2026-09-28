// TCDStoreViewController.h
// Manages the store grid only — sidebar has been moved to TCDSidebarView.
#import <Foundation/Foundation.h>
// Cocoa, not Foundation: this header uses NSWindow. The beta branch was
// built with an Xcode prefix header that supplied AppKit implicitly; the
// Makefile build has no prefix header, so the import has to be explicit.
#import <Cocoa/Cocoa.h>
@class TCDDownloadsViewController;

@interface TCDStoreViewController : NSObject
@property (strong, readonly) NSView          *view;
@property (weak) TCDDownloadsViewController  *downloadsVC;

// Called by TCDSidebarView when the user picks a category or types in search
- (void)filterByCategory:(NSString *)category;
- (void)filterBySearch:(NSString *)query;
@end
