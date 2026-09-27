//
//  TCDPackageDatabase.m
//  TCD Store
//

#import "TCDPackageDatabase.h"
#import <Cocoa/Cocoa.h>   // NSApplicationSupportDirectory, without betting on
                           // Foundation pulling NSSearchPath.h in for us
#import <sqlite3.h>

/* availableVersions is a small list of flat dictionaries, so it round-trips
   through JSON rather than a join table. The list is bounded by what a source
   actually publishes — a handful of entries at most. */
static NSString *TCDJSONString(NSArray *a) {
    if (!a.count) return nil;
    NSData *d = [NSJSONSerialization dataWithJSONObject:a options:0 error:NULL];
    return d ? [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] : nil;
}
static NSArray *TCDJSONArray(NSString *s) {
    if (!s.length) return [NSArray array];
    NSData *d = [s dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *a = [NSJSONSerialization JSONObjectWithData:d options:0 error:NULL];
    return [a isKindOfClass:[NSArray class]] ? a : [NSArray array];
}

static NSString *const kSchemaVersion = @"1";

@interface TCDPackageDatabase () {
    sqlite3 *_db;
}
@end

@implementation TCDPackageDatabase

+ (TCDPackageDatabase *)sharedDatabase {
    static TCDPackageDatabase *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[TCDPackageDatabase alloc] init]; });
    return shared;
}

- (void)dealloc { [self close]; }

- (NSString *)databasePath {
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                         NSUserDomainMask, YES);
    NSString *root = dirs.count ? dirs[0] : [NSHomeDirectory() stringByAppendingPathComponent:
                                             @"Library/Application Support"];
    return [root stringByAppendingPathComponent:@"TCDStore/package.db"];
}

#pragma mark - lifecycle

- (BOOL)openWithError:(NSError **)error {
    if (_db) return YES;
    NSString *path = [self databasePath];
    [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent]
                              withIntermediateDirectories:YES attributes:nil error:NULL];

    int rc = sqlite3_open_v2([path fileSystemRepresentation], &_db,
                             SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, NULL);
    if (rc != SQLITE_OK) {
        if (error) *error = [NSError errorWithDomain:@"TCDStore" code:rc userInfo:
            [NSDictionary dictionaryWithObject:@"could not open the package database"
                                         forKey:NSLocalizedDescriptionKey]];
        if (_db) { sqlite3_close(_db); _db = NULL; }
        return NO;
    }
    [self exec:@"PRAGMA journal_mode=WAL"];
    [self exec:@"PRAGMA foreign_keys=ON"];
    return [self migrateWithError:error];
}

- (void)close {
    if (_db) { sqlite3_close(_db); _db = NULL; }
}

- (BOOL)exec:(NSString *)sql {
    char *err = NULL;
    int rc = sqlite3_exec(_db, [sql UTF8String], NULL, NULL, &err);
    if (err) { sqlite3_free(err); }
    return rc == SQLITE_OK;
}

- (BOOL)columnExists:(NSString *)column inTable:(NSString *)table {
    NSString *sql = [NSString stringWithFormat:@"PRAGMA table_info(%@)", table];
    sqlite3_stmt *st = NULL;
    if (sqlite3_prepare_v2(_db, [sql UTF8String], -1, &st, NULL) != SQLITE_OK) return NO;
    BOOL found = NO;
    while (sqlite3_step(st) == SQLITE_ROW) {
        if ([[self textAtColumn:st column:1] isEqualToString:column]) { found = YES; break; }
    }
    sqlite3_finalize(st);
    return found;
}

