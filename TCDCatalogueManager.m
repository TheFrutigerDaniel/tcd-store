// TCDCatalogueManager.m
#import "TCDCatalogueManager.h"
#import "TCDAppItem.h"

NSString * const TCDCatalogueDidChangeNotification = @"TCDCatalogueDidChangeNotification";

@interface TCDCatalogueManager ()
@property (strong) NSMutableArray *items;
@end

@implementation TCDCatalogueManager

// ── Singleton ─────────────────────────────────────────────────────────────────

+ (instancetype)sharedManager
{
    static TCDCatalogueManager *s = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{ s = [[self alloc] init]; });
    return s;
}

- (instancetype)init
{
    self = [super init];
    if (!self) return nil;
    [self loadBundledCatalogue];
    return self;
}

// ── Load ──────────────────────────────────────────────────────────────────────

- (void)loadBundledCatalogue
{
    NSString *path = [[NSBundle mainBundle]
        pathForResource:@"catalogue" ofType:@"json"];
    NSData *data = path ? [NSData dataWithContentsOfFile:path] : nil;
    _items = [NSMutableArray array];
    if (data) [self mergeFromData:data];
}

- (void)mergeFromData:(NSData *)data
{
    NSError *err = nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
    if (![json isKindOfClass:[NSArray class]]) {
        NSLog(@"[TCDStore] Catalogue parse error: %@", err);
        return;
    }
    [_items removeAllObjects];
    for (NSDictionary *d in (NSArray *)json) {
        TCDAppItem *item = [self itemFromDictionary:d];
        if (item) [_items addObject:item];
    }
}

- (TCDAppItem *)itemFromDictionary:(NSDictionary *)d
{
    NSString *name    = d[@"name"];
    NSArray  *versions = d[@"versions"];
    if (!name.length || !versions.count) return nil;

    NSColor *color = [NSColor colorWithCalibratedRed:0.4 green:0.4 blue:0.4 alpha:1];
    NSArray *rgb = d[@"accentColor"];
    if ([rgb isKindOfClass:[NSArray class]] && rgb.count == 3) {
        color = [NSColor colorWithCalibratedRed:[rgb[0] intValue]/255.0
                                          green:[rgb[1] intValue]/255.0
                                           blue:[rgb[2] intValue]/255.0
                                          alpha:1];
    }
    TCDAppItem *item = [TCDAppItem itemWithName:name
                                      developer:d[@"developer"] ?: @""
                                       category:d[@"category"]  ?: @"Other"
                                    accentColor:color
                                       versions:versions
                                    downloadURL:d[@"downloadURL"] ?: @""];
    item.iconName = d[@"icon"] ?: @"";
    return item;
}

// ── Serialise ─────────────────────────────────────────────────────────────────

