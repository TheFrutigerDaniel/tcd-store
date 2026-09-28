// TCDDownloadRowView.m
#import "TCDDownloadRowView.h"
#import "TCDAppItem.h"
#import "TCDDownloadManager.h"
#import "TCDSettingsWindowController.h"

static const CGFloat kRowH       = 60.0;
static const CGFloat kBlobSize   = 36.0;
static const CGFloat kBlobPad    = 10.0;
static const CGFloat kBlobCorner =  7.0;

@interface TCDDownloadRowView ()
@property (strong) TCDAppItem          *item;
@property (strong) NSTextField         *nameLabel;
@property (strong) NSTextField         *statusLabel;
@property (strong) NSProgressIndicator *bar;
@property (strong) NSButton            *showButton;
@property (strong) NSButton            *cancelButton;
@property (copy)   NSString            *savedPath;
@end

@implementation TCDDownloadRowView

- (instancetype)initWithItem:(TCDAppItem *)item
{
    self = [super initWithFrame:NSMakeRect(0, 0, 400, kRowH)];
    if (!self) return nil;
    _item = item;
    [self buildSubviews];

    [[NSNotificationCenter defaultCenter]
        addObserver:self selector:@selector(handleProgress:)
               name:TCDDownloadProgressNotification object:_item];
    [[NSNotificationCenter defaultCenter]
        addObserver:self selector:@selector(handleFinished:)
               name:TCDDownloadFinishedNotification object:_item];
    [[NSNotificationCenter defaultCenter]
        addObserver:self selector:@selector(handleFailed:)
               name:TCDDownloadFailedNotification object:_item];
    [[NSNotificationCenter defaultCenter]
        addObserver:self selector:@selector(handleCancelled:)
               name:TCDDownloadCancelledNotification object:_item];
    return self;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)buildSubviews
{
    CGFloat W     = NSWidth(self.bounds);
    CGFloat textX = kBlobPad + kBlobSize + kBlobPad;
    // Reserve right margin: cancel(50) + show(86) + status(46) + gaps
    CGFloat rightW = 50 + 4 + 86 + 4 + 46 + kBlobPad;
    CGFloat textW  = W - textX - rightW;

    // App name
    _nameLabel = [self tf:NSMakeRect(textX, 36, W - textX - kBlobPad, 16)
                     font:[NSFont boldSystemFontOfSize:12]
                    color:[NSColor blackColor]];
    _nameLabel.stringValue = [NSString stringWithFormat:@"%@  %@",
                              _item.name, _item.selectedVersion ?: @""];
    [self addSubview:_nameLabel];

    // Progress bar
    _bar = [[NSProgressIndicator alloc]
            initWithFrame:NSMakeRect(textX, 18, textW, 12)];
    _bar.style = NSProgressIndicatorBarStyle;
    _bar.indeterminate = NO;
    _bar.minValue = 0.0; _bar.maxValue = 1.0; _bar.doubleValue = 0.0;
    [self addSubview:_bar];

    // Status label
    CGFloat statusX = textX + textW + 4;
    _statusLabel = [self tf:NSMakeRect(statusX, 16, 46, 16)
                       font:[NSFont userFixedPitchFontOfSize:10]
                      color:[NSColor darkGrayColor]];
    _statusLabel.alignment = NSRightTextAlignment;
    [self addSubview:_statusLabel];

    // "Cancel" button — visible while downloading
    CGFloat cancelX = statusX + 46 + 4;
    _cancelButton = [[NSButton alloc]
        initWithFrame:NSMakeRect(cancelX, 14, 50, 20)];
    _cancelButton.title      = @"Cancel";
    _cancelButton.bezelStyle = NSInlineBezelStyle;
    _cancelButton.font       = [NSFont systemFontOfSize:10];
    _cancelButton.target     = self;
    _cancelButton.action     = @selector(cancelPressed:);
    [self addSubview:_cancelButton];

    // "Show in Folder" button — visible when done
    _showButton = [[NSButton alloc]
        initWithFrame:NSMakeRect(cancelX, 14, 86, 20)];
    _showButton.title      = @"Show in Folder";
    _showButton.bezelStyle = NSInlineBezelStyle;
    _showButton.font       = [NSFont systemFontOfSize:10];
    _showButton.target     = self;
    _showButton.action     = @selector(showInFolder:);
    _showButton.hidden     = YES;
    [self addSubview:_showButton];

    [self updateProgress];
}

