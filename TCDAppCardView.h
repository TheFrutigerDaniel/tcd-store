// TCDAppCardView.h
#import <Cocoa/Cocoa.h>
@class TCDAppItem;

@protocol TCDAppCardViewDelegate <NSObject>
- (void)cardViewDidRequestDownload:(TCDAppItem *)item version:(NSString *)version;
@end

@interface TCDAppCardView : NSView
@property (strong) TCDAppItem *item;
@property (assign) id<TCDAppCardViewDelegate> delegate;  // assign, not weak — cards are subviews of a canvas owned by the store VC
- (instancetype)initWithItem:(TCDAppItem *)item;
- (void)refreshState; // call after downloadState changes
@end
