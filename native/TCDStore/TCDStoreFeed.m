//
//  TCDStoreFeed.m
//  TCD Store
//

#import "TCDStoreFeed.h"
#import "TCDPackage.h"
#import "TCDPackageDatabase.h"
#import "TCDIndexParser.h"
#import "TCDDemoSource.h"
#import "TCDAppItem.h"
#import "TCDCatalogue.h"
// For TCDCatalogueDidChangeNotification, which the store view already observes
// to reload itself.
#import "TCDCatalogueManager.h"

@interface TCDStoreFeed ()
@property (nonatomic, strong) TCDPackageDatabase *db;
@end

@implementation TCDStoreFeed

+ (TCDStoreFeed *)sharedFeed {
    static TCDStoreFeed *feed = nil;
    if (!feed) feed = [[TCDStoreFeed alloc] init];
    return feed;
}

- (TCDPackageDatabase *)db {
    if (!_db) {
        _db = [TCDPackageDatabase sharedDatabase];
        [_db openWithError:NULL];
    }
    return _db;
}

#pragma mark - preparing

- (BOOL)prepareStore {
    TCDPackageDatabase *db = [self db];
    if (!db) {
        NSLog(@"TCD: prepareStore: the package database could not be opened");
        return NO;
    }

    // A store with no sources would show an empty grid, which says nothing
    // about whether the store works. So the bundled demo index joins a store
    // that has nothing, and stays away from one that has been set up.
    if (![TCDDemoSource isAvailable])
        NSLog(@"TCD: prepareStore: demo-index.txt is not in the bundle");
    if (![TCDDemoSource registerIfNoSourcesExist])
        NSLog(@"TCD: prepareStore: demo source not registered");

    NSArray *sources = [db allSources];
    NSLog(@"TCD: prepareStore: %lu source(s)", (unsigned long)sources.count);
    for (NSDictionary *source in sources)
        [self ingestSource:source];

    NSLog(@"TCD: prepareStore: %lu package(s) in the database, %lu item(s) for the grid",
          (unsigned long)[[db allPackages] count],
          (unsigned long)[[self items] count]);
    return YES;
}

- (void)refresh {
    TCDPackageDatabase *db = [self db];
    if (!db) return;
    for (NSDictionary *source in [db allSources])
        [self ingestSource:source];
}

/* Fetch, then parse on the main thread. Only the fetch leaves it. */
- (void)ingestSource:(NSDictionary *)source {
    NSString *urlString = [source objectForKey:@"url"];
    NSString *identifier = [source objectForKey:@"identifier"];
    if (!urlString.length || !identifier.length) return;

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return;

    if ([url isFileURL]) {
        // Local: a read and a parse. No reason to defer it, and doing it now
        // is what makes the demo grid populated on the very first paint.
        [self ingestData:[NSData dataWithContentsOfURL:url] forSource:identifier];
        return;
    }

    TCDStoreFeed *feed = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURLResponse *response = nil;
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:
                            [NSURLRequest requestWithURL:url]
                                              returningResponse:&response
                                                          error:&error];
        if (!data) return;
        // Back to the main thread: every database call happens there.
        dispatch_async(dispatch_get_main_queue(), ^{
            [feed ingestData:data forSource:identifier];
        });
    });
}

/* One source, one transaction: the index is replaced or it is not. */
- (void)ingestData:(NSData *)data forSource:(NSString *)sourceIdentifier {
    if (!data.length) {
        NSLog(@"TCD: %@: index came back empty", sourceIdentifier);
        return;
    }
    TCDPackageDatabase *db = [self db];
    if (!db) return;

    NSArray *skipped = nil;
    NSArray *packages = [TCDIndexParser parseIndexData:data
                                     sourceIdentifier:sourceIdentifier
                                          skippedOut:&skipped];
    NSLog(@"TCD: %@: %lu byte(s) -> %lu package(s), %lu skipped",
          sourceIdentifier, (unsigned long)data.length,
          (unsigned long)packages.count, (unsigned long)skipped.count);
    if (!packages.count) return;

    [db beginTransaction];
    for (TCDPackage *pkg in packages) {
        // An index knows nothing about what is on this machine, so it would
        // otherwise wipe the install state of everything already here.
        TCDPackage *existing = [db packageWithIdentifier:pkg.identifier];
        if (existing) {
            pkg.installed        = existing.installed;
            pkg.installedVersion = existing.installedVersion;
            pkg.autoInstalled    = existing.autoInstalled;
            pkg.receiptID        = existing.receiptID;
        }
        [db upsertPackage:pkg];
    }
    [db commit];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:TCDCatalogueDidChangeNotification object:nil];
}

