// TCDAppCardView.m
#import "TCDAppCardView.h"
#import "TCDAppItem.h"
#import "TCDDownloadManager.h"
#import "TCDCatalogueManager.h"

static const CGFloat kCardW      = 160.0;
static const CGFloat kCardH      = 210.0;
static const CGFloat kIconSize   =  80.0;
static const CGFloat kIconTopPad =  14.0;
static const CGFloat kIconCorner =  16.0;
static const CGFloat kPad        =   8.0;
static const CGFloat kDotD       =   8.0;

@interface TCDAppCardView ()
@property (strong) NSPopUpButton *versionPopup;
@property (strong) NSButton      *downloadButton;
@property (strong) NSTextField   *nameLabel;
@property (strong) NSTextField   *devLabel;
@property (strong) NSView        *statusDot;
@property (copy)   NSString      *installedVersion;
@property (strong) NSImage       *iconImage;   // nil = draw colour blob
@end

@implementation TCDAppCardView

- (instancetype)initWithItem:(TCDAppItem *)item
{
    self = [super initWithFrame:NSMakeRect(0, 0, kCardW, kCardH)];
    if (!self) return nil;
    _item      = item;
    _iconImage = [TCDCatalogueManager iconNamed:item.iconName];
    [self buildSubviews];

    [[NSNotificationCenter defaultCenter]
        addObserver:self selector:@selector(downloadProgress:)
               name:TCDDownloadProgressNotification object:_item];
    [[NSNotificationCenter defaultCenter]
        addObserver:self selector:@selector(downloadFinished:)
               name:TCDDownloadFinishedNotification object:_item];
    [[NSNotificationCenter defaultCenter]
        addObserver:self selector:@selector(downloadFailed:)
               name:TCDDownloadFailedNotification object:_item];
    return self;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)buildSubviews
{
    CGFloat W = kCardW, H = kCardH;

    CGFloat nameY = H - kIconTopPad - kIconSize - 4 - 18;
    _nameLabel = [self tf:NSMakeRect(kPad, nameY, W-kPad*2, 18)
                     font:[NSFont boldSystemFontOfSize:11]
                    color:[NSColor blackColor]];
    _nameLabel.stringValue = _item.name ?: @"";
    [self addSubview:_nameLabel];

    _devLabel = [self tf:NSMakeRect(kPad, nameY-15, W-kPad*2, 14)
                    font:[NSFont systemFontOfSize:9]
                   color:[NSColor grayColor]];
    _devLabel.stringValue = _item.developer ?: @"";
    [self addSubview:_devLabel];

    CGFloat popY = nameY - 42;
    _versionPopup = [[NSPopUpButton alloc]
                     initWithFrame:NSMakeRect(kPad, popY, W-kPad*2, 22) pullsDown:NO];
    _versionPopup.font = [NSFont systemFontOfSize:10];
    [_versionPopup removeAllItems];
    [_versionPopup addItemsWithTitles:(_item.versions.count ? _item.versions : @[@"v1.0"])];
    [_versionPopup setTarget:self];
    [_versionPopup setAction:@selector(versionChanged:)];
    [self addSubview:_versionPopup];

    CGFloat btnY = popY - 30;
    _downloadButton = [[NSButton alloc]
                       initWithFrame:NSMakeRect(kPad, btnY, W-kPad*2, 24)];
    _downloadButton.bezelStyle = NSRoundedBezelStyle;
    _downloadButton.font       = [NSFont systemFontOfSize:11];
    _downloadButton.target     = self;
    _downloadButton.action     = @selector(downloadPressed:);
    [self addSubview:_downloadButton];

    CGFloat dotX = (W - kDotD) / 2.0;
    _statusDot = [[NSView alloc] initWithFrame:NSMakeRect(dotX, 6, kDotD, kDotD)];
    _statusDot.wantsLayer         = YES;
    _statusDot.layer.cornerRadius = kDotD / 2.0;
    [self addSubview:_statusDot];

    [self refreshState];
}

