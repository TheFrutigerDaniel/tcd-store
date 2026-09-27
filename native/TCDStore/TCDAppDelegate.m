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
//  The layout: the native title bar, then ONE black bar (TCDAeroBar) holding
//  the wordmark, the Store | Downloads pills and the search field, then the
//  split. Store shows the black sidebar plus the grid; Downloads hides the
//  sidebar and runs full width. There is no separate progress window: an
//  install is a row in the Downloads queue, watched as it runs.
//

#import "TCDAppDelegate.h"
#import "TCDTheme.h"
#import "TCDAeroBar.h"
#import "TCDStoreView.h"
#import "TCDDownloadsView.h"
#import "TCDPackageDatabase.h"
#import "TCDIndexParser.h"
#import "TCDResolver.h"
#import "TCDInstaller.h"
#import "TCDAuthorizer.h"
#import "TCDSigner.h"

/* A bare NSView with no -drawRect never paints, so the status strip gets one. */
@interface TCDStatusPlate : NSView
@end

@implementation TCDStatusPlate
- (void)drawRect:(NSRect)dirty {
    (void)dirty;
    [[TCDTheme chrome] setFill];
    NSRectFill([self bounds]);
    [[TCDTheme line] setFill];
    NSRectFill(NSMakeRect(0.0, NSMaxY([self bounds]) - 1.0,
                          NSWidth([self bounds]), 1.0));
}
@end

@interface TCDAppDelegate () <TCDAeroBarDelegate, TCDStoreViewDelegate>

@property (nonatomic, strong) TCDAeroBar *bar;
@property (nonatomic, strong) TCDStoreView *storeView;
@property (nonatomic, strong) TCDDownloadsView *downloadsView;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSArray *packages;
@property (nonatomic, strong) TCDSigner *signer;
@property (nonatomic, strong) TCDResolver *resolver;
@property (nonatomic, strong) TCDAuthorizer *authorizer;
@property (nonatomic, strong) TCDInstallSession *runningSession;
@property (nonatomic, strong) NSTimer *sessionPoll;
@property (nonatomic, copy)   NSString *runningTransferIdentifier;
@property (nonatomic, strong) NSPopUpButton *versionPopUp;
@property (nonatomic, strong) TCDPackage *versionPackage;
@property (nonatomic, strong) NSTextField *windowTitleLabel;

@end

@implementation TCDAppDelegate

#pragma mark - lifecycle

