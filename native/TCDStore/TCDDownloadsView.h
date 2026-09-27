//
//  TCDDownloadsView.h
//  TCD Store
//
//  Downloads, full width and with no sidebar — the same two-part screen as the
//  prototype: what is in flight on top, what already landed below, and a Clear
//  History button.
//
//  This is a readout of the real engine, not a decoration. A TCDTransfer wraps
//  one TCDInstallSession and repaints from its stepChanged and logLine
//  callbacks, so the queue row carries the real step name, the real fraction
//  and the real installer output. A run is added the moment it starts and
//  removed only when it finishes or is cancelled, at which point it becomes a
//  history row.
//
//  10.7: no NSCollectionView, no NSStackView. Rows are laid out by hand inside
//  a clip view, the same way the sidebar does it.
//

#import <Cocoa/Cocoa.h>
#import "TCDPackage.h"
#import "TCDInstaller.h"

@class TCDDownloadsView;

/* One entry in the history list. */
@interface TCDHistoryEntry : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *verb;      // Install / Update / Downgrade / Reinstall / Remove
@property (nonatomic, strong) NSDate *when;
@end

/* One run in flight. Wraps the engine's session; the view asks it for
   everything it draws, so the row and the session can never disagree. */
@interface TCDTransfer : NSObject
@property (nonatomic, strong) TCDInstallSession *session;
@property (nonatomic, copy)   NSString *identifier;
@property (nonatomic, strong) NSDate *startedAt;
@property (nonatomic, strong) NSMutableArray *logLines;   // NSString
- (NSString *)verb;
- (NSString *)displayVersion;
- (NSString *)stepText;
- (double)fraction;
- (unsigned long long)totalSizeBytes;
- (TCDPackage *)package;
- (void)beginObservingWithBlock:(void (^)(void))onChange;
@end

@interface TCDDownloadsView : NSView

/* The queue. Adding a transfer repaints immediately, which is what makes the
   install visibly happen on this page. */
- (void)addTransfer:(TCDTransfer *)transfer;
- (void)removeTransferWithIdentifier:(NSString *)identifier;
- (NSUInteger)activeCount;

- (void)addHistoryEntry:(TCDHistoryEntry *)entry;
- (void)clearHistory;

/* Set while an install is running so the enclosing window can switch here. */
@property (nonatomic, copy) void (^onBecameNonEmpty)(BOOL nonEmpty);
@property (nonatomic, copy) void (^onCancelTransfer)(NSString *identifier);

@end
