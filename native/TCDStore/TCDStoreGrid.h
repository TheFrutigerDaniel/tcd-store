//
//  TCDStoreGrid.h
//  TCD Store
//
//  The large-icon grid: 3, 4 or 5 tiles per row depending on the density, with
//  128, 96 or 64pt icons to match. Tapping a tile opens the package; tapping
//  the blue triangle in its corner unfolds the version menu.
//
//  NSCollectionView would be the obvious choice and cannot be used: it arrived
//  in 10.10. So this is a view that lays its own tile views out into a grid and
//  reports the height it needs back to the enclosing scroll view.
//
//  10.7: no NSStackView, no NSCollectionView, no autolayout. Frames only.
//

#import <Cocoa/Cocoa.h>
#import "TCDPackage.h"
#import "TCDSidebar.h"          // TCDIconDensity lives with the sidebar control

@class TCDStoreGrid;

@protocol TCDStoreGridDelegate <NSObject>
- (void)grid:(TCDStoreGrid *)grid didSelectPackage:(TCDPackage *)pkg;
- (void)grid:(TCDStoreGrid *)grid didTapVersionsForPackage:(TCDPackage *)pkg
                                               atPoint:(NSPoint)point;
- (void)grid:(TCDStoreGrid *)grid didChangeDensity:(TCDIconDensity)density;
@end

@interface TCDStoreGrid : NSView

@property (nonatomic, weak) id<TCDStoreGridDelegate> delegate;
@property (nonatomic, copy) NSArray *packages;     // TCDPackage
@property (nonatomic, assign) TCDIconDensity density;
@property (nonatomic, copy) NSString *emptyMessage;

- (void)reload;
- (void)showEmptyStateWithMessage:(NSString *)message;

/* Columns and icon size, exposed because the detail view and the status bar
   both report the current layout. */
- (NSUInteger)columns;
- (CGFloat)iconSize;

@end
