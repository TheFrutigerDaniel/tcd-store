// TCDDownloadRowView.h
#import <Cocoa/Cocoa.h>
@class TCDAppItem;

@interface TCDDownloadRowView : NSView
- (instancetype)initWithItem:(TCDAppItem *)item;
- (void)updateProgress;
@end