- (NSArray *)serialise
{
    NSMutableArray *out = [NSMutableArray array];
    for (TCDAppItem *item in _items) {
        NSColor *c = [item.accentColor
            colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
        [out addObject:@{
            @"name":        item.name        ?: @"",
            @"developer":   item.developer   ?: @"",
            @"category":    item.category    ?: @"Other",
            @"accentColor": @[@((int)(c.redComponent*255)),
                              @((int)(c.greenComponent*255)),
                              @((int)(c.blueComponent*255))],
            @"icon":        item.iconName    ?: @"",
            @"versions":    item.versions    ?: @[],
            @"downloadURL": item.downloadURL ?: @""
        }];
    }
    return out;
}

// ── Categories ────────────────────────────────────────────────────────────────

- (NSArray *)categories
{
    NSMutableOrderedSet *set = [NSMutableOrderedSet orderedSet];
    for (TCDAppItem *i in _items)
        if (i.category.length) [set addObject:i.category];
    NSMutableArray *cats = [NSMutableArray arrayWithObject:@"All"];
    [cats addObjectsFromArray:set.array];
    return cats;
}

// ── CRUD ──────────────────────────────────────────────────────────────────────

- (void)addItem:(TCDAppItem *)item
{
    [_items addObject:item];
    [self postChange];
}

- (void)removeItem:(TCDAppItem *)item
{
    [_items removeObject:item];
    [self postChange];
}

- (void)replaceItem:(TCDAppItem *)old withItem:(TCDAppItem *)new
{
    NSUInteger idx = [_items indexOfObject:old];
    if (idx != NSNotFound) [_items replaceObjectAtIndex:idx withObject:new];
    [self postChange];
}

- (void)postChange
{
    [[NSNotificationCenter defaultCenter]
        postNotificationName:TCDCatalogueDidChangeNotification object:nil];
}

// ── Export ────────────────────────────────────────────────────────────────────

- (void)exportWithWindow:(NSWindow *)w
{
    NSSavePanel *p         = [NSSavePanel savePanel];
    p.title                = @"Export Catalogue";
    p.nameFieldStringValue = @"catalogue.json";
    p.allowedFileTypes     = @[@"json"];
    [p beginSheetModalForWindow:w completionHandler:^(NSInteger r) {
        if (r != NSFileHandlingPanelOKButton) return;
        NSData *data = [NSJSONSerialization
            dataWithJSONObject:[self serialise]
                       options:NSJSONWritingPrettyPrinted error:nil];
        [data writeToURL:[p URL] atomically:YES];
    }];
}

// ── Import ────────────────────────────────────────────────────────────────────

- (void)importWithWindow:(NSWindow *)w
{
    NSOpenPanel *p            = [NSOpenPanel openPanel];
    p.title                   = @"Import Catalogue";
    p.allowedFileTypes        = @[@"json"];
    p.allowsMultipleSelection = NO;
    p.canChooseDirectories    = NO;
    [p beginSheetModalForWindow:w completionHandler:^(NSInteger r) {
        if (r != NSFileHandlingPanelOKButton) return;
        NSData *data = [NSData dataWithContentsOfURL:[p URL]];
        if (!data) return;
        [self mergeFromData:data];
        dispatch_async(dispatch_get_main_queue(), ^{ [self postChange]; });
    }];
}

// ── Icon resolution ───────────────────────────────────────────────────────────

+ (NSString *)userIconDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(
        NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *base = [paths firstObject];
    NSString *dir  = [[base stringByAppendingPathComponent:@"TCDStore"]
                             stringByAppendingPathComponent:@"AppIcons"];
    [[NSFileManager defaultManager]
        createDirectoryAtPath:dir
  withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

+ (NSString *)installIconFromPath:(NSString *)srcPath
{
    if (!srcPath.length) return nil;
    NSString *filename = [srcPath lastPathComponent];
    NSString *destDir  = [self userIconDirectory];
    NSString *destPath = [destDir stringByAppendingPathComponent:filename];

    NSFileManager *fm = [NSFileManager defaultManager];
    // Overwrite if already exists
    if ([fm fileExistsAtPath:destPath])
        [fm removeItemAtPath:destPath error:nil];

    NSError *err = nil;
    BOOL ok = [fm copyItemAtPath:srcPath toPath:destPath error:&err];
    if (!ok) {
        NSLog(@"[TCDStore] Icon copy failed: %@", err);
        return nil;
    }
    return filename;
}

+ (NSImage *)iconNamed:(NSString *)name
{
    if (!name.length) return nil;

    // 1. User support directory
    NSString *userPath = [[self userIconDirectory]
        stringByAppendingPathComponent:name];
    if ([[NSFileManager defaultManager] fileExistsAtPath:userPath]) {
        NSImage *img = [[NSImage alloc] initWithContentsOfFile:userPath];
        if (img) return img;
    }

    // 2. App bundle Resources/AppIcons/
    NSString *bundlePath = [[NSBundle mainBundle]
        pathForResource:[name stringByDeletingPathExtension]
                 ofType:[name pathExtension]
            inDirectory:@"AppIcons"];
    if (bundlePath) {
        NSImage *img = [[NSImage alloc] initWithContentsOfFile:bundlePath];
        if (img) return img;
    }

    // 3. NSImage named cache
    return [NSImage imageNamed:name];
}

@end
