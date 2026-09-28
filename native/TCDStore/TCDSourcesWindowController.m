//
//  TCDSourcesWindowController.m
//  TCD Store
//

#import "TCDSourcesWindowController.h"
#import "TCDStoreFeed.h"
#import "TCDDemoSource.h"
#import "TCDBackgroundView.h"
#import "TCDCatalogueManager.h"   // TCDCatalogueDidChangeNotification

static const CGFloat kWinW     = 760.0;
static const CGFloat kWinH     = 420.0;
static const CGFloat kToolbarH = 40.0;

static NSString *const kColNameID = @"name";
static NSString *const kColURLID  = @"url";
static NSString *const kColPkgsID = @"packages";
static NSString *const kColWhenID = @"lastSync";
static NSString *const kColStatID = @"status";

@interface TCDSourcesWindowController () <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, strong) NSTableView *table;
@property (nonatomic, strong) NSArray *sources;
@property (nonatomic, strong) NSButton *refreshButton;
@property (nonatomic, strong) NSButton *addButton;
@property (nonatomic, strong) NSButton *removeButton;
@property (nonatomic, strong) NSButton *demoButton;
@end

@implementation TCDSourcesWindowController

+ (TCDSourcesWindowController *)sharedController {
    static TCDSourcesWindowController *s = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{ s = [[self alloc] init]; });
    return s;
}

- (id)init {
    NSWindow *win = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, kWinW, kWinH)
                  styleMask:NSTitledWindowMask | NSClosableWindowMask
                             | NSResizableWindowMask
                    backing:NSBackingStoreBuffered
                      defer:NO];
    win.title              = @"Sources";
    win.releasedWhenClosed = NO;
    win.minSize            = NSMakeSize(620, 320);

    self = [super initWithWindow:win];
    if (!self) return nil;

    [self buildUI];
    [self reload];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(catalogueChanged:)
                                                 name:TCDCatalogueDidChangeNotification
                                               object:nil];
    return self;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

#pragma mark - building

- (void)buildUI {
    NSView *root = [self.window contentView];
    CGFloat barTop = NSHeight(root.bounds) - kToolbarH;

    // ---- toolbar ----
    TCDBackgroundView *bar = [TCDBackgroundView
        viewWithFrame:NSMakeRect(0, barTop, NSWidth(root.bounds), kToolbarH)
                 color:[NSColor colorWithCalibratedWhite:0.92 alpha:1.0]];
    [bar setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
    [root addSubview:bar];

    self.refreshButton = [self buttonWithTitle:@"Refresh"
                                       action:@selector(refreshClicked:)
                                         width:80.0];
    self.addButton     = [self buttonWithTitle:@"Add…"
                                       action:@selector(addClicked:)
                                         width:70.0];
    self.removeButton  = [self buttonWithTitle:@"Remove"
                                       action:@selector(removeClicked:)
                                         width:80.0];
    self.demoButton    = [self buttonWithTitle:@"Add demo source"
                                       action:@selector(addDemoClicked:)
                                         width:130.0];

    CGFloat y = (kToolbarH - 24.0) / 2.0;
    CGFloat x = NSWidth(root.bounds) - 12.0;
    x -= 130.0;  self.demoButton.frame    = NSMakeRect(x, y, 130.0, 24.0);
    x -= 8.0;  x -= 80.0;  self.removeButton.frame  = NSMakeRect(x, y, 80.0, 24.0);
    x -= 8.0;  x -= 70.0;  self.addButton.frame     = NSMakeRect(x, y, 70.0, 24.0);
    x -= 8.0;  x -= 80.0;  self.refreshButton.frame = NSMakeRect(x, y, 80.0, 24.0);
    for (NSButton *b in @[self.refreshButton, self.addButton,
                          self.removeButton, self.demoButton])
        [bar addSubview:b];

    // ---- the list ----
    NSScrollView *scroll = [[NSScrollView alloc]
        initWithFrame:NSMakeRect(0, 0, NSWidth(root.bounds), barTop)];
    [scroll setHasVerticalScroller:YES];
    [scroll setAutohidesScrollers:YES];
    [scroll setBorderType:NSNoBorder];
    [scroll setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [root addSubview:scroll];

    self.table = [[NSTableView alloc] initWithFrame:scroll.bounds];
    [self.table setDataSource:self];
    [self.table setDelegate:self];
    [self.table setUsesAlternatingRowBackgroundColors:YES];
    [self.table setRowHeight:20.0];
    [self.table setColumnAutoresizingStyle:NSTableViewUniformColumnAutoresizingStyle];

    [self addColumn:kColNameID title:@"Name"      width:190.0];
    [self addColumn:kColURLID  title:@"URL"       width:210.0];
    [self addColumn:kColPkgsID title:@"Packages"  width:80.0];
    [self addColumn:kColWhenID title:@"Last sync" width:150.0];
    [self addColumn:kColStatID title:@"Status"    width:120.0];

    [scroll setDocumentView:self.table];
}

- (void)addColumn:(NSString *)identifier title:(NSString *)title width:(CGFloat)width {
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:identifier];
    [[column headerCell] setStringValue:title];
    [column setWidth:width];
    [column setMinWidth:60.0];
    [self.table addTableColumn:column];
}

- (NSButton *)buttonWithTitle:(NSString *)title action:(SEL)action width:(CGFloat)width {
    NSButton *b = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, width, 24.0)];
    [b setTitle:title];
    [b setBezelStyle:NSRoundedBezelStyle];
    [b setTarget:self];
    [b setAction:action];
    return b;
}

