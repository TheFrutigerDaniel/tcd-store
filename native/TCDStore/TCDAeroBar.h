//
//  TCDAeroBar.h
//  TCD Store
//
//  The one black bar. In the prototype this is a single element (`.aero-chrome`)
//  holding two transparent lines, and that is deliberate: there must be no seam
//  between the toolbar and the search row. Here it is one NSView that owns both
//  lines and paints the ramp itself.
//
//  Line one:  "TCD store" wordmark, glossy Store | Downloads pills.
//  Line two:  search field, then Back / Refresh / Update All.
//
//  10.7 notes:
//    · no NSStackView, so the subviews are positioned by frame and re-laid out
//      in -layoutBar rather than by constraints
//    · the pills are NSButtons that draw their own face, because the stock
//      bezel is square and the design is not
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

/* Which pill is lit. Setting this repaints both. */
@property (nonatomic, assign) TCDAeroView activeView;

/* Live count for the Downloads pill; 0 removes the badge. */
@property (nonatomic, assign) NSUInteger downloadCount;

/* The search well. It is a dark inset inside the black bar, not a white box —
   a light field would split the bar in two, which is the thing the bar is not. */
@property (nonatomic, strong, readonly) NSSearchField *searchField;

/* Update All only appears when there is work to do. */
@property (nonatomic, assign) BOOL updateAllVisible;

- (void)focusSearch;
- (void)clearSearch;

@end
