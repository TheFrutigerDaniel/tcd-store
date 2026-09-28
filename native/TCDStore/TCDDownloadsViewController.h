// TCDDownloadsViewController.h
#import <Foundation/Foundation.h>

@interface TCDDownloadsViewController : NSObject
@property (strong, readonly) NSView *view;
- (void)addDownloadItem:(id)item; // TCDAppItem*
@end