#pragma mark - presenting

- (NSArray *)items {
    NSMutableArray *out = [NSMutableArray array];
    for (TCDPackage *pkg in [[self db] allPackages]) {
        TCDAppItem *item = [self itemForPackage:pkg];
        if (item) [out addObject:item];
    }
    return out;
}

- (NSArray *)categories {
    NSMutableArray *found = [NSMutableArray array];
    for (TCDPackage *pkg in [[self db] allPackages]) {
        NSString *section = [self sectionForPackage:pkg];
        if (section && ![found containsObject:section]) [found addObject:section];
    }
    [found sortUsingSelector:@selector(caseInsensitiveCompare:)];
    return [@[@"All"] arrayByAddingObjectsFromArray:found];
}

- (TCDPackage *)packageForItem:(TCDAppItem *)item {
    return item.storePackage;
}

- (BOOL)removeDemoSource {
    return [TCDDemoSource remove];
}

#pragma mark - mapping

- (TCDAppItem *)itemForPackage:(TCDPackage *)pkg {
    if (!pkg.name.length) return nil;

    TCDAppItem *item = [TCDAppItem
        itemWithName:pkg.name
           developer:(pkg.developer.length ? pkg.developer : @"Unknown")
            category:[self sectionForPackage:pkg]
         accentColor:[self accentForPackage:pkg]
            versions:[self versionStringsForPackage:pkg]
         downloadURL:[self downloadURLForPackage:pkg atVersion:pkg.version]];

    item.storePackage  = pkg;
    item.iconName      = [self iconNameForPackage:pkg];
    item.downloadState = pkg.installed ? TCDDownloadStateDone : TCDDownloadStateIdle;
    return item;
}

- (NSString *)sectionForPackage:(TCDPackage *)pkg {
    NSString *s = [pkg.section stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return s.length ? s : @"Other";
}

/* The popup on a card wants plain version strings, newest first, and falls
   back to the package's own version when the index carried no version list. */
- (NSArray *)versionStringsForPackage:(TCDPackage *)pkg {
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *entry in pkg.availableVersions) {
        NSString *v = [entry objectForKey:@"version"];
        if (v.length && ![out containsObject:v]) [out addObject:v];
    }
    if (!out.count && pkg.version.length) [out addObject:pkg.version];
    return out;
}

/* A specific version's payload, not just the newest one -- this is what makes
   a downgrade possible from the same card. */
- (NSString *)downloadURLForPackage:(TCDPackage *)pkg atVersion:(NSString *)version {
    NSDictionary *entry = version.length ? [pkg versionEntry:version] : nil;
    NSString *url = [entry objectForKey:@"downloadURLString"];
    return url.length ? url : pkg.downloadURLString;
}

- (NSString *)iconNameForPackage:(TCDPackage *)pkg {
    NSString *icon = pkg.iconURLString;
    if (!icon.length) return @"";
    // +[TCDCatalogueManager iconNamed:] resolves a bare filename, so hand it
    // one rather than a path.
    return [icon lastPathComponent];
}

/* A stable colour per package, so a grid of cards is not uniformly grey. */
- (NSColor *)accentForPackage:(TCDPackage *)pkg {
    NSUInteger hash = [pkg.identifier hash];
    CGFloat hue = (CGFloat)(hash % 360) / 360.0;
    return [NSColor colorWithCalibratedHue:hue saturation:0.32 brightness:0.86
                                    alpha:1.0];
}

@end
