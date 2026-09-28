// TCDSidebarView.h
// Permanent sidebar shared by both tabs.
// Contains: search, category buttons, Downloads button, status label.
#import <Cocoa/Cocoa.h>
@class TCDDownloadsViewController;
@class TCDStoreViewController;

@interface TCDSidebarView : NSView

// Injected by AppDelegate after all VCs are created
@property (weak) NSTabView                   *tabView;
@property (weak) TCDDownloadsViewController  *downloadsVC;
@property (weak) TCDStoreViewController      *storeVC;

// Called by TCDStoreViewController when the user types in search
// (search field lives here but filtering lives in the store VC)
@property (copy) void (^onSearchChanged)(NSString *query);

@end
