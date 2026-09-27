//
//  TCDStoreGrid.h
//  TCD Store
//
//  The large-icon grid.
//
//  This is an NSCollectionView. The first version hand-laid the tiles out in a
//  clip view and grew the document view by hand, which is a lot of code to
//  re-implement scrolling, item reuse and selection, and none of it was as
//  good as the stock behaviour. NSCollectionView is not new technology here —
//  it has existed since 10.5 — it is just much older than the rewrite people
//  usually reach for.
//
//  The tiles are plain: an image, a name, a version. The one piece of the
//  original design that survives is the blue version triangle, which is a real
//  NSButton so that its hover and press come from the system rather than from
//  hand-written tracking areas.
//

#import <Cocoa/Cocoa.h>
#import "TCDPackage.h"
#import "TCDSidebar.h"          // TCDIconDensity

@class TCDStoreGrid;

@protocol TCDStoreGridDelegate <NSObject>
- (void)grid:(TCDStoreGrid *)grid didSelectPackage:(TCDPackage *)pkg;
- (void)grid:(TCDStoreGrid *)grid didTapVersionsForPackage:(TCDPackage *)pkg;
- (void)grid:(TCDStoreGrid *)grid didChangeDensity:(TCDIconDensity)density;
@end

@interface TCDStoreGrid : NSView

@property (nonatomic, weak) id<TCDStoreGridDelegate> delegate;
@property (nonatomic, copy)   NSArray *packages;       // TCDPackage
@property (nonatomic, assign) TCDIconDensity density;

- (void)reload;

/* nil clears the message. Shown centred when the grid is empty. */
- (void)showEmptyStateWithMessage:(NSString *)message;

@end
