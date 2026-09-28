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

- (void)postChanged {
    [[NSNotificationCenter defaultCenter]
        postNotificationName:TCDCatalogueDidChangeNotification object:nil];
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

    NSArray *sources = [self sources];
    NSLog(@"TCD: prepareStore: %lu source(s)", (unsigned long)sources.count);
    for (NSDictionary *source in sources)
        [self ingestSource:source];

    NSLog(@"TCD: prepareStore: %lu package(s) in the database, %lu item(s) for the grid",
          (unsigned long)[[db allPackages] count],
          (unsigned long)[[self items] count]);
    return YES;
}

/* Every source, from the database. The Sources window reads this. */
- (NSArray *)sources {
    return [[self db] allSources];
}

- (NSUInteger)packageCountForSourceIdentifier:(NSString *)identifier {
    if (!identifier.length) return 0;
    NSUInteger n = 0;
    for (TCDPackage *pkg in [[self db] allPackages])
        if ([identifier isEqualToString:pkg.sourceIdentifier]) n++;
    return n;
}

#pragma mark - adding and removing

/* The identifier is the absolute URL. It is stable across launches and unique
   per source, which is what the (source, identifier) primary key needs. */
- (BOOL)addSourceWithName:(NSString *)name url:(NSString *)url {
    NSString *trimmedURL = [url stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSURL *parsed = trimmedURL.length ? [NSURL URLWithString:trimmedURL] : nil;
    // Either no scheme at all, or a scheme with neither a host nor a file
    // path: neither can be fetched.
    if (!parsed.scheme || (!parsed.host.length && !parsed.isFileURL)) {
        NSLog(@"TCD: addSource: '%@' is not a usable URL", url);
        return NO;
    }

    TCDPackageDatabase *db = [self db];
    if (!db) return NO;

    NSString *identifier = [parsed absoluteString];
    if ([db sourceWithIdentifier:identifier]) {
        NSLog(@"TCD: addSource: already have %@", identifier);
        return NO;
    }

    NSString *label = [name stringByTrimmingCharactersInSet:
                          [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [db addSource:[NSDictionary dictionaryWithObjectsAndKeys:
        identifier,                          @"identifier",
        label.length ? label : identifier,  @"name",
        identifier,                          @"url",
        [parsed isFileURL] ? @"local" : @"third-party", @"kind", nil]];

    [self refreshSourceWithIdentifier:identifier];
    [self postChanged];
    return YES;
}

/* Packages first, then the source row. Packages are keyed by identifier
   within a source, so deleting the row alone would leave packages that no
   longer belong to anything and would still show up in the grid. */
- (BOOL)removeSourceWithIdentifier:(NSString *)identifier {
    if (!identifier.length) return NO;
    TCDPackageDatabase *db = [self db];
    if (!db) return NO;
    if (![db sourceWithIdentifier:identifier]) return NO;

    [db beginTransaction];
    [db removePackagesForSourceIdentifier:identifier];
    [db removeSourceWithIdentifier:identifier];
    [db commit];

    [self postChanged];
    return YES;
}

#pragma mark - refreshing

- (void)refresh {
    for (NSDictionary *source in [self sources]) {
        NSString *urlString = [source objectForKey:@"url"];
        NSString *identifier = [source objectForKey:@"identifier"];
        if (!urlString.length || !identifier.length) continue;

        // A local index is a file read, so it is done inline: that is what
        // makes the demo grid populated on the first paint rather than a
        // moment later. A remote one is fetched off the main thread, because
        // blocking the launch on someone's server is not acceptable.
        NSURL *url = [NSURL URLWithString:urlString];
        if (url && [url isFileURL]) {
            [self ingestSource:source];
            continue;
        }
        TCDStoreFeed *feed = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *message = nil;
            NSData *data = [feed dataForURLString:urlString message:&message];
            // Back to the main thread: every database call happens there.
            dispatch_async(dispatch_get_main_queue(), ^{
                [feed finishSource:identifier data:data message:message];
            });
        });
    }
}

/* One source, start to finish, on the calling thread. This is what the Sources
   window's Refresh button drives: it is user-initiated, the window disables
   itself while it runs, and a remote index is small enough that the wait is
   shorter than the round trip. */
- (BOOL)refreshSourceWithIdentifier:(NSString *)identifier {
    if (!identifier.length) return NO;
    NSDictionary *source = [[self db] sourceWithIdentifier:identifier];
    NSString *urlString = [source objectForKey:@"url"];
    if (!urlString.length) return NO;

    NSString *message = nil;
    NSData *data = [self dataForURLString:urlString message:&message];
    [self finishSource:identifier data:data message:message];
    return data.length > 0;
}

/* nil plus a reason on failure, so the caller can record why. */
- (NSData *)dataForURLString:(NSString *)urlString message:(NSString **)message {
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        if (message) *message = @"not a usable URL";
        return nil;
    }
    if ([url isFileURL]) {
        NSData *data = [NSData dataWithContentsOfURL:url];
        if (!data && message) *message = @"index file not found";
        return data;
    }
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:
                        [NSURLRequest requestWithURL:url]
                                      returningResponse:&response
                                                  error:&error];
    if (!data) {
        if (message)
            *message = error.localizedDescription ?: @"could not reach the source";
        return nil;
    }
    // An index that arrives as a 404 page parses to nothing, which reads as
    // an empty source rather than a failure. Catch it here instead.
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSInteger code = [(NSHTTPURLResponse *)response statusCode];
        if (code < 200 || code > 299) {
            if (message) *message = [NSString stringWithFormat:@"server said %ld", (long)code];
            return nil;
        }
    }
    return data;
}

