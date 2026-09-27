//
//  TCDStoreView.h
//  TCD Store
//
//  The Store screen: the black panel on the left, the large-icon grid on the
//  right. The panel is scoped to Store — Downloads is a separate full-width
//  screen and hides this entirely.
//
//  10.7: a plain NSView, not an NSViewController. NSViewController exists on
//  10.7 but has no lifecycle until 10.10, so -viewDidLoad is not available and
//  there is nothing to gain from the indirection.
//

#import <Cocoa/Cocoa.h>
#import "TCDPackage.h"
#import "TCDSidebar.h"
#import "TCDStoreGrid.h"

@class TCDStoreView;

@protocol TCDStoreViewDelegate <NSObject>
- (void)storeView:(TCDStoreView *)view didSelectPackage:(TCDPackage *)pkg;
- (void)storeView:(TCDStoreView *)view didTapVersionsForPackage:(TCDPackage *)pkg;
- (void)storeViewDidSelectRoute:(TCDStoreView *)view
                          route:(TCDSidebarRoute)route
                        section:(NSString *)section;
- (void)storeView:(TCDStoreView *)view didSelectDensity:(TCDIconDensity)density;
@end

@interface TCDStoreView : NSView

@property (nonatomic, weak) id<TCDStoreViewDelegate> delegate;
@property (nonatomic, strong) TCDSidebar *sidebar;
@property (nonatomic, strong) TCDStoreGrid *grid;

/* Everything the screen draws from. */
- (void)setPackages:(NSArray *)packages
        categories:(NSArray *)categories
             sourceCount:(NSUInteger)sourceCount;

- (void)reload;

/* Routing. Search text wins over the current route, exactly as in the
   prototype: typing filters, clearing returns to the route underneath. */
- (void)applyRoute:(TCDSidebarRoute)route section:(NSString *)section;
- (void)applySearch:(NSString *)query;

- (BOOL)canGoBack;
- (void)goBack;

@end
