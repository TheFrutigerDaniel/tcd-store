//
//  TCDAppDelegate.m
//  TCD Store
//
//  10.7 constraints this file is written around:
//    · no NSStackView        (10.9)
//    · no NSVisualEffectView (10.10, and no fallback on 10.7)
//    · no NSURLSession       (10.9)
//    · no Auto Layout attribute introduced after 10.7
//    · frames + autoresizing, which is what a 10.7-era app would ship anyway
//

#import "TCDAppDelegate.h"
#import "TCDPackageDatabase.h"
#import "TCDIndexParser.h"
#import "TCDResolver.h"
#import "TCDInstaller.h"
#import "TCDAuthorizer.h"
#import "TCDSigner.h"

@interface TCDAppDelegate ()
@property (nonatomic, strong) NSArray *packages;
@property (nonatomic, strong) TCDSigner *signer;
@end

@implementation TCDAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)note {
    self.signer = [[TCDSigner alloc]
        initWithPolicy:[TCDSigner policyFromDefaults]];

    TCDPackageDatabase *db = [TCDPackageDatabase sharedDatabase];
    NSError *err = nil;
    if (![db openWithError:&err]) {
        [self presentFatal:err.localizedDescription];
        return;
    }
    [self buildWindow];
    [self reloadFromDatabase];
    [self refreshAllSources];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshAllSources)
                                                 name:@"TCDRefreshRequested"
                                               object:nil];
}

- (void)applicationWillTerminate:(NSNotification *)note {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[TCDPackageDatabase sharedDatabase] close];
}

- (void)presentFatal:(NSString *)message {
    NSAlert *a = [[NSAlert alloc] init];
    [a setMessageText:@"TCD Store cannot open its package database."];
    [a setInformativeText:message ?: @"Unknown error."];
    [a addButtonWithTitle:@"Quit"];
    [a runModal];
    [NSApp terminate:nil];
}

#pragma mark - window

- (void)buildWindow {
    NSRect frame = NSMakeRect(0, 0, 1000, 660);
    NSUInteger mask = NSTitledWindowMask | NSClosableWindowMask |
                      NSMiniaturizableWindowMask | NSResizableWindowMask;
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                             styleMask:mask
                                               backing:NSBackingStoreBuffered
                                                 defer:NO];
    [self.window setTitle:@"TCD Store"];
    [self.window center];
    [self.window setMinSize:NSMakeSize(820, 520)];
    [self.window makeKeyAndOrderFront:nil];

    NSView *content = [self.window contentView];

    // ---- title bar ----
    self.titleField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, frame.size.height - 34,
                                                                   frame.size.width, 24)];
    [self.titleField setAlignment:NSRightTextAlignment];
    [self.titleField setBezeled:NO];
    [self.titleField setDrawsBackground:NO];
    [self.titleField setEditable:NO];
    [self.titleField setSelectable:NO];
    [self.titleField setFont:[NSFont boldSystemFontOfSize:13.0]];
    [content addSubview:self.titleField];

    // ---- source list ----
    self.sourceList = [[NSOutlineView alloc] initWithFrame:
        NSMakeRect(0, 0, 210, frame.size.height - 38)];
    [self.sourceList setHeaderView:nil];
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"source"];
    [col setWidth:190];
    [self.sourceList addTableColumn:col];
    [self.sourceList setOutlineTableColumn:col];
    [self.sourceList setRowSizeStyle:NSTableViewRowSizeStyleDefault];
    [self.sourceList setRowHeight:26];

    NSScrollView *sidebarScroll = [[NSScrollView alloc] initWithFrame:
        NSMakeRect(0, 0, 210, frame.size.height - 38)];
    [sidebarScroll setDocumentView:self.sourceList];
    [sidebarScroll setHasVerticalScroller:YES];
    [sidebarScroll setAutohidesScrollers:YES];
    [sidebarScroll setBorderType:NSNoBorder];
    [content addSubview:sidebarScroll];

    // ---- content table ----
    self.contentTable = [[NSTableView alloc] initWithFrame:
        NSMakeRect(210, 0, frame.size.width - 210, frame.size.height - 38)];
    [self.contentTable setHeaderView:nil];
    NSTableColumn *icon = [[NSTableColumn alloc] initWithIdentifier:@"icon"];
    [icon setWidth:44];
    NSTableColumn *name = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    [name setWidth:230];
    NSTableColumn *summary = [[NSTableColumn alloc] initWithIdentifier:@"summary"];
    [summary setWidth:420];
    [self.contentTable addTableColumn:icon];
    [self.contentTable addTableColumn:name];
    [self.contentTable addTableColumn:summary];
    [self.contentTable setRowHeight:34];
    [self.contentTable setTarget:self];
    [self.contentTable setDoubleAction:@selector(contentTableDoubleClicked:)];

    NSScrollView *contentScroll = [[NSScrollView alloc] initWithFrame:
        NSMakeRect(210, 0, frame.size.width - 210, frame.size.height - 38)];
    [contentScroll setDocumentView:self.contentTable];
    [contentScroll setHasVerticalScroller:YES];
    [contentScroll setAutohidesScrollers:YES];
    [contentScroll setBorderType:NSNoBorder];
    [content addSubview:contentScroll];

    // Autosizing rather than constraints: this is the idiom a 10.7 target
    // forces, and it survives a resize without a layout pass.
    [sidebarScroll setAutoresizingMask:NSViewMinXMargin | NSViewHeightSizable];
    [contentScroll setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self.titleField setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];

    [content setAutoresizesSubviews:YES];
    [content setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
}

