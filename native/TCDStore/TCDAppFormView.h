// TCDAppFormView.h
// Right-hand form pane in the catalogue editor.
// Displays and edits a single TCDAppItem.
#import <Cocoa/Cocoa.h>
@class TCDAppItem;

@protocol TCDAppFormViewDelegate <NSObject>
// Called when the user clicks Save. newItem is a freshly-built TCDAppItem
// populated from the form. originalItem is nil when adding a new app.
- (void)formView:(id)sender didSaveItem:(TCDAppItem *)newItem
    replacingItem:(TCDAppItem *)originalItem;
@end

@interface TCDAppFormView : NSView <NSTableViewDataSource, NSTableViewDelegate>

@property (assign) id<TCDAppFormViewDelegate> delegate;  // assign, not weak — weak zeroing is unreliable on 10.7 for NSScrollView document views

// Load an existing item into the form for editing. Pass nil to show a blank form.
- (void)loadItem:(TCDAppItem *)item;

// Clear the form
- (void)clear;

@end
