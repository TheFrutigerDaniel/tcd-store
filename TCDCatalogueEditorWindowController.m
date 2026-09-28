// TCDCatalogueEditorWindowController.m
#import "TCDCatalogueEditorWindowController.h"
#import "TCDCatalogueManager.h"
#import "TCDAppItem.h"
#import "TCDAppFormView.h"

static const CGFloat kWindowW    = 800.0;
static const CGFloat kWindowH    = 580.0;
static const CGFloat kListW      = 220.0;
static const CGFloat kToolbarH   =  32.0;   // top of list: +/- buttons
static const CGFloat kBottomBarH =  40.0;   // Save + Done bar below the panes

@interface TCDCatalogueEditorWindowController ()
                        <NSTableViewDataSource,
                         NSTableViewDelegate,
                         TCDAppFormViewDelegate>
@property (strong) NSTableView    *listTable;
@property (strong) NSMutableArray *items;
@property (strong) TCDAppFormView *formView;
@property (strong) NSScrollView   *formScroll;
@property (strong) NSButton       *removeBtn;
@property (strong) NSButton       *saveBtn;
@end

@implementation TCDCatalogueEditorWindowController

+ (instancetype)sharedController
{
    static TCDCatalogueEditorWindowController *s = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{ s = [[self alloc] init]; });
    return s;
}

- (instancetype)init
{
    NSWindow *win = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, kWindowW, kWindowH)
                  styleMask:NSTitledWindowMask | NSClosableWindowMask
                           | NSResizableWindowMask
                    backing:NSBackingStoreBuffered
                      defer:NO];
    win.title              = @"Catalogue Editor";
    win.releasedWhenClosed = NO;
    win.minSize            = NSMakeSize(620, 460);

    self = [super initWithWindow:win];
    if (!self) return nil;

    _items = [[TCDCatalogueManager sharedManager].items mutableCopy];
    [self buildUI];

    // Delegate set here, after buildUI, so self is fully alive
    _formView.delegate = self;

    [[NSNotificationCenter defaultCenter]
        addObserver:self selector:@selector(windowDidBecomeKey:)
               name:NSWindowDidBecomeKeyNotification
             object:self.window];
    return self;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

// Resync if an external import happened while the editor was hidden
- (void)windowDidBecomeKey:(NSNotification *)note
{
    if ([TCDCatalogueManager sharedManager].items.count != _items.count) {
        _items = [[TCDCatalogueManager sharedManager].items mutableCopy];
        [_listTable reloadData];
        [_formView clear];
        _removeBtn.enabled = NO;
        _saveBtn.enabled   = NO;
    }
}

// ── Build UI ──────────────────────────────────────────────────────────────────

