//
//  TCDSourcesWindowController.h
//  TCD Store
//
//  The Sources window: which indexes the store is built from.
//
//  This replaces the beta branch's Catalogue menu, which edited a
//  hand-authored catalogue.json. A store is driven by sources, so the same
//  slot now lists them and lets one be added, refreshed or removed -- including
//  the bundled demo source, whose removal was otherwise only reachable from
//  code.
//
//  It is a window rather than a screen in the store area, which is the shape
//  the beta branch already used for the catalogue editor, and keeps the store
//  grid for browsing rather than for administration.
//

#import <Cocoa/Cocoa.h>

@interface TCDSourcesWindowController : NSWindowController

+ (TCDSourcesWindowController *)sharedController;

@end
