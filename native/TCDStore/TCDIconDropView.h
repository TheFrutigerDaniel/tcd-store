// TCDIconDropView.h
// NSImageView subclass that accepts drag-and-drop image files
// and has an integrated "Choose…" button.
// When an image is accepted it is installed into the user icon directory
// and the delegate is notified with the resulting filename.
#import <Cocoa/Cocoa.h>

@protocol TCDIconDropViewDelegate <NSObject>
// installedFilename is the filename (not full path) saved in the icon dir.
- (void)iconDropView:(id)sender didInstallIconNamed:(NSString *)installedFilename;
@end

@interface TCDIconDropView : NSView
@property (assign) id<TCDIconDropViewDelegate> delegate;  // assign, not weak — safe as form view always outlives drop view
@property (strong) NSImage  *currentImage;
@property (copy)   NSString *currentFilename;  // filename in icon dir, or nil

// Load an already-installed icon by name (looks in user dir + bundle)
- (void)loadIconNamed:(NSString *)name;
// Clear back to placeholder state
- (void)clear;
@end
