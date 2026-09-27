//
//  TCDDemoSource.m
//  TCD Store
//

#import "TCDDemoSource.h"
#import "TCDPackageDatabase.h"

static NSString *const kTCDDemoSourceIdentifier = @"dev.tcdstore.demo";
static NSString *const kTCDDemoSourceName      = @"Demo (bundled)";
static NSString *const kTCDDemoIndexResource   = @"demo-index";

@implementation TCDDemoSource

+ (NSString *)identifier  { return kTCDDemoSourceIdentifier; }
+ (NSString *)displayName { return kTCDDemoSourceName; }

+ (NSURL *)indexURL {
    NSString *path = [[NSBundle mainBundle] pathForResource:kTCDDemoIndexResource
                                                     ofType:@"txt"];
    return path ? [NSURL fileURLWithPath:path] : nil;
}

+ (BOOL)isAvailable { return [self indexURL] != nil; }

+ (BOOL)register {
    NSURL *url = [self indexURL];
    if (!url) return NO;
    TCDPackageDatabase *db = [TCDPackageDatabase sharedDatabase];
    if (![db openWithError:NULL]) return NO;
    [db addSource:[NSDictionary dictionaryWithObjectsAndKeys:
        kTCDDemoSourceIdentifier, @"identifier",
        kTCDDemoSourceName,      @"name",
        [url absoluteString],    @"url",
        @"local",                @"kind", nil]];
    return YES;
}

+ (BOOL)registerIfNoSourcesExist {
    TCDPackageDatabase *db = [TCDPackageDatabase sharedDatabase];
    if (![db openWithError:NULL]) return NO;
    // If the user has added anything of their own, stay out of the way. The
    // demo is a starting point, not something to append to a real setup.
    if ([db allSources].count) return NO;
    return [self register];
}

+ (BOOL)remove {
    TCDPackageDatabase *db = [TCDPackageDatabase sharedDatabase];
    if (![db openWithError:NULL]) return NO;
    if (![db sourceWithIdentifier:kTCDDemoSourceIdentifier]) return NO;

    [db beginTransaction];
    // Drop the packages first: they are keyed by identifier alone, so deleting
    // the source row alone would leave orphaned packages that no longer belong
    // to anything and would still show up in the grid.
    [db removePackagesForSourceIdentifier:kTCDDemoSourceIdentifier];
    [db removeSourceWithIdentifier:kTCDDemoSourceIdentifier];
    [db commit];
    return YES;
}

@end