#pragma mark - data

- (void)reload {
    self.sources = [[TCDStoreFeed sharedFeed] sources];
    [self.table reloadData];
    [self updateButtonState];
}

- (void)catalogueChanged:(NSNotification *)note {
    (void)note;
    [self reload];
}

- (NSDictionary *)sourceAtRow:(NSInteger)row {
    if (row < 0 || (NSUInteger)row >= self.sources.count) return nil;
    return [self.sources objectAtIndex:(NSUInteger)row];
}

- (NSString *)identifierForRow:(NSInteger)row {
    return [[self sourceAtRow:row] objectForKey:@"identifier"];
}

- (BOOL)demoSourceIsRegistered {
    NSString *want = [TCDDemoSource identifier];
    for (NSDictionary *s in self.sources) {
        if ([[s objectForKey:@"identifier"] isEqualToString:want]) return YES;
    }
    return NO;
}

- (void)updateButtonState {
    BOOL hasSelection = [self identifierForRow:[self.table selectedRow]] != nil;
    [self.refreshButton setEnabled:hasSelection];
    [self.removeButton  setEnabled:hasSelection];
    // Only offered when it would do something: the index has to be in the
    // bundle, and the source must not already be in the list.
    [self.demoButton setEnabled:[TCDDemoSource isAvailable]
                             && ![self demoSourceIsRegistered]];
}

#pragma mark - NSTableViewDataSource / Delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    (void)tableView;
    return (NSInteger)self.sources.count;
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row {
    NSTextField *field = [tableView makeViewWithIdentifier:tableColumn.identifier
                                                    owner:self];
    if (!field) {
        field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 100, 18)];
        [field setEditable:NO];
        [field setSelectable:YES];
        [field setBezeled:NO];
        [field setDrawsBackground:NO];
        [field setIdentifier:tableColumn.identifier];
    }

    NSDictionary *source = [self sourceAtRow:row];
    if (!source) { [field setStringValue:@""]; return field; }

    NSString *identifier = [source objectForKey:@"identifier"];
    NSString *column = tableColumn.identifier;
    NSString *text = @"";

    if ([column isEqualToString:kColNameID]) {
        text = [source objectForKey:@"name"] ?: @"";
    } else if ([column isEqualToString:kColURLID]) {
        text = [source objectForKey:@"url"] ?: @"";
    } else if ([column isEqualToString:kColPkgsID]) {
        text = [NSString stringWithFormat:@"%lu", (unsigned long)
                   [[TCDStoreFeed sharedFeed] packageCountForSourceIdentifier:identifier]];
    } else if ([column isEqualToString:kColWhenID]) {
        text = [self formattedSyncDate:[source objectForKey:@"lastSync"]];
    } else if ([column isEqualToString:kColStatID]) {
        NSInteger status = [[source objectForKey:@"lastStatus"] integerValue];
        if (status == 1) {
            text = @"ok";
        } else if (status == 2) {
            text = [source objectForKey:@"lastError"] ?: @"failed";
        } else {
            text = @"not synced";
        }
    }

    [field setStringValue:text];
    // A URL or a failure reason can be long; the tooltip carries the whole
    // thing rather than letting the column widen past the layout.
    [field setToolTip:[text length] > 24 ? text : @""];
    return field;
}

- (NSString *)formattedSyncDate:(id)value {
    double when = [value doubleValue];
    if (when <= 0.0) return @"never";
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    [f setDateFormat:@"yyyy-MM-dd HH:mm"];
    return [f stringFromDate:[NSDate dateWithTimeIntervalSince1970:when]];
}

