// TCDCatalogueManager.h
#import <Foundation/Foundation.h>
// Cocoa, not Foundation: this header uses NSWindow. The beta branch was
// built with an Xcode prefix header that supplied AppKit implicitly; the
// Makefile build has no prefix header, so the import has to be explicit.
#import <Cocoa/Cocoa.h>
@class TCDAppItem;

extern NSString * const TCDCatalogueDidChangeNotification;

@interface TCDCatalogueManager : NSObject

+ (instancetype)sharedManager;

@property (strong, readonly) NSMutableArray *items;

- (NSArray *)categories;

// ── CRUD ──────────────────────────────────────────────────────────────────────
- (void)addItem:(TCDAppItem *)item;
- (void)removeItem:(TCDAppItem *)item;
- (void)replaceItem:(TCDAppItem *)old withItem:(TCDAppItem *)new;

// ── Import / Export ───────────────────────────────────────────────────────────
- (void)exportWithWindow:(NSWindow *)parentWindow;
- (void)importWithWindow:(NSWindow *)parentWindow;

// ── Icon resolution ───────────────────────────────────────────────────────────
// Checks ~/Library/Application Support/TCDStore/AppIcons/ first,
// then the app bundle's Resources/AppIcons/, then NSImage named cache.
+ (NSImage *)iconNamed:(NSString *)name;

// Returns ~/Library/Application Support/TCDStore/AppIcons/, creating it if needed.
+ (NSString *)userIconDirectory;

// Copies an image file at srcPath into the user icon directory.
// Returns the destination filename (not full path), or nil on failure.
+ (NSString *)installIconFromPath:(NSString *)srcPath;

@end
