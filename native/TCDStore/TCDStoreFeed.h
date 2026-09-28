//
//  TCDStoreFeed.h
//  TCD Store
//
//  The bridge between the real store and the beta branch's grid.
//
//  Two data layers now meet here. The beta filled its grid from
//  TCDCatalogueManager: a hand-authored catalogue.json holding TCDAppItems
//  with a downloadURL each, imported by hand through Catalogue -> Import. That
//  is a catalogue browser, not a store -- there is no source, no index, no
//  install unit and nothing to remove.
//
//  The real side is TCDPackageDatabase: sources, Packages-format indexes parsed
//  into TCDPackage rows, and local install state. TCDStoreFeed opens that
//  database, registers the bundled demo source on a store that has no sources,
//  fetches and parses every index, and presents the result as the TCDAppItems
//  the beta's grid and sidebar already know how to draw.
//
//  Both the grid and the sidebar read through +TCDCatalogue, so that shim is
//  the only thing that had to change.
//

#import <Cocoa/Cocoa.h>

@class TCDAppItem;
@class TCDPackage;

@interface TCDStoreFeed : NSObject

+ (TCDStoreFeed *)sharedFeed;

/* Opens the database, registers the bundled demo source when the store has no
   sources at all, and ingests every index. Called once from the app delegate,
   before the window is built, so the grid is populated on the first paint
   rather than filling in a moment later.

   Local indexes are ingested synchronously -- they are a file read and a
   parse, and blocking on that costs nothing. Remote indexes are fetched off
   the main thread and ingested back on it, because every database call
   happens on the main thread: SQLite connections are not safe to share
   across threads. Returns NO if the database could not be opened. */
- (BOOL)prepareStore;

/* TCDAppItem for the beta's grid. Rebuilt from the database on each call, so
   a caller always sees current install state. */
- (NSArray *)items;

/* "All" first, then every section currently in use, sorted. */
- (NSArray *)categories;

/* The TCDPackage behind a card, for install, update and downgrade. Nil when
   the item did not come from the feed. */
- (TCDPackage *)packageForItem:(TCDAppItem *)item;

/* Every source, as dictionaries with identifier, name, url, kind, lastSync,
   lastStatus and lastError. lastStatus is 0 never synced, 1 ok, 2 failed. */
- (NSArray *)sources;

/* How many packages a source currently contributes to the grid. */
- (NSUInteger)packageCountForSourceIdentifier:(NSString *)identifier;

/* Re-fetches every source. Local ones land immediately; remote ones post
   TCDCatalogueDidChangeNotification when they arrive. */
- (void)refresh;

/* One source, start to finish, on the calling thread. Returns NO if the fetch
   failed or the index held nothing usable -- the source is still recorded as
   failed, with the reason, and the grid falls back to the cached index. */
- (BOOL)refreshSourceWithIdentifier:(NSString *)identifier;

/* Adds a source and refreshes it. The identifier is the absolute URL, which is
   stable and unique. NO if the URL will not parse or is already added. */
- (BOOL)addSourceWithName:(NSString *)name url:(NSString *)url;

/* Removes a source and every package that came from it, as one transaction.
   NO if there was no such source. */
- (BOOL)removeSourceWithIdentifier:(NSString *)identifier;

/* Drops the bundled demo source. This is the removal path the demo source is
   supposed to have, and it is what the Sources window's Remove button calls. */
- (BOOL)removeDemoSource;

@end