- (BOOL)migrateWithError:(NSError **)error {
    NSString *version = [[NSUserDefaults standardUserDefaults] stringForKey:@"TCDSchemaVersion"];
    if ([version isEqualToString:kSchemaVersion]) return YES;

    BOOL ok =
    [self exec:
        @"CREATE TABLE IF NOT EXISTS packages ("
        @"  identifier      TEXT NOT NULL,"
        @"  source          TEXT NOT NULL,"
        @"  name            TEXT NOT NULL,"
        @"  version         TEXT NOT NULL,"
        @"  summary         TEXT,"
        @"  description     TEXT,"
        @"  developer       TEXT,"
        @"  section         TEXT,"
        @"  changelog       TEXT,"
        @"  icon_url        TEXT,"
        @"  download_url    TEXT,"
        @"  sha256          TEXT,"
        @"  install_prefix  TEXT,"
        @"  type            INTEGER DEFAULT 0,"
        @"  arch            INTEGER DEFAULT 0,"
        @"  size_bytes      INTEGER DEFAULT 0,"
        @"  rating_count    INTEGER DEFAULT 0,"
        @"  rating_average  REAL DEFAULT 0,"
        @"  min_os          TEXT,"
        @"  depends         TEXT,"
        @"  conflicts       TEXT,"
        @"  installed       INTEGER DEFAULT 0,"
        @"  installed_version TEXT,"
        @"  auto_installed  INTEGER DEFAULT 0,"
        @"  receipt_id      TEXT,"
        @"  available_versions TEXT,"
        @"  PRIMARY KEY (source, identifier)"
        @");"] &&
    [self exec:
        @"CREATE TABLE IF NOT EXISTS sources ("
        @"  identifier  TEXT PRIMARY KEY,"
        @"  name        TEXT,"
        @"  url         TEXT,"
        @"  kind        TEXT,"
        @"  added       REAL,"
        @"  last_sync   REAL,"
        @"  last_status INTEGER DEFAULT 0,"
        @"  index_blob  BLOB"
        @");"] &&
    [self exec:@"CREATE INDEX IF NOT EXISTS idx_packages_section ON packages(section)"] &&
    [self exec:@"CREATE INDEX IF NOT EXISTS idx_packages_installed ON packages(installed)"] &&
    [self exec:@"CREATE INDEX IF NOT EXISTS idx_packages_name ON packages(name)"];

    if (!ok) {
        if (error) *error = [NSError errorWithDomain:@"TCDStore" code:1 userInfo:
            [NSDictionary dictionaryWithObject:@"schema migration failed"
                                         forKey:NSLocalizedDescriptionKey]];
        return NO;
    }

    // CREATE TABLE IF NOT EXISTS will not add a column to a database that
    // already exists, so each new column is added separately. SQLite has no
    // "ADD COLUMN IF NOT EXISTS", hence the lookup.
    if (![self columnExists:@"available_versions" inTable:@"packages"]) {
        if (![self exec:@"ALTER TABLE packages ADD COLUMN available_versions TEXT"]) {
            if (error) *error = [NSError errorWithDomain:@"TCDStore" code:1 userInfo:
                [NSDictionary dictionaryWithObject:@"could not add available_versions"
                                             forKey:NSLocalizedDescriptionKey]];
            return NO;
        }
    }
    [[NSUserDefaults standardUserDefaults] setObject:kSchemaVersion forKey:@"TCDSchemaVersion"];
    return YES;
}

#pragma mark - transactions

- (void)beginTransaction { [self exec:@"BEGIN IMMEDIATE TRANSACTION"]; }
- (void)commit         { [self exec:@"COMMIT"]; }
- (void)rollback       { [self exec:@"ROLLBACK"]; }

#pragma mark - helpers

/* The first argument only names the column so the call sites read as a table;
   the statement is already prepared and nothing here touches it. It is an
   NSString because that is what every call site passes, and ARC will not
   convert NSString to const char * for you. */
- (void)bindText:(NSString *)label stmt:(sqlite3_stmt *)st index:(int)i value:(NSString *)v {
    (void)label;
    if (v) sqlite3_bind_text(st, i, [v UTF8String], -1, SQLITE_TRANSIENT);
    else    sqlite3_bind_null(st, i);
}

- (NSString *)textAtColumn:(sqlite3_stmt *)st column:(int)c {
    const unsigned char *t = sqlite3_column_text(st, c);
    return t ? [NSString stringWithUTF8String:(const char *)t] : nil;
}

- (NSArray *)splitList:(NSString *)s {
    if (!s.length) return [NSArray array];
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *p in [s componentsSeparatedByString:@","]) {
        NSString *t = [p stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceCharacterSet]];
        if (t.length) [out addObject:t];
    }
    return out;
}

- (NSString *)joinList:(NSArray *)a {
    return a.count ? [a componentsJoinedByString:@","] : @"";
}

#pragma mark - packages

