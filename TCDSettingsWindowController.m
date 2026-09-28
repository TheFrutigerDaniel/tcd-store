// TCDSettingsWindowController.m
#import "TCDSettingsWindowController.h"
#import "TCDCatalogueManager.h"
#import "TCDCatalogueEditorWindowController.h"

static NSString * const kDownloadDirKey = @"TCDDownloadDirectory";

@interface TCDSettingsWindowController ()
@property (strong) NSTextField *dirLabel;
@end

@implementation TCDSettingsWindowController

+ (instancetype)sharedController
{
    static TCDSettingsWindowController *s = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{ s = [[self alloc] init]; });
    return s;
}

- (instancetype)init
{
    NSWindow *win = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 420, 230)
                  styleMask:NSTitledWindowMask | NSClosableWindowMask
                    backing:NSBackingStoreBuffered defer:NO];
    win.title              = @"TCD Store — Settings";
    win.releasedWhenClosed = NO;
    self = [super initWithWindow:win];
    if (!self) return nil;
    [self buildContentView];
    return self;
}

- (NSString *)downloadDirectory
{
    NSString *s = [[NSUserDefaults standardUserDefaults]
                   stringForKey:kDownloadDirKey];
    return s.length ? s :
        [NSHomeDirectory() stringByAppendingPathComponent:@"Downloads"];
}

- (void)setDownloadDirectory:(NSString *)path
{
    [[NSUserDefaults standardUserDefaults] setObject:path forKey:kDownloadDirKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    _dirLabel.stringValue = path;
}

- (void)buildContentView
{
    NSView *root = self.window.contentView;

    // ── Download Location ─────────────────────────────────────────────────
    [root addSubview:[self labelWithFrame:NSMakeRect(20, 192, 380, 16)
                                     bold:YES text:@"Download Location"]];
    _dirLabel = [self labelWithFrame:NSMakeRect(20, 168, 300, 20)
                                bold:NO text:self.downloadDirectory];
    ((NSTextFieldCell *)_dirLabel.cell).lineBreakMode = NSLineBreakByTruncatingHead;
    [root addSubview:_dirLabel];

    NSButton *chooseBtn = [[NSButton alloc] initWithFrame:NSMakeRect(326, 164, 74, 26)];
    chooseBtn.title = @"Choose…"; chooseBtn.bezelStyle = NSRoundedBezelStyle;
    chooseBtn.target = self; chooseBtn.action = @selector(chooseDirectory:);
    [root addSubview:chooseBtn];

    NSButton *resetBtn = [[NSButton alloc] initWithFrame:NSMakeRect(20, 132, 140, 24)];
    resetBtn.title = @"Reset to Default"; resetBtn.bezelStyle = NSRoundedBezelStyle;
    resetBtn.target = self; resetBtn.action = @selector(resetDirectory:);
    [root addSubview:resetBtn];

    // ── Catalogue ─────────────────────────────────────────────────────────
    [root addSubview:[self labelWithFrame:NSMakeRect(20, 104, 380, 16)
                                     bold:YES text:@"Catalogue"]];

    NSButton *editBtn = [[NSButton alloc] initWithFrame:NSMakeRect(20, 74, 140, 24)];
    editBtn.title = @"Edit Catalogue…"; editBtn.bezelStyle = NSRoundedBezelStyle;
    editBtn.target = self; editBtn.action = @selector(openEditor:);
    [root addSubview:editBtn];

    NSButton *importBtn = [[NSButton alloc] initWithFrame:NSMakeRect(20, 44, 120, 24)];
    importBtn.title = @"Import…"; importBtn.bezelStyle = NSRoundedBezelStyle;
    importBtn.target = self; importBtn.action = @selector(importCatalogue:);
    [root addSubview:importBtn];

    NSButton *exportBtn = [[NSButton alloc] initWithFrame:NSMakeRect(148, 44, 120, 24)];
    exportBtn.title = @"Export…"; exportBtn.bezelStyle = NSRoundedBezelStyle;
    exportBtn.target = self; exportBtn.action = @selector(exportCatalogue:);
    [root addSubview:exportBtn];

    // ── Done ──────────────────────────────────────────────────────────────
    NSButton *doneBtn = [[NSButton alloc] initWithFrame:NSMakeRect(326, 10, 74, 24)];
    doneBtn.title = @"Done"; doneBtn.bezelStyle = NSRoundedBezelStyle;
    doneBtn.target = self; doneBtn.action = @selector(close);
    [root addSubview:doneBtn];
    self.window.defaultButtonCell = (NSButtonCell *)doneBtn.cell;
}

- (void)chooseDirectory:(id)sender
{
    NSOpenPanel *p = [NSOpenPanel openPanel];
    p.canChooseFiles = NO; p.canChooseDirectories = YES;
    p.allowsMultipleSelection = NO;
    p.title = @"Choose Download Folder"; p.prompt = @"Select";
    [p beginSheetModalForWindow:self.window completionHandler:^(NSInteger r) {
        if (r == NSFileHandlingPanelOKButton)
            [self setDownloadDirectory:[[p URL] path]];
    }];
}

- (void)resetDirectory:(id)sender
{
    [self setDownloadDirectory:
     [NSHomeDirectory() stringByAppendingPathComponent:@"Downloads"]];
}

- (void)openEditor:(id)sender
{
    TCDCatalogueEditorWindowController *ed =
        [TCDCatalogueEditorWindowController sharedController];
    [ed.window center];
    [ed showWindow:sender];
    [ed.window makeKeyAndOrderFront:sender];
}

- (void)importCatalogue:(id)sender
{
    [[TCDCatalogueManager sharedManager] importWithWindow:self.window];
}

- (void)exportCatalogue:(id)sender
{
    [[TCDCatalogueManager sharedManager] exportWithWindow:self.window];
}

- (NSTextField *)labelWithFrame:(NSRect)f bold:(BOOL)bold text:(NSString *)t
{
    NSTextField *tf    = [[NSTextField alloc] initWithFrame:f];
    tf.stringValue     = t;
    tf.editable = tf.selectable = tf.bordered = tf.drawsBackground = NO;
    tf.font      = bold ? [NSFont boldSystemFontOfSize:12]
                        : [NSFont systemFontOfSize:11];
    tf.textColor = bold ? [NSColor blackColor] : [NSColor darkGrayColor];
    return tf;
}

@end