- (void)tableViewSelectionDidChange:(NSNotification *)note {
    (void)note;
    [self updateButtonState];
}

#pragma mark - actions

- (void)refreshClicked:(id)sender {
    (void)sender;
    NSString *identifier = [self identifierForRow:[self.table selectedRow]];
    if (!identifier) return;
    [self setBusy:YES];
    BOOL ok = [[TCDStoreFeed sharedFeed] refreshSourceWithIdentifier:identifier];
    [self setBusy:NO];
    [self reload];
    if (!ok) [self reportFailureForSource:identifier];
}

- (void)addClicked:(id)sender {
    (void)sender;

    NSTextField *nameField = [[NSTextField alloc] initWithFrame:NSMakeRect(64, 30, 260, 20)];
    NSTextField *urlField  = [[NSTextField alloc] initWithFrame:NSMakeRect(64, 8, 260, 20)];

    NSView *form = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 330, 56)];
    [form addSubview:[self labelWithTitle:@"Name:" frame:NSMakeRect(0, 30, 60, 16)]];
    [form addSubview:nameField];
    [form addSubview:[self labelWithTitle:@"URL:"  frame:NSMakeRect(0, 8, 60, 16)]];
    [form addSubview:urlField];

    NSAlert *sheet = [[NSAlert alloc] init];
    [sheet setMessageText:@"Add a source"];
    [sheet setInformativeText:@"A Packages-format index. http, https and file URLs."];
    [sheet addButtonWithTitle:@"Add"];
    [sheet addButtonWithTitle:@"Cancel"];
    [sheet setAccessoryView:form];

    if ([sheet runModal] != NSAlertFirstButtonReturn) return;

    if (![[TCDStoreFeed sharedFeed] addSourceWithName:[nameField stringValue]
                                                   url:[urlField stringValue]]) {
        [self alertWithHeading:@"Could not add that source"
                       detail:@"Check the URL. It has to be an http, https or file URL, and it must not already be in the list."];
    }
    [self reload];
}

- (NSTextField *)labelWithTitle:(NSString *)title frame:(NSRect)frame {
    NSTextField *l = [[NSTextField alloc] initWithFrame:frame];
    [l setStringValue:title];
    [l setBezeled:NO];
    [l setDrawsBackground:NO];
    [l setEditable:NO];
    [l setSelectable:NO];
    return l;
}

- (void)addDemoClicked:(id)sender {
    (void)sender;
    if (![TCDDemoSource isAvailable]) {
        [self alertWithHeading:@"The demo source is not available"
                       detail:@"demo-index.txt is not in the application bundle."];
        return;
    }
    [TCDDemoSource register];
    [[TCDStoreFeed sharedFeed] refreshSourceWithIdentifier:[TCDDemoSource identifier]];
    [self reload];
}

- (void)removeClicked:(id)sender {
    (void)sender;
    NSDictionary *source = [self sourceAtRow:[self.table selectedRow]];
    NSString *identifier = [source objectForKey:@"identifier"];
    if (!identifier) return;

    NSAlert *confirm = [[NSAlert alloc] init];
    [confirm setMessageText:[NSString stringWithFormat:@"Remove “%@”?",
                             [source objectForKey:@"name"] ?: identifier]];
    [confirm setInformativeText:@"Its packages leave the store too. Anything already installed is left alone."];
    [confirm addButtonWithTitle:@"Remove"];
    [confirm addButtonWithTitle:@"Cancel"];
    if ([confirm runModal] != NSAlertFirstButtonReturn) return;

    [[TCDStoreFeed sharedFeed] removeSourceWithIdentifier:identifier];
    [self reload];
}

- (void)setBusy:(BOOL)busy {
    for (NSButton *b in @[self.refreshButton, self.addButton,
                          self.removeButton, self.demoButton])
        [b setEnabled:!busy];
}

- (void)reportFailureForSource:(NSString *)identifier {
    for (NSDictionary *s in [[TCDStoreFeed sharedFeed] sources]) {
        if (![[s objectForKey:@"identifier"] isEqualToString:identifier]) continue;
        if ([[s objectForKey:@"lastStatus"] integerValue] != 2) return;
        [self alertWithHeading:@"That refresh did not work"
                       detail:[s objectForKey:@"lastError"] ?: @"unknown error"];
        return;
    }
}

- (void)alertWithHeading:(NSString *)heading detail:(NSString *)detail {
    NSAlert *a = [[NSAlert alloc] init];
    [a setMessageText:heading];
    [a setInformativeText:detail ?: @""];
    [a addButtonWithTitle:@"OK"];
    [a runModal];
}

@end