- (void)upsertPackage:(TCDPackage *)p {
    if (!p.identifier.length || !_db) return;
    static const char *sql =
        "INSERT OR REPLACE INTO packages ("
        " identifier,source,name,version,summary,description,developer,section,changelog,"
        " icon_url,download_url,sha256,install_prefix,type,arch,size_bytes,rating_count,"
        " rating_average,min_os,depends,conflicts,installed,installed_version,auto_installed,receipt_id)"
        " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)";
    sqlite3_stmt *st = NULL;
    if (sqlite3_prepare_v2(_db, sql, -1, &st, NULL) != SQLITE_OK) return;

    int i = 1;
    [self bindText:@"identifier" stmt:st index:i++ value:p.identifier];
    [self bindText:@"source"     stmt:st index:i++ value:p.sourceIdentifier];
    [self bindText:@"name"       stmt:st index:i++ value:p.name];
    [self bindText:@"version"    stmt:st index:i++ value:p.version];
    [self bindText:@"summary"    stmt:st index:i++ value:p.packageSummary];
    [self bindText:@"description" stmt:st index:i++ value:p.packageDescription];
    [self bindText:@"developer"  stmt:st index:i++ value:p.developer];
    [self bindText:@"section"    stmt:st index:i++ value:p.section];
    [self bindText:@"changelog"  stmt:st index:i++ value:p.changelog];
    [self bindText:@"icon_url"   stmt:st index:i++ value:p.iconURLString];
    [self bindText:@"download_url" stmt:st index:i++ value:p.downloadURLString];
    [self bindText:@"sha256"     stmt:st index:i++ value:p.sha256];
    [self bindText:@"install_prefix" stmt:st index:i++ value:p.installPrefix];
    sqlite3_bind_int(st, i++, (int)p.type);
    sqlite3_bind_int(st, i++, (int)p.arch);
    sqlite3_bind_int64(st, i++, (sqlite3_int64)p.sizeBytes);
    sqlite3_bind_int(st, i++, (int)p.ratingCount);
    sqlite3_bind_double(st, i++, p.ratingAverage);
    [self bindText:@"min_os"     stmt:st index:i++ value:p.minimumSystemVersion];
    [self bindText:@"depends"    stmt:st index:i++ value:[self joinList:p.dependencies]];
    [self bindText:@"conflicts"  stmt:st index:i++ value:[self joinList:p.conflicts]];
    sqlite3_bind_int(st, i++, p.installed ? 1 : 0);
    [self bindText:@"installed_version" stmt:st index:i++ value:p.installedVersion];
    sqlite3_bind_int(st, i++, p.autoInstalled ? 1 : 0);
    [self bindText:@"receipt_id" stmt:st index:i++ value:p.receiptID];
    [self bindText:@"available_versions" stmt:st index:i++ value:TCDJSONString(p.availableVersions)];

    sqlite3_step(st);
    sqlite3_finalize(st);
}

- (TCDPackage *)packageFromRow:(sqlite3_stmt *)st {
    TCDPackage *p = [[TCDPackage alloc] init];
    p.identifier         = [self textAtColumn:st column:0];
    p.sourceIdentifier   = [self textAtColumn:st column:1];
    p.name               = [self textAtColumn:st column:2];
    p.version            = [self textAtColumn:st column:3];
    p.packageSummary     = [self textAtColumn:st column:4];
    p.packageDescription = [self textAtColumn:st column:5];
    p.developer          = [self textAtColumn:st column:6];
    p.section            = [self textAtColumn:st column:7];
    p.changelog          = [self textAtColumn:st column:8];
    p.iconURLString      = [self textAtColumn:st column:9];
    p.downloadURLString  = [self textAtColumn:st column:10];
    p.sha256             = [self textAtColumn:st column:11];
    p.installPrefix      = [self textAtColumn:st column:12];
    p.type               = (TCDPackageType)sqlite3_column_int(st, 13);
    p.arch               = (TCDPackageArch)sqlite3_column_int(st, 14);
    p.sizeBytes          = (unsigned long long)sqlite3_column_int64(st, 15);
    p.ratingCount        = sqlite3_column_int(st, 16);
    p.ratingAverage      = sqlite3_column_double(st, 17);
    p.minimumSystemVersion = [self textAtColumn:st column:18];
    p.dependencies       = [self splitList:[self textAtColumn:st column:19]];
    p.conflicts          = [self splitList:[self textAtColumn:st column:20]];
    p.installed          = sqlite3_column_int(st, 21) != 0;
    p.installedVersion   = [self textAtColumn:st column:22];
    p.autoInstalled      = sqlite3_column_int(st, 23) != 0;
    p.receiptID          = [self textAtColumn:st column:24];
    p.availableVersions  = TCDJSONArray([self textAtColumn:st column:25]);
    return p;
}

