// TCDHeaderView.m
#import "TCDHeaderView.h"

NSString * const TCDGridColumnsChangedNotification = @"TCDGridColumnsChangedNotification";

#define kGridTag3 3
#define kGridTag4 4
#define kGridTag5 5

@interface TCDHeaderView ()
@property (strong) NSPopUpButton *menuButton;
@end

@implementation TCDHeaderView

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;

    // ── Title ─────────────────────────────────────────────────────────────
    NSTextField *title = [[NSTextField alloc]
        initWithFrame:NSMakeRect(16, 30, 300, 28)];
    title.stringValue     = @"TCD store";
    title.editable        = NO;
    title.selectable      = NO;
    title.bordered        = NO;
    title.drawsBackground = NO;
    title.textColor       = [NSColor whiteColor];
    title.font            = [NSFont boldSystemFontOfSize:22];
    title.autoresizingMask = NSViewMaxXMargin | NSViewMinYMargin;
    [self addSubview:title];

    // ── Version label ─────────────────────────────────────────────────────
    NSTextField *version = [[NSTextField alloc]
        initWithFrame:NSMakeRect(18, 16, 200, 14)];
    version.stringValue     = @"Alpha 1.0.1";
    version.editable        = NO;
    version.selectable      = NO;
    version.bordered        = NO;
    version.drawsBackground = NO;
    version.textColor       = [NSColor colorWithCalibratedWhite:0.60 alpha:1];
    version.font            = [NSFont systemFontOfSize:10];
    version.autoresizingMask = NSViewMaxXMargin | NSViewMinYMargin;
    [self addSubview:version];

    // ── Grid size popup (gear icon, right side) ───────────────────────────
    _menuButton = [[NSPopUpButton alloc]
        initWithFrame:NSMakeRect(NSWidth(frame) - 36, 22, 26, 26)
            pullsDown:YES];
    _menuButton.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
    _menuButton.bordered         = NO;
    _menuButton.bezelStyle       = NSTexturedRoundedBezelStyle;

    // First item = button face (pull-down convention)
    [_menuButton addItemWithTitle:@""];
    [[_menuButton itemAtIndex:0]
        setImage:[NSImage imageNamed:NSImageNameActionTemplate]];

    NSMenu *menu = _menuButton.menu;

    NSMenuItem *header = [[NSMenuItem alloc]
        initWithTitle:@"Grid Size" action:nil keyEquivalent:@""];
    header.enabled = NO;
    [menu addItem:header];

    for (NSInteger n = 3; n <= 5; n++) {
        NSMenuItem *item = [[NSMenuItem alloc]
            initWithTitle:[NSString stringWithFormat:@"%ld per row", (long)n]
                   action:@selector(setGridColumns:)
            keyEquivalent:@""];
        item.target = self;
        item.tag    = n;
        item.state  = (n == 5) ? NSOnState : NSOffState;
        [menu addItem:item];
    }

    [self addSubview:_menuButton];
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSGradient *g = [[NSGradient alloc]
        initWithStartingColor:[NSColor colorWithCalibratedWhite:0.13 alpha:1]
               endingColor:  [NSColor colorWithCalibratedWhite:0.22 alpha:1]];
    [g drawInRect:self.bounds angle:270];
    [[NSColor colorWithCalibratedWhite:0.08 alpha:1] setFill];
    NSRectFill(NSMakeRect(0, 0, NSWidth(self.bounds), 1));
}

- (void)setGridColumns:(NSMenuItem *)sender
{
    // Update checkmarks
    for (NSMenuItem *item in _menuButton.menu.itemArray) {
        if (item.tag >= kGridTag3 && item.tag <= kGridTag5)
            item.state = (item.tag == sender.tag) ? NSOnState : NSOffState;
    }
    [[NSNotificationCenter defaultCenter]
        postNotificationName:TCDGridColumnsChangedNotification
                      object:[NSNumber numberWithInteger:sender.tag]];
}

@end
