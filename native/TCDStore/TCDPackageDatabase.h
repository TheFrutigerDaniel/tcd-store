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
- (TCDPackage *)packageWithIdentifier:(NSString *)identifier;
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
- (void)storeIndexData:(NSData *)data forSource:(NSString *)identifier;
- (NSData *)indexDataForSource:(NSString *)identifier;

@end
