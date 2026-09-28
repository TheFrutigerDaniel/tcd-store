// TCDAppFormView.m
#import "TCDAppFormView.h"
#import "TCDAppItem.h"
#import "TCDCatalogueManager.h"
#import "TCDIconDropView.h"

static NSArray *kBuiltInCategories(void) {
    return @[@"Browsers",@"Developer",@"Emulators",@"Productivity",
             @"Social",@"Utilities",@"Other"];
}

@interface TCDAppFormView () <TCDIconDropViewDelegate>
@property (strong) NSTextField    *nameField;
@property (strong) NSTextField    *developerField;
@property (strong) NSTextField    *urlField;
@property (strong) NSPopUpButton  *categoryPopup;
@property (strong) NSColorWell    *colorWell;
@property (strong) NSTableView    *versionsTable;
@property (strong) NSMutableArray *versions;
@property (strong) TCDIconDropView *iconDropView;
@property (strong) TCDAppItem     *originalItem;
@end

@implementation TCDAppFormView

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _versions = [NSMutableArray array];
    [self buildSubviews];
    return self;
}

- (void)buildSubviews
{
    CGFloat W = NSWidth(self.bounds);
    CGFloat y = NSHeight(self.bounds) - 10;

    // App Info section
    y -= 20; [self addSubview:[self sectionLabel:@"App Info" y:y]];

    y -= 26; [self addSubview:[self label:@"Name" y:y]];
    _nameField = [self field:NSMakeRect(80, y, W-90, 22)];
    [self addSubview:_nameField];

    y -= 26; [self addSubview:[self label:@"Developer" y:y]];
    _developerField = [self field:NSMakeRect(80, y, W-90, 22)];
    [self addSubview:_developerField];

    y -= 26; [self addSubview:[self label:@"Category" y:y]];
    _categoryPopup = [[NSPopUpButton alloc]
        initWithFrame:NSMakeRect(80, y, W-90, 22) pullsDown:NO];
    [_categoryPopup addItemsWithTitles:kBuiltInCategories()];
    [self addSubview:_categoryPopup];

    y -= 26; [self addSubview:[self label:@"URL" y:y]];
    _urlField = [self field:NSMakeRect(80, y, W-90, 22)];
    ((NSTextFieldCell *)_urlField.cell).placeholderString = @"https://…";
    [self addSubview:_urlField];

    y -= 26; [self addSubview:[self label:@"Colour" y:y]];
    _colorWell = [[NSColorWell alloc] initWithFrame:NSMakeRect(80, y, 44, 22)];
    _colorWell.color = [NSColor colorWithCalibratedRed:0.4 green:0.4 blue:0.7 alpha:1];
    [self addSubview:_colorWell];

    // Icon section
    y -= 30; [self addSubview:[self sectionLabel:@"Icon" y:y]];
    y -= 100;
    _iconDropView = [[TCDIconDropView alloc]
        initWithFrame:NSMakeRect(80, y, 80, 108)];
    _iconDropView.delegate = self;
    [self addSubview:_iconDropView];

    // Versions section
    y -= 14; [self addSubview:[self sectionLabel:@"Versions" y:y]];
    y -= 90;

    NSScrollView *scroll = [[NSScrollView alloc]
        initWithFrame:NSMakeRect(80, y, W-90, 88)];
    scroll.borderType          = NSBezelBorder;
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers  = YES;

    _versionsTable = [[NSTableView alloc] initWithFrame:scroll.bounds];
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"version"];
    [col.headerCell setStringValue:@"Version"];
    col.width    = W - 90 - 4;
    col.editable = NO;   // editing done via alert sheet, not inline
    [_versionsTable addTableColumn:col];
    _versionsTable.dataSource              = self;
    _versionsTable.delegate                = self;
    _versionsTable.allowsEmptySelection    = YES;
    _versionsTable.allowsMultipleSelection = NO;
    // Keep the header view — removing it breaks editColumn: on 10.7
    [scroll setDocumentView:_versionsTable];
    [self addSubview:scroll];

    // Version +/− buttons
    CGFloat btnY = y - 28;
    NSButton *addV = [[NSButton alloc] initWithFrame:NSMakeRect(80, btnY, 30, 22)];
    addV.title = @"+"; addV.bezelStyle = NSSmallSquareBezelStyle;
    addV.target = self; addV.action = @selector(addVersion:);
    [self addSubview:addV];

    NSButton *delV = [[NSButton alloc] initWithFrame:NSMakeRect(112, btnY, 30, 22)];
    delV.title = @"−"; delV.bezelStyle = NSSmallSquareBezelStyle;
    delV.target = self; delV.action = @selector(removeVersion:);
    [self addSubview:delV];

    // Save button
    NSButton *save = [[NSButton alloc] initWithFrame:NSMakeRect(W-90, 10, 80, 26)];
    save.title = @"Save"; save.bezelStyle = NSRoundedBezelStyle;
    save.target = self; save.action = @selector(savePressed:);
    [self addSubview:save];
}

// ── Public ────────────────────────────────────────────────────────────────────

- (void)loadItem:(TCDAppItem *)item
{
    _originalItem               = item;
    _nameField.stringValue      = item.name        ?: @"";
    _developerField.stringValue = item.developer   ?: @"";
    _urlField.stringValue       = item.downloadURL ?: @"";

    NSString *cat = item.category ?: @"Other";
    if ([_categoryPopup indexOfItemWithTitle:cat] == -1)
        [_categoryPopup addItemWithTitle:cat];
    [_categoryPopup selectItemWithTitle:cat];

    if (item.accentColor) _colorWell.color = item.accentColor;

    if (item.iconName.length) [_iconDropView loadIconNamed:item.iconName];
    else                       [_iconDropView clear];

    _versions = [item.versions mutableCopy] ?: [NSMutableArray array];
    [_versionsTable reloadData];
}

