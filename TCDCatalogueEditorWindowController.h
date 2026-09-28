// TCDCatalogueEditorWindowController.h
// Two-pane catalogue editor window.
// Left: scrollable table of all apps with + / − buttons.
// Right: TCDAppFormView for the selected app or a new app.
#import <Cocoa/Cocoa.h>

@interface TCDCatalogueEditorWindowController : NSWindowController
+ (instancetype)sharedController;
@end
