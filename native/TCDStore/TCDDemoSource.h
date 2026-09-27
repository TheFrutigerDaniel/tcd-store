//
//  TCDDemoSource.h
//  TCD Store
//
//  The bundled demo source.
//
//  The store with no sources shows an empty grid, which says nothing about
//  whether the store works. So the app ships a small Packages-format index and
//  registers it as a source on first launch.
//
//  It is a source like any other: it is a row in the sources table with a URL,
//  and the refresh path fetches it with the same NSURLConnection call every
//  other source goes through — a file:// URL rather than http, that is the only
//  difference. Deleting the row removes it completely, and the Sources screen
//  can put it back.
//

#import <Foundation/Foundation.h>

@interface TCDDemoSource : NSObject

/* The identifier every bundled-demo row is stored under. */
+ (NSString *)identifier;
+ (NSString *)displayName;

/* YES when the index is present in the running bundle. */
+ (BOOL)isAvailable;

/* Adds the source if it is not already registered. Does nothing if the store
   has any sources at all, so a real source is never joined by a demo one
   behind the user's back. */
+ (BOOL)registerIfNoSourcesExist;

/* Adds it regardless, which is what the Sources screen's "add demo" does. */
+ (BOOL)register;

/* Removes the source and every package that came from it. NO if the row was
   not there. */
+ (BOOL)remove;

/* file:// URL of the bundled index, or nil when it is not in the bundle. */
+ (NSURL *)indexURL;

@end