- (void)clear
{
    _originalItem               = nil;
    _nameField.stringValue      = @"";
    _developerField.stringValue = @"";
    _urlField.stringValue       = @"";
    [_categoryPopup selectItemAtIndex:0];
    _colorWell.color = [NSColor colorWithCalibratedRed:0.4 green:0.4 blue:0.7 alpha:1];
    [_iconDropView clear];
    _versions = [NSMutableArray array];
    [_versionsTable reloadData];
}

// ── Version actions (alert-based input — reliable on all 10.7-10.9) ──────────

- (void)addVersion:(id)sender
{
    // Use an NSAlert with an accessory text field — works on all target OS versions
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText     = @"Add Version";
    alert.informativeText = @"Enter a version string (e.g. v1.0):";
    [alert addButtonWithTitle:@"Add"];
    [alert addButtonWithTitle:@"Cancel"];

    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.stringValue = @"v1.0";
    [alert setAccessoryView:input];
    [alert.window makeFirstResponder:input];

    if ([alert runModal] != NSAlertFirstButtonReturn) return;

    NSString *v = [input.stringValue
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (!v.length) return;

    [_versions addObject:v];
    [_versionsTable reloadData];
    NSUInteger row = _versions.count - 1;
    [_versionsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
                byExtendingSelection:NO];
    [_versionsTable scrollRowToVisible:(NSInteger)row];
}

- (void)removeVersion:(id)sender
{
    NSInteger row = [_versionsTable selectedRow];
    if (row < 0 || row >= (NSInteger)_versions.count) return;
    [_versions removeObjectAtIndex:(NSUInteger)row];
    [_versionsTable reloadData];
}

// ── Save ──────────────────────────────────────────────────────────────────────

- (void)triggerSave
{
    [self savePressed:self];
}

- (void)savePressed:(id)sender
{
    NSString *name = [_nameField.stringValue
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (!name.length) {
        NSAlert *a = [[NSAlert alloc] init];
        a.messageText = @"Name is required.";
        [a runModal]; return;
    }
    if (!_versions.count) {
        NSAlert *a = [[NSAlert alloc] init];
        a.messageText = @"Add at least one version.";
        [a runModal]; return;
    }

    TCDAppItem *item = [TCDAppItem
        itemWithName:name
           developer:[_developerField.stringValue
                         stringByTrimmingCharactersInSet:
                             [NSCharacterSet whitespaceCharacterSet]]
            category:[_categoryPopup titleOfSelectedItem] ?: @"Other"
         accentColor:_colorWell.color
            versions:[_versions copy]
         downloadURL:[_urlField.stringValue
                         stringByTrimmingCharactersInSet:
                             [NSCharacterSet whitespaceCharacterSet]]];
    item.iconName = _iconDropView.currentFilename ?: @"";

    if ([_delegate respondsToSelector:
         @selector(formView:didSaveItem:replacingItem:)])
        [_delegate formView:self didSaveItem:item replacingItem:_originalItem];
}

// ── TCDIconDropViewDelegate ───────────────────────────────────────────────────

- (void)iconDropView:(id)sender didInstallIconNamed:(NSString *)filename {}

// ── NSTableViewDataSource ─────────────────────────────────────────────────────

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv
{
    return (NSInteger)_versions.count;
}

- (id)tableView:(NSTableView *)tv
objectValueForTableColumn:(NSTableColumn *)col
            row:(NSInteger)row
{
    return _versions[(NSUInteger)row];
}

- (void)tableView:(NSTableView *)tv setObjectValue:(id)value
   forTableColumn:(NSTableColumn *)col row:(NSInteger)row
{
    NSString *s = [value stringByTrimmingCharactersInSet:
                   [NSCharacterSet whitespaceCharacterSet]];
    if (s.length) _versions[(NSUInteger)row] = s;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

- (NSTextField *)label:(NSString *)text y:(CGFloat)y
{
    NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(8, y, 70, 20)];
    tf.stringValue = text; tf.alignment = NSRightTextAlignment;
    tf.editable = tf.bordered = tf.drawsBackground = NO; tf.selectable = NO;
    tf.font = [NSFont systemFontOfSize:11];
    tf.textColor = [NSColor darkGrayColor];
    return tf;
}

- (NSTextField *)sectionLabel:(NSString *)text y:(CGFloat)y
{
    NSTextField *tf = [[NSTextField alloc]
        initWithFrame:NSMakeRect(8, y, NSWidth(self.bounds)-16, 18)];
    tf.stringValue = text;
    tf.editable = tf.bordered = tf.drawsBackground = NO; tf.selectable = NO;
    tf.font = [NSFont boldSystemFontOfSize:11];
    tf.textColor = [NSColor colorWithCalibratedWhite:0.3 alpha:1];
    return tf;
}

- (NSTextField *)field:(NSRect)frame
{
    NSTextField *tf = [[NSTextField alloc] initWithFrame:frame];
    tf.editable = YES; tf.bordered = YES; tf.drawsBackground = YES;
    tf.font = [NSFont systemFontOfSize:12];
    return tf;
}

@end