/* How a refresh went, however the bytes arrived: parse them in, remember the
   index, and record the outcome so the window can show it. */
- (void)finishSource:(NSString *)identifier
               data:(NSData *)data
            message:(NSString *)message {
    TCDPackageDatabase *db = [self db];
    if (!db) return;

    if (!data.length) {
        // Fall back to what was last fetched rather than emptying the grid: a
        // source going down should not look like the user uninstalling
        // everything.
        NSData *cached = [db indexDataForSource:identifier];
        if (cached.length) {
            NSLog(@"TCD: %@: refresh failed (%@), using the cached index",
                  identifier, message ?: @"unknown");
            [self ingestData:cached forSource:identifier];
        } else {
            NSLog(@"TCD: %@: refresh failed (%@), no cached index",
                  identifier, message ?: @"unknown");
        }
        [db markSourceWithIdentifier:identifier synced:NO
                            message:message ?: @"refresh failed"];
        [self postChanged];
        return;
    }

    if ([self ingestData:data forSource:identifier]) {
        // Kept so a later failure has something to fall back to.
        [db storeIndexData:data forSource:identifier];
        [db markSourceWithIdentifier:identifier synced:YES message:@""];
    } else {
        [db markSourceWithIdentifier:identifier synced:NO
                            message:@"the index held no usable packages"];
    }
    [self postChanged];
}

- (void)ingestSource:(NSDictionary *)source {
    NSString *urlString = [source objectForKey:@"url"];
    NSString *identifier = [source objectForKey:@"identifier"];
    if (!urlString.length || !identifier.length) return;
    NSString *message = nil;
    NSData *data = [self dataForURLString:urlString message:&message];
    [self finishSource:identifier data:data message:message];
}

/* One source, one transaction: the index is replaced or it is not. Returns NO
   when the index held nothing usable, which the caller records as a failure
   rather than a successful empty refresh. */
- (BOOL)ingestData:(NSData *)data forSource:(NSString *)sourceIdentifier {
    if (!data.length) return NO;
    TCDPackageDatabase *db = [self db];
    if (!db) return NO;

    NSArray *skipped = nil;
    NSArray *packages = [TCDIndexParser parseIndexData:data
                                     sourceIdentifier:sourceIdentifier
                                          skippedOut:&skipped];
    NSLog(@"TCD: %@: %lu byte(s) -> %lu package(s), %lu skipped",
          sourceIdentifier, (unsigned long)data.length,
          (unsigned long)packages.count, (unsigned long)skipped.count);
    if (!packages.count) return NO;

    [db beginTransaction];
    for (TCDPackage *pkg in packages) {
        // An index knows nothing about this machine, so it would otherwise
        // wipe the install state of everything already installed. Scoped by
        // source, because two sources may carry the same package id.
        TCDPackage *existing = [db packageWithIdentifier:pkg.identifier
                                       sourceIdentifier:sourceIdentifier];
        if (existing) {
            pkg.installed        = existing.installed;
            pkg.installedVersion = existing.installedVersion;
            pkg.autoInstalled    = existing.autoInstalled;
            pkg.receiptID        = existing.receiptID;
        }
        [db upsertPackage:pkg];
    }
    [db commit];
    return YES;
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
    return [self removeSourceWithIdentifier:[TCDDemoSource identifier]];
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
