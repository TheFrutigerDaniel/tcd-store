// TCDAppItem.h
#import <Cocoa/Cocoa.h>

@class TCDPackage;

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

// The TCDPackage this card was built from, when it came from the real store
// rather than from a hand-authored catalogue. The grid only needs the strings
// above to draw and to download; install, update and downgrade all need the
// package itself, so the feed hangs it here rather than making the grid carry a
// parallel model. nil for items that did not come from a source.
@property (strong) TCDPackage        *storePackage;

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