- (void)buildUI
{
    NSView *root = self.window.contentView;
    CGFloat W = kWindowW;
    CGFloat H = kWindowH;

    // ── Bottom bar: Save (right-of-list) + Done (far right) ──────────────
    // Sits at the very bottom, full width. Built first so panes sit above it.
    NSView *bottomBar = [[NSView alloc]
        initWithFrame:NSMakeRect(0, 0, W, kBottomBarH)];
    bottomBar.wantsLayer = YES;
    bottomBar.layer.backgroundColor =
        [NSColor colorWithCalibratedWhite:0.92 alpha:1].CGColor;
    bottomBar.autoresizingMask = NSViewWidthSizable;

    // Top separator of the bottom bar
    NSView *barSep = [[NSView alloc] initWithFrame:NSMakeRect(0, kBottomBarH-1, W, 1)];
    barSep.wantsLayer = YES;
    barSep.layer.backgroundColor =
        [NSColor colorWithCalibratedWhite:0.72 alpha:1].CGColor;
    barSep.autoresizingMask = NSViewWidthSizable;
    [bottomBar addSubview:barSep];

    // "Save App" button — prominent, left of centre
    _saveBtn = [[NSButton alloc] initWithFrame:NSMakeRect(kListW + 12, 7, 110, 26)];
    _saveBtn.title      = @"Save App";
    _saveBtn.bezelStyle = NSRoundedBezelStyle;
    _saveBtn.target     = self;
    _saveBtn.action     = @selector(saveApp:);
    _saveBtn.enabled    = YES;
    [bottomBar addSubview:_saveBtn];

    // "Done" button — far right
    NSButton *doneBtn = [[NSButton alloc]
        initWithFrame:NSMakeRect(W - 90, 7, 80, 26)];
    doneBtn.title            = @"Done";
    doneBtn.bezelStyle       = NSRoundedBezelStyle;
    doneBtn.target           = self;
    doneBtn.action           = @selector(close);
    doneBtn.autoresizingMask = NSViewMinXMargin;
    [bottomBar addSubview:doneBtn];

    [root addSubview:bottomBar];

    CGFloat panesH = H - kBottomBarH;

    // ── Left: list toolbar (+ / − buttons) ───────────────────────────────
    NSView *listToolbar = [[NSView alloc]
        initWithFrame:NSMakeRect(0, panesH - kToolbarH, kListW, kToolbarH)];
    listToolbar.wantsLayer = YES;
    listToolbar.layer.backgroundColor =
        [NSColor colorWithCalibratedWhite:0.85 alpha:1].CGColor;
    listToolbar.autoresizingMask = NSViewMinYMargin;

    NSButton *addBtn = [[NSButton alloc] initWithFrame:NSMakeRect(2, 4, 28, 24)];
    addBtn.title = @"+"; addBtn.bezelStyle = NSSmallSquareBezelStyle;
    addBtn.target = self; addBtn.action = @selector(addApp:);
    [listToolbar addSubview:addBtn];

    _removeBtn = [[NSButton alloc] initWithFrame:NSMakeRect(32, 4, 28, 24)];
    _removeBtn.title = @"−"; _removeBtn.bezelStyle = NSSmallSquareBezelStyle;
    _removeBtn.target = self; _removeBtn.action = @selector(removeApp:);
    _removeBtn.enabled = NO;
    [listToolbar addSubview:_removeBtn];

    NSView *toolSep = [[NSView alloc]
        initWithFrame:NSMakeRect(0, 0, kListW, 1)];
    toolSep.wantsLayer = YES;
    toolSep.layer.backgroundColor =
        [NSColor colorWithCalibratedWhite:0.70 alpha:1].CGColor;
    [listToolbar addSubview:toolSep];
    [root addSubview:listToolbar];

    // ── Left: app list scroll view ────────────────────────────────────────
    CGFloat listH = panesH - kToolbarH;
    NSScrollView *listScroll = [[NSScrollView alloc]
        initWithFrame:NSMakeRect(0, kBottomBarH, kListW, listH)];
    listScroll.hasVerticalScroller   = YES;
    listScroll.hasHorizontalScroller = NO;
    listScroll.autohidesScrollers    = YES;
    listScroll.borderType            = NSNoBorder;
    listScroll.autoresizingMask      = NSViewHeightSizable;

    _listTable = [[NSTableView alloc] initWithFrame:listScroll.bounds];
    NSTableColumn *nameCol = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    [nameCol.headerCell setStringValue:@"App"];
    nameCol.width    = kListW - 4;
    nameCol.editable = NO;
    [_listTable addTableColumn:nameCol];
    _listTable.dataSource              = self;
    _listTable.delegate                = self;
    _listTable.allowsEmptySelection    = YES;
    _listTable.allowsMultipleSelection = NO;
    [listScroll setDocumentView:_listTable];
    [root addSubview:listScroll];

    // ── Vertical separator ────────────────────────────────────────────────
    NSView *vsep = [[NSView alloc]
        initWithFrame:NSMakeRect(kListW, kBottomBarH, 1, panesH)];
    vsep.wantsLayer = YES;
    vsep.layer.backgroundColor =
        [NSColor colorWithCalibratedWhite:0.70 alpha:1].CGColor;
    vsep.autoresizingMask = NSViewHeightSizable;
    [root addSubview:vsep];

    // ── Right: form scroll view ───────────────────────────────────────────
    CGFloat formX        = kListW + 1;
    CGFloat formW        = W - formX;
    CGFloat formContentH = 600;   // taller than visible area → scroll

    _formScroll = [[NSScrollView alloc]
        initWithFrame:NSMakeRect(formX, kBottomBarH, formW, panesH)];
    _formScroll.hasVerticalScroller   = YES;
    _formScroll.hasHorizontalScroller = NO;
    _formScroll.autohidesScrollers    = YES;
    _formScroll.borderType            = NSNoBorder;
    _formScroll.autoresizingMask      = NSViewWidthSizable | NSViewHeightSizable;

    _formView = [[TCDAppFormView alloc]
        initWithFrame:NSMakeRect(0, 0, formW, formContentH)];
    // delegate set in init after buildUI returns
    [_formScroll setDocumentView:_formView];
    [root addSubview:_formScroll];
}

