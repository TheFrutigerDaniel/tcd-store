// TCDAppItem.h
#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, TCDDownloadState) {
    TCDDownloadStateIdle,
    TCDDownloadStateDownloading,
    TCDDownloadStateDone,
    TCDDownloadStateFailed
};

@interface TCDAppItem : NSObject

@property (copy)   NSString         *name;
@property (copy)   NSString         *developer;
@property (copy)   NSString         *category;
@property (strong) NSColor          *accentColor;
@property (strong) NSArray          *versions;
@property (copy)   NSString         *selectedVersion;
@property (copy)   NSString         *downloadURL;
@property (copy)   NSString         *iconName;      // filename, e.g. "momiji.png"

@property (assign) TCDDownloadState  downloadState;
@property (assign) CGFloat           downloadProgress;
@property (copy)   NSString         *savedPath;

+ (instancetype)itemWithName:(NSString *)name
                   developer:(NSString *)developer
                    category:(NSString *)category
                 accentColor:(NSColor *)color
                    versions:(NSArray *)versions
                 downloadURL:(NSString *)url;
@end
