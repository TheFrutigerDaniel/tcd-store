// TCDDownloadManager.h
#import <Foundation/Foundation.h>
@class TCDAppItem;

extern NSString * const TCDDownloadProgressNotification;
extern NSString * const TCDDownloadFinishedNotification;
extern NSString * const TCDDownloadFailedNotification;
extern NSString * const TCDDownloadCancelledNotification;

@interface TCDDownloadManager : NSObject
+ (instancetype)sharedManager;
- (void)startDownload:(TCDAppItem *)item;
- (void)cancelDownload:(TCDAppItem *)item;
// 0.0-1.0 aggregate across all active downloads; -1 if nothing active
- (CGFloat)totalProgress;
- (NSInteger)activeDownloadCount;
@end