- (void)updateProgress
{
    double p = _item.downloadProgress;
    [_bar setDoubleValue:p];

    switch (_item.downloadState) {
        case TCDDownloadStateDone:
            _statusLabel.stringValue = @"Done";
            _statusLabel.textColor   =
                [NSColor colorWithCalibratedRed:0.1 green:0.6 blue:0.1 alpha:1];
            _bar.hidden          = YES;
            _cancelButton.hidden = YES;
            _showButton.hidden   = NO;
            break;
        case TCDDownloadStateFailed:
            _statusLabel.stringValue = @"Failed";
            _statusLabel.textColor   =
                [NSColor colorWithCalibratedRed:0.8 green:0.1 blue:0.1 alpha:1];
            [_bar setDoubleValue:0.0];
            _cancelButton.hidden = YES;
            _showButton.hidden   = YES;
            break;
        case TCDDownloadStateIdle: // cancelled resets to idle
            _statusLabel.stringValue = @"Cancelled";
            _statusLabel.textColor   = [NSColor grayColor];
            [_bar setDoubleValue:0.0];
            _cancelButton.hidden = YES;
            _showButton.hidden   = YES;
            break;
        default: // Downloading
            _statusLabel.stringValue =
                [NSString stringWithFormat:@"%d%%", (int)(p * 100)];
            _statusLabel.textColor   = [NSColor darkGrayColor];
            _cancelButton.hidden     = NO;
            _showButton.hidden       = YES;
            break;
    }
}

// ── Notification handlers ─────────────────────────────────────────────────────

- (void)handleProgress:(NSNotification *)n  { [self updateProgress]; }
- (void)handleFinished:(NSNotification *)n
{
    _savedPath = _item.savedPath;
    [self updateProgress];
}
- (void)handleFailed:(NSNotification *)n    { [self updateProgress]; }
- (void)handleCancelled:(NSNotification *)n { [self updateProgress]; }

// ── Actions ───────────────────────────────────────────────────────────────────

- (void)cancelPressed:(id)sender
{
    [[TCDDownloadManager sharedManager] cancelDownload:_item];
}

- (void)showInFolder:(id)sender
{
    if (_savedPath.length) {
        [[NSWorkspace sharedWorkspace]
            selectFile:_savedPath
            inFileViewerRootedAtPath:[_savedPath stringByDeletingLastPathComponent]];
    } else {
        [[NSWorkspace sharedWorkspace] openFile:
         [TCDSettingsWindowController sharedController].downloadDirectory];
    }
}

// ── Drawing ───────────────────────────────────────────────────────────────────

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    [[NSColor whiteColor] setFill];
    NSRectFill(self.bounds);
    [[NSColor colorWithCalibratedWhite:0.88 alpha:1] setFill];
    NSRectFill(NSMakeRect(0, 0, NSWidth(self.bounds), 1));
    CGFloat blobY = (NSHeight(self.bounds) - kBlobSize) / 2.0;
    NSBezierPath *blob = [NSBezierPath
        bezierPathWithRoundedRect:NSMakeRect(kBlobPad, blobY, kBlobSize, kBlobSize)
        xRadius:kBlobCorner yRadius:kBlobCorner];
    [(_item.accentColor ?: [NSColor grayColor]) setFill];
    [blob fill];
}

- (NSTextField *)tf:(NSRect)f font:(NSFont *)font color:(NSColor *)c
{
    NSTextField *t    = [[NSTextField alloc] initWithFrame:f];
    t.editable        = NO; t.selectable  = NO;
    t.bordered        = NO; t.drawsBackground = NO;
    t.font = font; t.textColor = c;
    return t;
}

@end