- (NSArray *)query:(NSString *)sql {
    return [self query:sql arguments:nil];
}

/* Every value from an index or from the user must be bound, never spliced
   into SQL text. A source URL or a package name containing a quote would
   otherwise corrupt the statement. */
- (NSArray *)query:(NSString *)sql arguments:(NSArray *)arguments {
    NSMutableArray *out = [NSMutableArray array];
    if (!_db) return out;
    sqlite3_stmt *st = NULL;
    if (sqlite3_prepare_v2(_db, [sql UTF8String], -1, &st, NULL) != SQLITE_OK) {
        NSLog(@"[TCDStore] query failed: %s (%@)", sqlite3_errmsg(_db), sql);
        return out;
    }
    int i = 1;
    for (id a in arguments) {
        if ([a isKindOfClass:[NSNumber class]]) sqlite3_bind_int64(st, i++, [a longLongValue]);
        else [self bindText:sql stmt:st index:i++ value:a];
    }
    while (sqlite3_step(st) == SQLITE_ROW) [out addObject:[self packageFromRow:st]];
    sqlite3_finalize(st);
    return out;
}

static NSString *const kSelectColumns =
    @"identifier,source,name,version,summary,description,developer,section,changelog,"
    @"icon_url,download_url,sha256,install_prefix,type,arch,size_bytes,rating_count,"
    @"rating_average,min_os,depends,conflicts,installed,installed_version,auto_installed,"
    @"receipt_id,available_versions";

- (NSArray *)allPackages {
    return [self query:[NSString stringWithFormat:@"SELECT %@ FROM packages ORDER BY name", kSelectColumns]];
}

- (TCDPackage *)packageWithIdentifier:(NSString *)identifier {
    NSMutableArray *r = [NSMutableArray array];
    if (!_db || !identifier.length) return nil;
    sqlite3_stmt *st = NULL;
    NSString *sql = [NSString stringWithFormat:
                     @"SELECT %@ FROM packages WHERE identifier=? LIMIT 1", kSelectColumns];
    if (sqlite3_prepare_v2(_db, [sql UTF8String], -1, &st, NULL) != SQLITE_OK) return nil;
    [self bindText:sql stmt:st index:1 value:identifier];
    if (sqlite3_step(st) == SQLITE_ROW) [r addObject:[self packageFromRow:st]];
    sqlite3_finalize(st);
    return r.count ? r[0] : nil;
}

- (NSArray *)packagesInSection:(NSString *)section {
    return [self query:[NSString stringWithFormat:
        @"SELECT %@ FROM packages WHERE section=? ORDER BY name", kSelectColumns]
             arguments:[NSArray arrayWithObject:section ?: @""]];
}

- (NSArray *)installedPackages {
    return [self query:[NSString stringWithFormat:
        @"SELECT %@ FROM packages WHERE installed=1 ORDER BY name", kSelectColumns]];
}

- (NSArray *)packagesWithUpdates {
    return [self query:[NSString stringWithFormat:
        @"SELECT %@ FROM packages WHERE installed=1 AND installed_version IS NOT NULL"
        @" AND installed_version <> version ORDER BY name", kSelectColumns]];
}

- (NSArray *)packagesMatchingQuery:(NSString *)query {
    NSString *like = [NSString stringWithFormat:@"%%%@%%",
        [query stringByReplacingOccurrencesOfString:@"'" withString:@"''"]];
    return [self query:[NSString stringWithFormat:
        @"SELECT %@ FROM packages WHERE name LIKE '%@' OR summary LIKE '%@'"
        @" OR developer LIKE '%@' OR section LIKE '%@' ORDER BY name",
        kSelectColumns, like, like, like, like]];
}

- (void)setPackage:(TCDPackage *)pkg installed:(BOOL)installed {
    if (!pkg.identifier) return;
    pkg.installed = installed;
    if (!installed) { pkg.installedVersion = nil; pkg.autoInstalled = NO; }
    [self upsertPackage:pkg];
}

