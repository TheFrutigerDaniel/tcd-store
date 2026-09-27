//
//  TCDAeroBar.h
//  TCD Store
//
//  The one black bar. In the prototype this is a single element (`.aero-chrome`)
//  holding two transparent lines, and that is deliberate: there must be no seam
//  between the toolbar and the search row. Here it is one NSView that owns both
//  lines and paints the ramp itself.
//
//  Line one:  "TCD store" wordmark, Store | Downloads.
//  Line two:  search field, then Back / Refresh / Update All.
//
//  Every control is a stock one. The first version drew its own pills, round
//  buttons and search well, and it looked wrong: a hand-drawn bezel never
//  matches the real one, which has correct hairlines and a pressed state that
//  was drawn once by someone who knew the pixel grid. On an OS that still has
//  its own version of this, use it. Only the background is painted here, since
//  a black bar with a vertical ramp is a surface and has no stock equivalent.
//
//  10.7 notes:
//    · no NSStackView, so the subviews are positioned by frame and re-laid out
//      in -layoutBar rather than by constraints
//    · NSSegmentedControl carries Store | Downloads
//

#import <Cocoa/Cocoa.h>

@class TCDAeroBar;

typedef NS_ENUM(NSInteger, TCDAeroView) {
    TCDAeroViewStore = 0,
    TCDAeroViewDownloads
};

@protocol TCDAeroBarDelegate <NSObject>
- (void)aeroBar:(TCDAeroBar *)bar didSelectView:(TCDAeroView)view;
- (void)aeroBar:(TCDAeroBar *)bar didChangeSearch:(NSString *)query;
- (void)aeroBarDidGoBack:(TCDAeroBar *)bar;
- (void)aeroBarDidRefresh:(TCDAeroBar *)bar;
- (void)aeroBarDidUpdateAll:(TCDAeroBar *)bar;
@end

@interface TCDAeroBar : NSView

@property (nonatomic, weak) id<TCDAeroBarDelegate> delegate;

/* Which view is showing. Setting this moves the segmented control. */
@property (nonatomic, assign) TCDAeroView activeView;

/* Live transfer count; shown inside the Downloads segment label, 0 for none. */
@property (nonatomic, assign) NSUInteger downloadCount;

/* Stock NSSearchField, bezel and all. */
@property (nonatomic, strong, readonly) NSSearchField *searchField;

/* Update All only appears when there is work to do. */
@property (nonatomic, assign) BOOL updateAllVisible;

- (void)focusSearch;
- (void)clearSearch;

@end
