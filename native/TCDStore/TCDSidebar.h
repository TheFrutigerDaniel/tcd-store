//
//  TCDSidebar.h
//  TCD Store
//
//  The Store's black panel: Store rows, a View group holding the icon-density
//  control, then the category cards. Downloads has no sidebar at all, so this
//  view is hidden wholesale rather than emptied.
//
//  Rows are drawn by hand rather than by NSOutlineView, because the card look
//  (a rounded gradient row, a white label, a blue tick on the active one) is
//  not something a cell renders. A single NSTableView in view-based mode with
//  three row kinds keeps scrolling and selection for free.
//
//  10.7: view-based NSTableView is 10.0, so this is all available. The density
//  control is three custom buttons rather than NSSegmentedControl, which cannot
//  carry the Finder-style grid glyphs the design calls for.
//

#import <Cocoa/Cocoa.h>
#import "TCDPackage.h"

@class TCDSidebar;

typedef NS_ENUM(NSInteger, TCDSidebarRoute) {
    TCDSidebarRouteFeatured = 0,
    TCDSidebarRouteUpdates,
    TCDSidebarRouteInstalled,
    TCDSidebarRouteSources,
    TCDSidebarRouteSettings,
    TCDSidebarRouteCategory
};

typedef NS_ENUM(NSInteger, TCDIconDensity) {
    TCDIconDensityLarge = 0,   // 3 per row, 128pt icons
    TCDIconDensityMedium,      // 4 per row, 96pt icons   <- the default
    TCDIconDensitySmall        // 5 per row, 64pt icons
};

@protocol TCDSidebarDelegate <NSObject>
- (void)sidebar:(TCDSidebar *)sidebar didSelectRoute:(TCDSidebarRoute)route
                                        section:(NSString *)section;
- (void)sidebar:(TCDSidebar *)sidebar didSelectDensity:(TCDIconDensity)density;
@end

@interface TCDSidebar : NSView

@property (nonatomic, weak) id<TCDSidebarDelegate> delegate;

/* Everything the panel draws from. Passing nil arrays is fine. */
@property (nonatomic, copy)   NSArray *packages;     // TCDPackage
@property (nonatomic, copy)   NSArray *sections;     // NSString, display order
@property (nonatomic, assign) NSUInteger updatesCount;
@property (nonatomic, assign) NSUInteger installedCount;
@property (nonatomic, assign) NSUInteger sourceCount;

@property (nonatomic, assign) TCDSidebarRoute activeRoute;
@property (nonatomic, copy)   NSString *activeSection;

/* Re-runs the row plan from the current packages/sections/counts. Call after
   changing any of them. */
- (void)reload;

/* Session state, not stored in the database. */
@property (nonatomic, assign) TCDIconDensity density;

@end
