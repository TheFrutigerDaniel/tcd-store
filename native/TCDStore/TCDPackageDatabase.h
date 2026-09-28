//
//  TCDPackageDatabase.h
//  TCD Store
//
//  SQLite is the right tool here and is already present on 10.7
//  (libsqlite3.dylib ships with the OS, no system package needed).
//
//  Two tables, deliberately separate:
//
//    packages  — the merged view of every source index plus our own local
//                annotations (installed, version, autoInstalled, receipt).
//    sources   — which indexes we have, when we last fetched them, and the
//                raw bytes so a failed refresh can still show a cached list.
//
//  A source refresh is a transaction: the whole index is replaced or none of
//  it is, so a connection dropped half way through a 4 MB index cannot leave
//  the user with a package list that is missing its second half.
//

#import <Foundation/Foundation.h>
#import "TCDPackage.h"

@interface TCDPackageDatabase : NSObject

+ (TCDPackageDatabase *)sharedDatabase;

- (NSString *)databasePath;
- (BOOL)openWithError:(NSError **)error;
- (void)close;

- (void)beginTransaction;
- (void)commit;
- (void)rollback;

#pragma mark - packages

- (void)upsertPackage:(TCDPackage *)pkg;
/* Source-scoped, because the primary key is (source, identifier) and two
   sources may carry the same package id. */
- (TCDPackage *)packageWithIdentifier:(NSString *)identifier
                    sourceIdentifier:(NSString *)sourceIdentifier;
- (NSArray *)allPackages;
- (NSArray *)packagesInSection:(NSString *)section;
- (NSArray *)installedPackages;
- (NSArray *)packagesWithUpdates;
- (NSArray *)packagesMatchingQuery:(NSString *)query;
- (void)setPackage:(TCDPackage *)pkg installed:(BOOL)installed;

#pragma mark - sources

- (NSArray *)allSources;
- (NSDictionary *)sourceWithIdentifier:(NSString *)identifier;
- (void)addSource:(NSDictionary *)source;      // {identifier,name,url,kind}
- (void)removeSourceWithIdentifier:(NSString *)identifier;

/* Removes every package that came from `sourceIdentifier` and reports how
   many went. Packages are keyed by identifier alone, so removing a source has
   to take its packages with it or they survive as orphans in the grid. */
- (NSUInteger)removePackagesForSourceIdentifier:(NSString *)sourceIdentifier;
- (void)storeIndexData:(NSData *)data forSource:(NSString *)identifier;

/* Outcome of a refresh. synced:NO records the failure so the Sources window
   can say why a source is stale instead of leaving it silently blank. */
- (void)markSourceWithIdentifier:(NSString *)identifier
                          synced:(BOOL)ok
                         message:(NSString *)message;
- (NSData *)indexDataForSource:(NSString *)identifier;

@end
