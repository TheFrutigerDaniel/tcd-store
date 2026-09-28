// TCDIconDropView.m
#import "TCDIconDropView.h"
#import "TCDCatalogueManager.h"

static const CGFloat kSize   = 80.0;
static const CGFloat kCorner = 16.0;
static const CGFloat kBtnH   = 22.0;
static const CGFloat kTotalH = kSize + 6 + kBtnH;

@interface TCDIconDropView ()
@property (strong) NSImageView *imageView;
@property (strong) NSButton    *chooseButton;
@property (assign) BOOL         isDragTarget;
@end

@implementation TCDIconDropView

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:NSMakeRect(frame.origin.x, frame.origin.y,
                                           kSize, kTotalH)];
    if (!self) return nil;

    // NSFilenamesPboardType covers all file drops including images — on 10.7+.
    // NSTIFFPboardType covers raw TIFF data from other apps.
    // NSPNGPboardType does NOT exist on 10.7 — omit it entirely.
    [self registerForDraggedTypes:@[NSFilenamesPboardType, NSTIFFPboardType]];

    _imageView = [[NSImageView alloc]
        initWithFrame:NSMakeRect(0, kBtnH + 6, kSize, kSize)];
    _imageView.imageScaling   = NSImageScaleProportionallyUpOrDown;
    _imageView.imageAlignment = NSImageAlignCenter;
    [self addSubview:_imageView];

    _chooseButton = [[NSButton alloc]
        initWithFrame:NSMakeRect(0, 0, kSize, kBtnH)];
    _chooseButton.title      = @"Choose…";
    _chooseButton.bezelStyle = NSRoundedBezelStyle;
    _chooseButton.font       = [NSFont systemFontOfSize:10];
    _chooseButton.target     = self;
    _chooseButton.action     = @selector(choosePressed:);
    [self addSubview:_chooseButton];

    [self showPlaceholder];
    return self;
}

// ── Public ────────────────────────────────────────────────────────────────────

- (void)loadIconNamed:(NSString *)name
{
    NSImage *img = [TCDCatalogueManager iconNamed:name];
    if (img) {
        _currentImage    = img;
        _currentFilename = name;
        _imageView.image = img;
    } else {
        [self showPlaceholder];
    }
}

- (void)clear
{
    _currentImage    = nil;
    _currentFilename = nil;
    [self showPlaceholder];
}

// ── Drawing ───────────────────────────────────────────────────────────────────

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];

    NSRect imgRect = NSMakeRect(0, kBtnH + 6, kSize, kSize);

    NSColor *bg = _isDragTarget
        ? [NSColor colorWithCalibratedRed:0.2 green:0.5 blue:1.0 alpha:0.15]
        : [NSColor colorWithCalibratedWhite:0.88 alpha:1];
    [bg setFill];
    NSBezierPath *p = [NSBezierPath
        bezierPathWithRoundedRect:imgRect xRadius:kCorner yRadius:kCorner];
    [p fill];

    NSColor *border = _isDragTarget
        ? [NSColor colorWithCalibratedRed:0.2 green:0.5 blue:1.0 alpha:0.8]
        : [NSColor colorWithCalibratedWhite:0.70 alpha:1];
    [border setStroke];
    p.lineWidth = _isDragTarget ? 2.0 : 1.0;
    [p stroke];
}

- (void)showPlaceholder
{
    NSImage *ph = [NSImage imageNamed:NSImageNameIconViewTemplate];
    if (!ph) ph = [NSImage imageNamed:NSImageNameActionTemplate];
    _imageView.image = ph;
}

// ── Choose button ─────────────────────────────────────────────────────────────

- (void)choosePressed:(id)sender
{
    NSOpenPanel *panel            = [NSOpenPanel openPanel];
    panel.title                   = @"Choose Icon Image";
    panel.allowedFileTypes        = @[@"png", @"jpg", @"jpeg", @"tiff", @"gif"];
    panel.allowsMultipleSelection = NO;
    panel.canChooseDirectories    = NO;

    NSWindow *win = self.window;
    if (win) {
        [panel beginSheetModalForWindow:win completionHandler:^(NSInteger result) {
            if (result == NSFileHandlingPanelOKButton)
                [self installFromPath:[[panel URL] path]];
        }];
    } else {
        if ([panel runModal] == NSFileHandlingPanelOKButton)
            [self installFromPath:[[panel URL] path]];
    }
}

// ── Drag-and-drop ─────────────────────────────────────────────────────────────

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
    if ([self pathFromDraggingInfo:sender]) {
        _isDragTarget = YES;
        [self setNeedsDisplay:YES];
        return NSDragOperationCopy;
    }
    return NSDragOperationNone;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender
{
    _isDragTarget = NO;
    [self setNeedsDisplay:YES];
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    _isDragTarget = NO;
    [self setNeedsDisplay:YES];
    NSString *path = [self pathFromDraggingInfo:sender];
    if (!path) return NO;
    [self installFromPath:path];
    return YES;
}

- (NSString *)pathFromDraggingInfo:(id<NSDraggingInfo>)info
{
    NSPasteboard *pb = [info draggingPasteboard];
    NSArray *files   = [pb propertyListForType:NSFilenamesPboardType];
    if (![files isKindOfClass:[NSArray class]] || !files.count) return nil;
    NSString *path = files[0];
    NSArray *ok    = @[@"png", @"jpg", @"jpeg", @"tiff", @"gif"];
    if ([ok containsObject:[[path pathExtension] lowercaseString]])
        return path;
    return nil;
}

// ── Install ───────────────────────────────────────────────────────────────────

- (void)installFromPath:(NSString *)path
{
    NSString *filename = [TCDCatalogueManager installIconFromPath:path];
    if (!filename) return;

    NSString *fullPath = [[TCDCatalogueManager userIconDirectory]
        stringByAppendingPathComponent:filename];
    NSImage *img = [[NSImage alloc] initWithContentsOfFile:fullPath];
    if (!img) return;

    _currentImage    = img;
    _currentFilename = filename;
    _imageView.image = img;
    [self setNeedsDisplay:YES];

    if ([_delegate respondsToSelector:
         @selector(iconDropView:didInstallIconNamed:)])
        [_delegate iconDropView:self didInstallIconNamed:filename];
}

@end
