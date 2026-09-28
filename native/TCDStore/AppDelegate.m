// AppDelegate.m
#import "AppDelegate.h"
#import "TCDHeaderView.h"
#import "TCDSidebarView.h"
#import "TCDStoreViewController.h"
#import "TCDDownloadsViewController.h"
#import "TCDSettingsWindowController.h"
#import "TCDCatalogueEditorWindowController.h"
#import "TCDCatalogueManager.h"
#import "TCDStoreFeed.h"

@interface AppDelegate ()
@property (strong) NSWindow                              *window;
@property (strong) NSTabView                             *tabView;
@property (strong) TCDSidebarView                        *sidebarView;
@property (strong) TCDStoreViewController                *storeVC;
@property (strong) TCDDownloadsViewController            *downloadsVC;
@property (strong) TCDSettingsWindowController           *settingsWC;
@property (strong) TCDCatalogueEditorWindowController    *editorWC;
@end

@implementation AppDelegate

- (void)buildMainMenu
{
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@""];
    [NSApp setMainMenu:mainMenu];

    // ── App menu ──────────────────────────────────────────────────────────
    NSMenuItem *appMenuItem = [[NSMenuItem alloc]
        initWithTitle:@"" action:nil keyEquivalent:@""];
    [mainMenu addItem:appMenuItem];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"TCD Store"];
    appMenuItem.submenu = appMenu;

    NSMenuItem *about = [[NSMenuItem alloc]
        initWithTitle:@"About TCD Store"
               action:@selector(showAbout:) keyEquivalent:@""];
    about.target = self;
    [appMenu addItem:about];

    [appMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *settings = [[NSMenuItem alloc]
        initWithTitle:@"Settings…"
               action:@selector(openSettings:) keyEquivalent:@","];
    settings.target = self;
    [appMenu addItem:settings];

    [appMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *hide = [[NSMenuItem alloc]
        initWithTitle:@"Hide TCD Store"
               action:@selector(hide:) keyEquivalent:@"h"];
    [appMenu addItem:hide];
    NSMenuItem *hideOthers = [[NSMenuItem alloc]
        initWithTitle:@"Hide Others"
               action:@selector(hideOtherApplications:) keyEquivalent:@"h"];
    hideOthers.keyEquivalentModifierMask = NSCommandKeyMask | NSAlternateKeyMask;
    [appMenu addItem:hideOthers];
    [[appMenu addItemWithTitle:@"Show All"
                        action:@selector(unhideAllApplications:)
                 keyEquivalent:@""] setTarget:nil];

    [appMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quit = [[NSMenuItem alloc]
        initWithTitle:@"Quit TCD Store"
               action:@selector(terminate:) keyEquivalent:@"q"];
    [appMenu addItem:quit];

    // ── Catalogue menu ────────────────────────────────────────────────────
    NSMenuItem *catMenuItem = [[NSMenuItem alloc]
        initWithTitle:@"Catalogue" action:nil keyEquivalent:@""];
    [mainMenu addItem:catMenuItem];
    NSMenu *catMenu = [[NSMenu alloc] initWithTitle:@"Catalogue"];
    catMenuItem.submenu = catMenu;

    NSMenuItem *editor = [[NSMenuItem alloc]
        initWithTitle:@"Edit Catalogue…"
               action:@selector(openEditor:) keyEquivalent:@"e"];
    editor.keyEquivalentModifierMask = NSCommandKeyMask | NSShiftKeyMask;
    editor.target = self;
    [catMenu addItem:editor];

    [catMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *importItem = [[NSMenuItem alloc]
        initWithTitle:@"Import…"
               action:@selector(importCatalogue:) keyEquivalent:@""];
    importItem.target = self;
    [catMenu addItem:importItem];

    NSMenuItem *exportItem = [[NSMenuItem alloc]
        initWithTitle:@"Export…"
               action:@selector(exportCatalogue:) keyEquivalent:@""];
    exportItem.target = self;
    [catMenu addItem:exportItem];

    // ── Window menu ───────────────────────────────────────────────────────
    NSMenuItem *winMenuItem = [[NSMenuItem alloc]
        initWithTitle:@"Window" action:nil keyEquivalent:@""];
    [mainMenu addItem:winMenuItem];
    NSMenu *winMenu = [[NSMenu alloc] initWithTitle:@"Window"];
    winMenuItem.submenu = winMenu;
    [[winMenu addItemWithTitle:@"Minimize"
                        action:@selector(performMiniaturize:)
                 keyEquivalent:@"m"] setTarget:nil];
    [[winMenu addItemWithTitle:@"Zoom"
                        action:@selector(performZoom:)
                 keyEquivalent:@""] setTarget:nil];
    [NSApp setWindowsMenu:winMenu];
}

- (void)applicationWillFinishLaunching:(NSNotification *)note
{
    [self buildMainMenu];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Before the window is built. TCDStoreViewController reads the database in
    // its initialiser, so anything prepared after this point misses the first
    // paint and the grid comes up empty until something forces a reload.
    [[TCDStoreFeed sharedFeed] prepareStore];

    NSRect cr = NSMakeRect(0, 0, 980, 580);
    NSUInteger style = NSTitledWindowMask | NSClosableWindowMask
                     | NSMiniaturizableWindowMask | NSResizableWindowMask;
    _window = [[NSWindow alloc]
        initWithContentRect:cr styleMask:style
                    backing:NSBackingStoreBuffered defer:NO];
    _window.title   = @"TCD Store";
    _window.minSize = NSMakeSize(700, 460);

    NSView *root     = _window.contentView;
    CGFloat hH       = 68;
    CGFloat sidebarW = 150.0;
    CGFloat contentH = NSHeight(cr) - hH;

    TCDHeaderView *header = [[TCDHeaderView alloc]
        initWithFrame:NSMakeRect(0, NSHeight(cr)-hH, NSWidth(cr), hH)];
    header.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [root addSubview:header];

    _sidebarView = [[TCDSidebarView alloc]
        initWithFrame:NSMakeRect(0, 0, sidebarW, contentH)];
    _sidebarView.autoresizingMask = NSViewHeightSizable;
    [root addSubview:_sidebarView];

    _tabView = [[NSTabView alloc]
        initWithFrame:NSMakeRect(sidebarW, 0, NSWidth(cr)-sidebarW, contentH)];
    _tabView.tabViewType      = NSNoTabsNoBorder;
    _tabView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [root addSubview:_tabView];

    _downloadsVC = [[TCDDownloadsViewController alloc] init];
    NSTabViewItem *dlTab = [[NSTabViewItem alloc] initWithIdentifier:@"downloads"];
    dlTab.view = _downloadsVC.view;
    [_tabView addTabViewItem:dlTab];

    _storeVC = [[TCDStoreViewController alloc] init];
    _storeVC.downloadsVC = _downloadsVC;
    NSTabViewItem *storeTab = [[NSTabViewItem alloc] initWithIdentifier:@"store"];
    storeTab.view = _storeVC.view;
    [_tabView insertTabViewItem:storeTab atIndex:0];
    [_tabView selectTabViewItemAtIndex:0];

    _sidebarView.tabView     = _tabView;
    _sidebarView.downloadsVC = _downloadsVC;
    _sidebarView.storeVC     = _storeVC;

    _settingsWC = [TCDSettingsWindowController sharedController];
    _editorWC   = [TCDCatalogueEditorWindowController sharedController];

    [_window center];
    [_window makeKeyAndOrderFront:nil];
}

// ── Actions ───────────────────────────────────────────────────────────────────

- (IBAction)showAbout:(id)sender
{
    NSAlert *a = [[NSAlert alloc] init];
    a.messageText     = @"TCD Store";
    a.informativeText =
        @"Version: Beta 1.5.0\n"
         "A community app store for OS X 10.7 – 10.9.\n\n"
         "Made by TCDcorp.\n"
         "Built with Objective-C and Cocoa.";
    [a addButtonWithTitle:@"OK"];
    [a runModal];
}

- (IBAction)openSettings:(id)sender
{
    [_settingsWC.window center];
    [_settingsWC showWindow:sender];
    [_settingsWC.window makeKeyAndOrderFront:sender];
}

- (IBAction)openEditor:(id)sender
{
    [_editorWC.window center];
    [_editorWC showWindow:sender];
    [_editorWC.window makeKeyAndOrderFront:sender];
}

- (IBAction)importCatalogue:(id)sender
{
    [[TCDCatalogueManager sharedManager] importWithWindow:_window];
}

- (IBAction)exportCatalogue:(id)sender
{
    [[TCDCatalogueManager sharedManager] exportWithWindow:_window];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)s
{
    return YES;
}

@end
