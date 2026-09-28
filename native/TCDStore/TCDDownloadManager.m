// TCDDownloadManager.m
#import "TCDDownloadManager.h"
#import "TCDAppItem.h"
#import "TCDSettingsWindowController.h"

NSString * const TCDDownloadProgressNotification  = @"TCDDownloadProgressNotification";
NSString * const TCDDownloadFinishedNotification   = @"TCDDownloadFinishedNotification";
NSString * const TCDDownloadFailedNotification     = @"TCDDownloadFailedNotification";
NSString * const TCDDownloadCancelledNotification  = @"TCDDownloadCancelledNotification";

// Forward-declare so TCDDownloadContext can call back into the manager
@interface TCDDownloadManager ()
@property (strong) NSMutableArray *activeContexts;
- (void)removeContext:(id)ctx;
@end

// ── Per-download context ──────────────────────────────────────────────────────

@interface TCDDownloadContext : NSObject <NSURLDownloadDelegate>
@property (strong) TCDAppItem    *item;
@property (strong) NSURLDownload *download;
@property (assign) long long      expectedLength;
@property (copy)   NSString      *destinationPath;
@end

@implementation TCDDownloadContext

- (void)download:(NSURLDownload *)dl didReceiveResponse:(NSURLResponse *)response
{
    _expectedLength = [response expectedContentLength];
}

- (void)download:(NSURLDownload *)dl didReceiveDataOfLength:(NSUInteger)length
{
    if (_expectedLength > 0) {
        _item.downloadProgress = MIN(_item.downloadProgress
                                     + (CGFloat)length / (CGFloat)_expectedLength,
                                     0.99);
        [[NSNotificationCenter defaultCenter]
            postNotificationName:TCDDownloadProgressNotification object:_item];
    }
}

- (void)download:(NSURLDownload *)dl
        decideDestinationWithSuggestedFilename:(NSString *)filename
{
    NSString *dir = [TCDSettingsWindowController sharedController].downloadDirectory;
    [[NSFileManager defaultManager]
        createDirectoryAtPath:dir withIntermediateDirectories:YES
                   attributes:nil error:nil];
    _destinationPath = [dir stringByAppendingPathComponent:filename];
    [dl setDestination:_destinationPath allowOverwrite:YES];
}

- (void)downloadDidFinish:(NSURLDownload *)dl
{
    _item.downloadProgress = 1.0;
    _item.downloadState    = TCDDownloadStateDone;
    _item.savedPath        = _destinationPath;
    [self deliverSystemNotification];
    [[NSNotificationCenter defaultCenter]
        postNotificationName:TCDDownloadFinishedNotification object:_item];
    [[TCDDownloadManager sharedManager] removeContext:self];
}

- (void)download:(NSURLDownload *)dl didFailWithError:(NSError *)error
{
    NSLog(@"[TCD Store] Download failed for %@: %@",
          _item.name, error.localizedDescription);
    _item.downloadState    = TCDDownloadStateFailed;
    _item.downloadProgress = 0.0;
    [[NSNotificationCenter defaultCenter]
        postNotificationName:TCDDownloadFailedNotification object:_item];
    [[TCDDownloadManager sharedManager] removeContext:self];
}

- (BOOL)download:(NSURLDownload *)dl
        canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space
{
    return [space.authenticationMethod
            isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)download:(NSURLDownload *)dl
        didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    [[challenge sender]
        useCredential:[NSURLCredential
                       credentialForTrust:challenge.protectionSpace.serverTrust]
        forAuthenticationChallenge:challenge];
}

- (void)deliverSystemNotification
{
    Class NUNClass  = NSClassFromString(@"NSUserNotification");
    Class NUNCClass = NSClassFromString(@"NSUserNotificationCenter");
    if (!NUNClass || !NUNCClass) return;
    NSString *dir = [TCDSettingsWindowController sharedController].downloadDirectory;
    id note = [[NUNClass alloc] init];
    [note setValue:[NSString stringWithFormat:@"\"%@\" downloaded", _item.name]
            forKey:@"title"];
    [note setValue:[NSString stringWithFormat:@"Saved to %@", dir]
            forKey:@"informativeText"];
    id center = [NUNCClass performSelector:@selector(defaultUserNotificationCenter)];
    [center performSelector:@selector(deliverNotification:) withObject:note];
}

@end

// ── TCDDownloadManager ────────────────────────────────────────────────────────

@implementation TCDDownloadManager