- (void)applicationDidFinishLaunching:(NSNotification *)note {
    (void)note;
    self.signer = [[TCDSigner alloc] initWithPolicy:[TCDSigner policyFromDefaults]];
    self.authorizer = [[TCDAuthorizer alloc] init];

    NSError *err = nil;
    if (![[TCDPackageDatabase sharedDatabase] openWithError:&err]) {
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
    (void)note;
    [self.sessionPoll invalidate];
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
    NSRect frame = NSMakeRect(0.0, 0.0, 1040, 680);
    NSUInteger mask = NSTitledWindowMask | NSClosableWindowMask |
                      NSMiniaturizableWindowMask | NSResizableWindowMask;
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                             styleMask:mask
                                               backing:NSBackingStoreBuffered
                                                 defer:NO];
    [self.window setTitle:@"TCD store"];
    [self.window setMinSize:NSMakeSize(900, 560)];
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];

    NSView *content = [self.window contentView];
    CGFloat barH = [TCDTheme barHeight];
    CGFloat statusH = 22.0;
    CGFloat bodyH = NSHeight(frame) - barH - statusH;

    // ---- the one black bar ----
    self.bar = [[TCDAeroBar alloc] initWithFrame:
        NSMakeRect(0.0, NSHeight(frame) - barH, NSWidth(frame), barH)];
    self.bar.delegate = self;
    [content addSubview:self.bar];

    // ---- the split: sidebar + grid, or Downloads full width ----
    self.storeView = [[TCDStoreView alloc] initWithFrame:
        NSMakeRect(0.0, statusH, NSWidth(frame), bodyH)];
    self.storeView.delegate = self;
    [content addSubview:self.storeView];

    self.downloadsView = [[TCDDownloadsView alloc] initWithFrame:
        NSMakeRect(0.0, statusH, NSWidth(frame), bodyH)];
    __weak TCDAppDelegate *weakSelf = self;
    self.downloadsView.onCancelTransfer = ^(NSString *identifier) {
        [weakSelf cancelTransferWithIdentifier:identifier];
    };
    [content addSubview:self.downloadsView];
    [self.downloadsView setHidden:YES];

    // ---- status bar: the plate goes down first, the label on top of it ----
    TCDStatusPlate *status = [[TCDStatusPlate alloc] initWithFrame:
        NSMakeRect(0.0, 0.0, NSWidth(frame), statusH)];
    [status setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
    [content addSubview:status];

    self.statusLabel = [[NSTextField alloc] initWithFrame:
        NSMakeRect(10.0, 4.0, NSWidth(frame) - 20.0, 14.0)];
    [self.statusLabel setBezeled:NO];
    [self.statusLabel setDrawsBackground:NO];
    [self.statusLabel setEditable:NO];
    [self.statusLabel setSelectable:NO];
    [self.statusLabel setFont:[TCDTheme uiFontOfSize:10.5]];
    [[self.statusLabel cell] setTextColor:[TCDTheme inkThree]];
    [content addSubview:self.statusLabel];

    // Autoresizing, not constraints: the idiom a 10.7 target forces, and it
    // survives a resize without a layout pass.
    [self.bar setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
    [self.storeView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self.downloadsView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self.statusLabel setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
    [content setAutoresizesSubviews:YES];
}

#pragma mark - data

- (void)reloadFromDatabase {
    TCDPackageDatabase *db = [TCDPackageDatabase sharedDatabase];
    self.packages = [db allPackages];
    self.resolver = [[TCDResolver alloc] initWithCatalogue:self.packages];

    NSMutableArray *cats = [NSMutableArray array];
    for (TCDPackage *p in self.packages) {
        if (p.section.length && ![cats containsObject:p.section]) [cats addObject:p.section];
    }
    [cats sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];

    NSUInteger sourceCount = [db allSources].count;
    [self.storeView setPackages:self.packages
                     categories:cats
                    sourceCount:sourceCount];

    NSUInteger updates = 0, installed = 0;
    for (TCDPackage *p in self.packages) {
        if (p.hasUpdate) updates++;
        if (p.installed) installed++;
    }
    self.bar.updateAllVisible = updates > 0;
    [self.statusLabel setStringValue:
        [NSString stringWithFormat:@"%lu packages · %lu installed · %lu update%@ · %lu source%@",
         (unsigned long)self.packages.count, (unsigned long)installed,
         (unsigned long)updates, updates == 1 ? @"" : @"s",
         (unsigned long)sourceCount, sourceCount == 1 ? @"" : @"s"]];
}

- (void)refreshAllSources {
    TCDPackageDatabase *db = [TCDPackageDatabase sharedDatabase];
    NSArray *sources = [db allSources];
    if (!sources.count) return;
    [self.statusLabel setStringValue:[NSString stringWithFormat:
        @"Refreshing %lu source%@…", (unsigned long)sources.count,
        sources.count == 1 ? @"" : @"s"]];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (NSDictionary *source in sources) {
            NSURL *url = [NSURL URLWithString:[source objectForKey:@"url"]];
            if (!url) continue;
            NSURLRequest *req = [NSURLRequest requestWithURL:url
                                                 cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                             timeoutInterval:45.0];
            // NSURLSession is 10.9; NSURLConnection is the 10.7 answer.
            [NSURLConnection sendAsynchronousRequest:req
                                              queue:[NSOperationQueue mainQueue]
                                  completionHandler:
                ^(NSURLResponse *r, NSData *d, NSError *e) {
                    (void)r;
                    if (e || !d.length) return;
                    NSArray *parsed = [TCDIndexParser
                        parseIndexData:d
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
                }];
        }
    });
}

#pragma mark - TCDAeroBarDelegate

- (void)aeroBar:(TCDAeroBar *)bar didSelectView:(TCDAeroView)view {
    (void)bar;
    BOOL downloads = (view == TCDAeroViewDownloads);
    [self.storeView setHidden:downloads];
    [self.downloadsView setHidden:!downloads];
}

- (void)aeroBar:(TCDAeroBar *)bar didChangeSearch:(NSString *)query {
    (void)bar;
    // Typing switches back to Store, and the field is the only way into search
    // — there is deliberately no Search card in the panel.
    [self.storeView setHidden:NO];
    [self.downloadsView setHidden:YES];
    [self.bar setActiveView:TCDAeroViewStore];
    [self.storeView applySearch:query];
}

- (void)aeroBarDidGoBack:(TCDAeroBar *)bar {
    (void)bar;
    if ([self.storeView canGoBack]) [self.storeView goBack];
    else [self.storeView applyRoute:TCDSidebarRouteFeatured section:nil];
}

- (void)aeroBarDidRefresh:(TCDAeroBar *)bar {
    (void)bar;
    [self refreshAllSources];
}

- (void)aeroBarDidUpdateAll:(TCDAeroBar *)bar {
    (void)bar;
    NSMutableArray *list = [NSMutableArray array];
    for (TCDPackage *p in self.packages) if (p.hasUpdate) [list addObject:p];
    if (!list.count) return;
    [self startPlan:[self.resolver planForPackages:list]
              title:@"Update All"];
}

#pragma mark - TCDStoreViewDelegate

- (void)storeViewDidSelectRoute:(TCDStoreView *)view
                          route:(TCDSidebarRoute)route
                        section:(NSString *)section {
    (void)view;
    [view applyRoute:route section:section];
}

- (void)storeView:(TCDStoreView *)view didSelectDensity:(TCDIconDensity)density {
    (void)view; (void)density;
}

- (void)storeView:(TCDStoreView *)view didSelectPackage:(TCDPackage *)pkg {
    (void)view;
    [self presentPackageSheet:pkg version:nil];
}

- (void)storeView:(TCDStoreView *)view didTapVersionsForPackage:(TCDPackage *)pkg {
    (void)view;
    [self presentVersionMenuForPackage:pkg];
}

#pragma mark - the version disclosure

/* The blue triangle opens the version menu: every version the source carries,
   each labelled install / update / downgrade / reinstall relative to what is
   actually on disk. */
- (void)presentVersionMenuForPackage:(TCDPackage *)pkg {
    NSAlert *sheet = [[NSAlert alloc] init];
    [sheet setMessageText:[NSString stringWithFormat:@"Other versions of %@", pkg.name]];
    [sheet setInformativeText:
        [NSString stringWithFormat:@"%@ is installed. The source carries %lu version%@.",
         pkg.installed ? [NSString stringWithFormat:@"v%@", pkg.installedVersion]
                       : @"Nothing",
         (unsigned long)pkg.availableVersions.count,
         pkg.availableVersions.count == 1 ? @"" : @"s"]];

    NSPopUpButton *pop = [[NSPopUpButton alloc] initWithFrame:
        NSMakeRect(0.0, 0.0, 280.0, 24.0) pullsDown:NO];
    NSMutableArray *versions = [NSMutableArray array];
    for (NSDictionary *entry in pkg.availableVersions) {
        NSString *version = [entry objectForKey:@"version"];
        if (!version.length) continue;
        TCDVersionRelation rel = [pkg relationToVersion:version];
        NSString *title = [NSString stringWithFormat:@"v%@ — %@", version,
                           [TCDPackage stringForRelation:rel]];
        NSMenuItem *item = [[pop menu] addItemWithTitle:title
                                                  action:NULL
                                           keyEquivalent:@""];
        [item setRepresentedObject:version];
        [item setEnabled:(rel != TCDVersionRelationReinstall)];
        [versions addObject:version];
    }
    [sheet setAccessoryView:pop];
    self.versionPopUp = pop;
    self.versionPackage = pkg;
    [sheet addButtonWithTitle:@"Install This Version"];
    [sheet addButtonWithTitle:@"Details"];

    [sheet beginSheetModalForWindow:self.window
                  completionHandler:^(NSModalResponse response) {
        if (response == NSAlertSecondButtonReturn) {
            [self presentPackageSheet:self.versionPackage version:nil];
            return;
        }
        if (response != NSAlertFirstButtonReturn) return;
        NSString *version = [[[pop selectedItem] representedObject] description];
        if (!version.length) return;
        [self presentPackageSheet:pkg version:version];
    }];
}

#pragma mark - the plan sheet

- (void)presentPackageSheet:(TCDPackage *)pkg version:(NSString *)version {
    TCDInstallPlan *plan = version.length
        ? [self.resolver planForPackage:pkg atVersion:version]
        : [self.resolver planForPackage:pkg];

    if (![plan isValid]) {
        [self presentProblem:
            [NSString stringWithFormat:@"Cannot install %@", pkg.name]
                       detail:plan.failureReason ?: @"A required package is missing."];
        return;
    }

    TCDVersionRelation rel = plan.primaryRelation;
    NSString *verb = [TCDPackage stringForRelation:rel];

    NSAlert *sheet = [[NSAlert alloc] init];
    NSString *headline = plan.packages.count > 1
        ? [NSString stringWithFormat:@"%@ %lu packages", verb,
           (unsigned long)plan.packages.count]
        : [NSString stringWithFormat:@"%@ %@", verb, pkg.name];
    [sheet setMessageText:headline];

    NSMutableString *detail = [NSMutableString string];
    for (TCDPackage *p in plan.packages) {
        NSString *targetVersion = [plan.versionOverrides objectForKey:p.identifier] ?: p.version;
        [detail appendFormat:@"%@ v%@%@\n",
         p.name, targetVersion,
         [plan.primaryIdentifiers containsObject:p.identifier]
            ? @"   (what you asked for)"
            : @"   (needed by the above)"];
    }
    if ([plan.blockingConflicts count]) {
        [detail appendFormat:@"\n%@ in the way:\n",
         [plan.blockingConflicts count] == 1 ? @"A conflict" : @"Conflicts"];
        for (TCDConflict *c in plan.blockingConflicts)
            [detail appendFormat:@"  %@ clashes with %@\n", c.name, c.conflictingWithName];
    }
    if (rel == TCDVersionRelationDowngrade) {
        [detail appendString:
            @"\nThis is a downgrade. The installed version is newer than the "
            @"one you picked, and downgrading can leave an application in a "
            @"state its own author did not intend.\n"];
    }
    if (plan.packages.count > 1) {
        [detail appendString:@"\nOnly the first package is what you asked for; "
                              @"the rest are pulled in as dependencies.\n"];
    }
    if ([plan requiresPrivilege])
        [detail appendString:@"\nA password will be requested, because this plan "
                              @"installs a .pkg.\n"];
    [sheet setInformativeText:detail];

    [sheet addButtonWithTitle:(rel == TCDVersionRelationDowngrade ? @"Downgrade" : verb)];
    [sheet addButtonWithTitle:@"Cancel"];

    [sheet beginSheetModalForWindow:self.window
                  completionHandler:^(NSModalResponse response) {
        if (response != NSAlertFirstButtonReturn) return;
        [self startPlan:plan title:headline];
    }];
}

- (void)presentProblem:(NSString *)headline detail:(NSString *)detail {
    NSAlert *a = [[NSAlert alloc] init];
    [a setMessageText:headline];
    [a setInformativeText:detail ?: @""];
    [a addButtonWithTitle:@"OK"];
    [a beginSheetModalForWindow:self.window completionHandler:nil];
}

#pragma mark - running a plan on the Downloads screen

- (void)startPlan:(TCDInstallPlan *)plan title:(NSString *)title {
    (void)title;
    if (![plan isValid]) {
        [self presentProblem:@"That plan cannot be installed"
                      detail:plan.failureReason ?: @"Something in the plan is missing."];
        return;
    }

    TCDInstaller *installer = [[TCDInstaller alloc] initWithAuthorizer:self.authorizer
                                                               signer:self.signer];
    TCDInstallSession *session = [installer installPlan:plan];

    // The transfer is registered before the view switch, so the queue is
    // already correct the first time it draws.
    TCDTransfer *transfer = [[TCDTransfer alloc] init];
    transfer.session = session;
    self.runningTransferIdentifier = transfer.identifier;
    [self.downloadsView addTransfer:transfer];

    // and the user is taken there to watch it
    self.bar.activeView = TCDAeroViewDownloads;
    [self.storeView setHidden:YES];
    [self.downloadsView setHidden:NO];
    self.bar.downloadCount = [self.downloadsView activeCount];

    self.runningSession = session;
    [self.sessionPoll invalidate];
    self.sessionPoll = [NSTimer scheduledTimerWithTimeInterval:0.05
                                                        target:self
                                                      selector:@selector(pollSession)
                                                      userInfo:transfer
                                                       repeats:YES];
}

- (void)pollSession {
    TCDTransfer *transfer = [self.sessionPoll userInfo];
    TCDInstallSession *session = self.runningSession;
    self.bar.downloadCount = [self.downloadsView activeCount];
    if (!session.finished) return;

    [self.sessionPoll invalidate];
    self.sessionPoll = nil;
    self.runningSession = nil;

    if (session.failureReason) {
        [self downloadsViewDidFinishTransferWithFailure:session.failureReason];
    } else {
        [self.downloadsView removeTransferWithIdentifier:transfer.identifier];
        [self reloadFromDatabase];
    }
    self.runningTransferIdentifier = nil;
    self.bar.downloadCount = [self.downloadsView activeCount];
}

- (void)downloadsViewDidFinishTransferWithFailure:(NSString *)reason {
    NSAlert *a = [[NSAlert alloc] init];
    [a setMessageText:@"Installation failed."];
    [a setInformativeText:reason ?: @"The installer stopped."];
    [a addButtonWithTitle:@"OK"];
    [a beginSheetModalForWindow:self.window completionHandler:nil];
    [self.downloadsView removeTransferWithIdentifier:self.runningTransferIdentifier ?: @""];
}

- (void)cancelTransferWithIdentifier:(NSString *)identifier {
    // Cancellation is keyed to the run that owns the row, not to a global, so
    // two concurrent runs cannot cancel each other.
    if ([identifier isEqualToString:self.runningTransferIdentifier] && self.runningSession) {
        [self.runningSession cancel];
    }
    [self.downloadsView removeTransferWithIdentifier:identifier];
    self.bar.downloadCount = [self.downloadsView activeCount];
    if (!self.runningSession) {
        [self.sessionPoll invalidate];
        self.sessionPoll = nil;
    }
}

@end