#pragma mark - sources

- (NSArray *)allSources {
    NSMutableArray *out = [NSMutableArray array];
    if (!_db) return out;
    sqlite3_stmt *st = NULL;
    if (sqlite3_prepare_v2(_db,
            "SELECT identifier,name,url,kind,last_sync,last_status FROM sources ORDER BY name",
            -1, &st, NULL) != SQLITE_OK) return out;
    while (sqlite3_step(st) == SQLITE_ROW) {
        [out addObject:[NSDictionary dictionaryWithObjectsAndKeys:
            [self textAtColumn:st column:0], @"identifier",
            [self textAtColumn:st column:1] ?: @"", @"name",
            [self textAtColumn:st column:2] ?: @"", @"url",
            [self textAtColumn:st column:3] ?: @"third-party", @"kind",
            [NSNumber numberWithDouble:sqlite3_column_double(st, 4)], @"lastSync",
            [NSNumber numberWithInt:sqlite3_column_int(st, 5)], @"lastStatus", nil]];
    }
    sqlite3_finalize(st);
    return out;
}

- (NSDictionary *)sourceWithIdentifier:(NSString *)identifier {
    for (NSDictionary *s in [self allSources]) {
        if ([[s objectForKey:@"identifier"] isEqualToString:identifier]) return s;
    }
    return nil;
}

- (void)addSource:(NSDictionary *)source {
    if (!_db) return;
    sqlite3_stmt *st = NULL;
    if (sqlite3_prepare_v2(_db,
            "INSERT OR REPLACE INTO sources (identifier,name,url,kind,added,last_status)"
            " VALUES (?,?,?,?,?,0)", -1, &st, NULL) != SQLITE_OK) return;
    [self bindText:@"x" stmt:st index:1 value:source[@"identifier"]];
    [self bindText:@"x" stmt:st index:2 value:source[@"name"]];
    [self bindText:@"x" stmt:st index:3 value:source[@"url"]];
    NSString *kind = source[@"kind"] ?: @"third-party";
    [self bindText:@"x" stmt:st index:4 value:kind];
    sqlite3_bind_double(st, 5, [[NSDate date] timeIntervalSince1970]);
    sqlite3_step(st);
    sqlite3_finalize(st);
}

- (void)removeSourceWithIdentifier:(NSString *)identifier {
    if (!_db) return;
    sqlite3_stmt *st = NULL;
    if (sqlite3_prepare_v2(_db, "DELETE FROM sources WHERE identifier=?", -1, &st, NULL)
        != SQLITE_OK) return;
    [self bindText:@"x" stmt:st index:1 value:identifier];
    sqlite3_step(st);
    sqlite3_finalize(st);
}

- (void)storeIndexData:(NSData *)data forSource:(NSString *)identifier {
    if (!_db) return;
    sqlite3_stmt *st = NULL;
    if (sqlite3_prepare_v2(_db,
            "UPDATE sources SET index_blob=?, last_sync=?, last_status=1 WHERE identifier=?",
            -1, &st, NULL) != SQLITE_OK) return;
    sqlite3_bind_blob(st, 1, data.bytes, (int)data.length, SQLITE_TRANSIENT);
    sqlite3_bind_double(st, 2, [[NSDate date] timeIntervalSince1970]);
    [self bindText:@"x" stmt:st index:3 value:identifier];
    sqlite3_step(st);
    sqlite3_finalize(st);
}

- (NSData *)indexDataForSource:(NSString *)identifier {
    if (!_db) return nil;
    sqlite3_stmt *st = NULL;
    if (sqlite3_prepare_v2(_db, "SELECT index_blob FROM sources WHERE identifier=?",
                           -1, &st, NULL) != SQLITE_OK) return nil;
    [self bindText:@"x" stmt:st index:1 value:identifier];
    NSData *data = nil;
    if (sqlite3_step(st) == SQLITE_ROW) {
        const void *bytes = sqlite3_column_blob(st, 0);
        int len = sqlite3_column_bytes(st, 0);
        if (bytes && len > 0) data = [NSData dataWithBytes:bytes length:(NSUInteger)len];
    }
    sqlite3_finalize(st);
    return data;
}

@end