- (void)refreshState
{
    NSString *selected = [_versionPopup titleOfSelectedItem];

    if (_item.downloadState == TCDDownloadStateDownloading
        && [_item.selectedVersion isEqualToString:selected]) {
        _downloadButton.title   = @"Downloading…";
        _downloadButton.enabled = NO;
        _statusDot.layer.backgroundColor =
            [NSColor colorWithCalibratedRed:0.9 green:0.7 blue:0.0 alpha:1].CGColor;
        return;
    }
    if (_item.downloadState == TCDDownloadStateFailed
        && [_item.selectedVersion isEqualToString:selected]) {
        _downloadButton.title   = @"Retry";
        _downloadButton.enabled = YES;
        _statusDot.layer.backgroundColor =
            [NSColor colorWithCalibratedRed:0.85 green:0.15 blue:0.15 alpha:1].CGColor;
        return;
    }
    if (_item.downloadState == TCDDownloadStateDone
        && [_installedVersion isEqualToString:selected]) {
        _downloadButton.title   = @"Installed";
        _downloadButton.enabled = NO;
        _statusDot.layer.backgroundColor =
            [NSColor colorWithCalibratedRed:0.18 green:0.72 blue:0.18 alpha:1].CGColor;
        return;
    }
    _downloadButton.title   = @"Download";
    _downloadButton.enabled = YES;
    _statusDot.layer.backgroundColor =
        [NSColor colorWithCalibratedWhite:0.72 alpha:1].CGColor;
}

- (void)downloadProgress:(NSNotification *)n  { [self refreshState]; }
- (void)downloadFinished:(NSNotification *)n
{
    _installedVersion = _item.selectedVersion;
    [self refreshState];
}
- (void)downloadFailed:(NSNotification *)n    { [self refreshState]; }

- (void)versionChanged:(id)sender
{
    _item.selectedVersion = [_versionPopup titleOfSelectedItem];
    [self refreshState];
}

- (void)downloadPressed:(id)sender
{
    _item.selectedVersion = [_versionPopup titleOfSelectedItem];
    if ([_delegate respondsToSelector:@selector(cardViewDidRequestDownload:version:)])
        [_delegate cardViewDidRequestDownload:_item version:_item.selectedVersion];
}

// ── Drawing ───────────────────────────────────────────────────────────────────

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    NSRect b = self.bounds;

    // Card background
    [[NSColor colorWithCalibratedWhite:0.98 alpha:1] setFill];
    NSBezierPath *bg = [NSBezierPath bezierPathWithRoundedRect:b xRadius:6 yRadius:6];
    [bg fill];
    [[NSColor colorWithCalibratedWhite:0.82 alpha:1] setStroke];
    bg.lineWidth = 0.5;
    [bg stroke];

    CGFloat ix = (NSWidth(b) - kIconSize) / 2.0;
    CGFloat iy = NSHeight(b) - kIconTopPad - kIconSize;
    NSRect iconRect = NSMakeRect(ix, iy, kIconSize, kIconSize);

    if (_iconImage) {
        // ── Draw real icon, clipped to rounded rect ───────────────────────
        NSBezierPath *clip = [NSBezierPath
            bezierPathWithRoundedRect:iconRect
                              xRadius:kIconCorner yRadius:kIconCorner];
        [NSGraphicsContext saveGraphicsState];
        [clip setClip];
        [_iconImage drawInRect:iconRect
                      fromRect:NSZeroRect
                     operation:NSCompositeSourceOver
                      fraction:1.0];
        [NSGraphicsContext restoreGraphicsState];
    } else {
        // ── Fallback: coloured blob ───────────────────────────────────────
        NSBezierPath *blob = [NSBezierPath
            bezierPathWithRoundedRect:iconRect
                              xRadius:kIconCorner yRadius:kIconCorner];
        [(_item.accentColor ?: [NSColor grayColor]) setFill];
        [blob fill];
    }
}

- (NSTextField *)tf:(NSRect)f font:(NSFont *)font color:(NSColor *)c
{
    NSTextField *t = [[NSTextField alloc] initWithFrame:f];
    t.editable = t.selectable = t.bordered = t.drawsBackground = NO;
    t.font = font; t.textColor = c;
    return t;
}

@end