#pragma mark - data

- (void)reloadFromDatabase {
    self.packages = [[TCDPackageDatabase sharedDatabase] allPackages];
    [self.sourceList reloadData];
    [self.contentTable reloadData];
}

- (void)refreshAllSources {
    TCDPackageDatabase *db = [TCDPackageDatabase sharedDatabase];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (NSDictionary *source in [db allSources]) {
            NSString *urlString = [source objectForKey:@"url"];
            NSURL *url = [NSURL URLWithString:urlString];
            if (!url) continue;
            NSURLRequest *req = [NSURLRequest requestWithURL:url
                                                 cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                             timeoutInterval:45.0];
            // NSURLSession is 10.9; NSURLConnection is the 10.7 answer.
            [NSURLConnection sendAsynchronousRequest:req
                                              queue:[NSOperationQueue mainQueue]
                                  completionHandler:
                ^(NSURLResponse *r, NSData *d, NSError *e) {
                if (!e && d.length) {
                    NSArray *parsed = [TCDIndexParser parseIndexData:d
                                                    sourceIdentifier:[source objectForKey:@"identifier"]
                                                         skippedOut:NULL];
                    [db beginTransaction];
                    for (TCDPackage *p in parsed) {
                        // Keep what the local database already knows.
                        TCDPackage *old = [db packageWithIdentifier:p.identifier];
                        if (old) {
                            p.installed        = old.installed;
                            p.installedVersion = old.installedVersion;
                            p.autoInstalled    = old.autoInstalled;
                            p.receiptID        = old.receiptID;
                        }
                        [db upsertPackage:p];
                    }
                    [db storeIndexData:d forSource:[source objectForKey:@"identifier"]];
                    [db commit];
                    [self reloadFromDatabase];
                }
            }];
        }
    });
}

#pragma mark - install

- (void)installPackage:(TCDPackage *)pkg {
    TCDResolver *resolver = [[TCDResolver alloc] initWithCatalogue:self.packages];
    TCDInstallPlan *plan = [resolver planForPackage:pkg];
    if (![plan isValid]) {
        NSAlert *a = [[NSAlert alloc] init];
        [a setMessageText:[NSString stringWithFormat:@"Cannot install %@", pkg.name]];
        [a setInformativeText:plan.failureReason ?: @"A required package is missing."];
        [a addButtonWithTitle:@"OK"];
        [a runModal];
        return;
    }

    TCDAuthorizer *auth = [[TCDAuthorizer alloc] init];
    TCDInstaller *installer = [[TCDInstaller alloc] initWithAuthorizer:auth
                                                               signer:self.signer];
    TCDInstallSession *session = [installer installPlan:plan];

    NSProgressIndicator *spinner = [[NSProgressIndicator alloc]
        initWithFrame:NSMakeRect(0, 0, 32, 32)];
    [spinner setStyle:NSProgressIndicatorSpinningStyle];
    [spinner startAnimation:nil];
    [spinner setFrameOrigin:NSMakePoint(22, 18)];
    [[self.window contentView] addSubview:spinner];

    [session setStepChanged:^(TCDInstallStep *step) {
        [self.titleField setStringValue:step.title];
    }];

    // Poll the session rather than running a nested run loop: the engine is
    // serial and single-purpose, and an invalidated timer is easy to reason
    // about. -[TCDInstallSession finished] is set on the main queue, so this
    // always runs on the main thread.
    [NSTimer scheduledTimerWithTimeInterval:0.05
                                     target:self
                                   selector:@selector(pollSession:)
                                   userInfo:@{ @"session": session, @"spinner": spinner }
                                    repeats:YES];
}

- (void)pollSession:(NSTimer *)timer {
    NSDictionary *ctx = [timer userInfo];
    TCDInstallSession *session = [ctx objectForKey:@"session"];
    if (!session.finished) return;

    [timer invalidate];
    [(NSProgressIndicator *)[ctx objectForKey:@"spinner"] stopAnimation:nil];
    [[[ctx objectForKey:@"spinner"] superview] removeSubview:[ctx objectForKey:@"spinner"]];

    if (session.failureReason) {
        NSAlert *a = [[NSAlert alloc] init];
        [a setMessageText:@"Installation failed."];
        [a setInformativeText:session.failureReason];
        [a addButtonWithTitle:@"OK"];
        [a runModal];
    }
    [self reloadFromDatabase];
}

- (void)contentTableDoubleClicked:(id)sender {
    NSInteger row = [self.contentTable clickedRow];
    if (row < 0 || row >= (NSInteger)self.packages.count) return;
    [self installPackage:self.packages[(NSUInteger)row]];
}

@end
