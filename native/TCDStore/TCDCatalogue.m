// TCDCatalogue.m
//
// The shim both the grid and the sidebar read through, so it is the one place
// that had to change when the store became a real store. It used to hand back
// TCDCatalogueManager's hand-authored catalogue; it now hands back whatever the
// package database holds, which is a list of sources and their parsed indexes
// rather than an imported JSON file.

#import "TCDCatalogue.h"
#import "TCDStoreFeed.h"

@implementation TCDCatalogue

+ (NSArray *)allItems   { return [[TCDStoreFeed sharedFeed] items]; }
+ (NSArray *)categories { return [[TCDStoreFeed sharedFeed] categories]; }

@end
