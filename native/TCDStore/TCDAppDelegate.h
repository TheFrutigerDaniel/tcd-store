//
//  TCDAppDelegate.h
//  TCD Store
//

#import <Cocoa/Cocoa.h>

@interface TCDAppDelegate : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) NSOutlineView *sourceList;
@property (nonatomic, strong) NSTableView  *contentTable;
@property (nonatomic, strong) NSTextField  *titleField;
@end