// ── Actions ───────────────────────────────────────────────────────────────────

- (void)addApp:(id)sender
{
    [_listTable deselectAll:nil];   // fires tableViewSelectionDidChange → clear
    _removeBtn.enabled = NO;
    // Scroll form to top so Name field is the first thing seen
    [[_formScroll documentView] scrollPoint:
        NSMakePoint(0, NSHeight(_formView.bounds))];
}

- (void)saveApp:(id)sender
{
    // Delegate to the form's own save logic — it validates and calls our delegate
    [_formView triggerSave];
}

- (void)removeApp:(id)sender
{
    NSInteger row = [_listTable selectedRow];
    if (row < 0 || row >= (NSInteger)_items.count) return;

    TCDAppItem *item = _items[(NSUInteger)row];
    NSAlert *alert        = [[NSAlert alloc] init];
    alert.messageText     = [NSString stringWithFormat:@"Remove \"%@\"?", item.name];
    alert.informativeText = @"This cannot be undone.";
    [alert addButtonWithTitle:@"Remove"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] != NSAlertFirstButtonReturn) return;

    [[TCDCatalogueManager sharedManager] removeItem:item];
    [_items removeObjectAtIndex:(NSUInteger)row];
    [_listTable reloadData];
    [_formView clear];
    _removeBtn.enabled = NO;
}

// ── NSTableViewDataSource ─────────────────────────────────────────────────────

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv
{
    return (NSInteger)_items.count;
}

- (id)tableView:(NSTableView *)tv
objectValueForTableColumn:(NSTableColumn *)col
            row:(NSInteger)row
{
    TCDAppItem *item = _items[(NSUInteger)row];
    return [NSString stringWithFormat:@"%@  —  %@",
            item.name ?: @"", item.developer ?: @""];
}

// ── NSTableViewDelegate ───────────────────────────────────────────────────────

- (void)tableViewSelectionDidChange:(NSNotification *)note
{
    NSInteger row = [_listTable selectedRow];
    if (row < 0) {
        [_formView clear];
        _removeBtn.enabled = NO;
        return;
    }
    _removeBtn.enabled = YES;
    [_formView loadItem:_items[(NSUInteger)row]];
}

// ── TCDAppFormViewDelegate ────────────────────────────────────────────────────

- (void)formView:(TCDAppFormView *)sender
     didSaveItem:(TCDAppItem *)newItem
   replacingItem:(TCDAppItem *)oldItem
{
    NSLog(@"[Editor] didSaveItem: %@ replacing: %@", newItem.name, oldItem.name);

    if (oldItem) {
        [[TCDCatalogueManager sharedManager] replaceItem:oldItem withItem:newItem];
        NSUInteger idx = [_items indexOfObject:oldItem];
        if (idx != NSNotFound)
            [_items replaceObjectAtIndex:idx withObject:newItem];
    } else {
        [[TCDCatalogueManager sharedManager] addItem:newItem];
        [_items addObject:newItem];
    }

    [_listTable reloadData];

    NSUInteger newIdx = [_items indexOfObject:newItem];
    if (newIdx != NSNotFound) {
        [_listTable selectRowIndexes:[NSIndexSet indexSetWithIndex:newIdx]
                byExtendingSelection:NO];
    }
    
    NSLog(@"[Editor] _items count now: %lu", (unsigned long)_items.count);
}

@end