+ (instancetype)sharedManager
{
    static TCDDownloadManager *s = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{ s = [[self alloc] init]; });
    return s;
}

- (instancetype)init
{
    self = [super init];
    if (!self) return nil;
    _activeContexts = [NSMutableArray array];
    return self;
}

// ── Public API ────────────────────────────────────────────────────────────────

- (void)startDownload:(TCDAppItem *)item
{
    if (item.downloadState == TCDDownloadStateDownloading) return;

    item.downloadState    = TCDDownloadStateDownloading;
    item.downloadProgress = 0.0;
    item.savedPath        = nil;

    [[NSNotificationCenter defaultCenter]
        postNotificationName:TCDDownloadProgressNotification object:item];

    if (item.downloadURL.length > 0) {
        // ── Real NSURLDownload ─────────────────────────────────────────────
        NSURL *url        = [NSURL URLWithString:item.downloadURL];
        NSURLRequest *req = [NSURLRequest
                             requestWithURL:url
                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                            timeoutInterval:60.0];
        TCDDownloadContext *ctx = [[TCDDownloadContext alloc] init];
        ctx.item     = item;
        ctx.download = [[NSURLDownload alloc] initWithRequest:req delegate:ctx];
        [_activeContexts addObject:ctx];
    } else {
        // ── 5-second dummy simulation ──────────────────────────────────────
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSInteger ticks = 50;
            for (NSInteger t = 1; t <= ticks; t++) {
                // Stop early if cancelled
                if (item.downloadState != TCDDownloadStateDownloading) return;
                [NSThread sleepForTimeInterval:0.1];
                CGFloat p = t / (CGFloat)ticks;
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (item.downloadState != TCDDownloadStateDownloading) return;
                    item.downloadProgress = p;
                    [[NSNotificationCenter defaultCenter]
                        postNotificationName:TCDDownloadProgressNotification object:item];
                });
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (item.downloadState != TCDDownloadStateDownloading) return;
                NSString *dir  = [TCDSettingsWindowController sharedController]
                                    .downloadDirectory;
                [[NSFileManager defaultManager]
                    createDirectoryAtPath:dir withIntermediateDirectories:YES
                               attributes:nil error:nil];
                NSString *filename = [NSString stringWithFormat:@"%@-%@.tcdpkg",
                                      item.name, item.selectedVersion ?: @"v1.0"];
                NSString *filePath = [dir stringByAppendingPathComponent:filename];
                [[NSString stringWithFormat:
                  @"TCD Store package\nApp: %@\nVersion: %@\nDeveloper: %@\n",
                  item.name, item.selectedVersion, item.developer]
                 writeToFile:filePath atomically:YES
                    encoding:NSUTF8StringEncoding error:nil];
                item.downloadState    = TCDDownloadStateDone;
                item.downloadProgress = 1.0;
                item.savedPath        = filePath;
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:TCDDownloadFinishedNotification object:item];
            });
        });
    }
}

- (void)cancelDownload:(TCDAppItem *)item
{
    if (item.downloadState != TCDDownloadStateDownloading) return;

    // Find and cancel the NSURLDownload context if one exists
    TCDDownloadContext *found = nil;
    for (TCDDownloadContext *ctx in _activeContexts) {
        if (ctx.item == item) { found = ctx; break; }
    }
    if (found) {
        [found.download cancel];
        // Clean up partial file
        if (found.destinationPath) {
            [[NSFileManager defaultManager]
                removeItemAtPath:found.destinationPath error:nil];
        }
        [_activeContexts removeObject:found];
    }

    // Reset item state (also stops the dummy simulation loop)
    item.downloadState    = TCDDownloadStateIdle;
    item.downloadProgress = 0.0;
    item.savedPath        = nil;

    [[NSNotificationCenter defaultCenter]
        postNotificationName:TCDDownloadCancelledNotification object:item];
}

- (CGFloat)totalProgress
{
    // Average progress across all items currently downloading
    if (_activeContexts.count == 0) return -1.0;
    CGFloat sum = 0;
    for (TCDDownloadContext *ctx in _activeContexts) {
        sum += ctx.item.downloadProgress;
    }
    return sum / (CGFloat)_activeContexts.count;
}

- (NSInteger)activeDownloadCount
{
    return (NSInteger)_activeContexts.count;
}

- (void)removeContext:(id)ctx
{
    [_activeContexts removeObject:ctx];
}

@end
