//
//  TCDInstaller.h
//  TCD Store
//
//  Executes a TCDInstallPlan. The step list is data, not control flow, so the
//  progress window can render it and the tests can assert on it without
//  driving a real install.
//
//  Step order (opt-in policy):
//      download -> verify -> authorise -> install -> finish
//  Step order (ad-hoc policy):
//      download -> verify -> authorise -> install -> re-sign -> commit -> finish
//

#import <Foundation/Foundation.h>
#import "TCDPackage.h"
#import "TCDResolver.h"

typedef NS_ENUM(NSInteger, TCDInstallStage) {
    TCDInstallStageDownload,
    TCDInstallStageVerify,
    TCDInstallStageAuthorise,
    TCDInstallStageInstall,
    TCDInstallStageResign,
    TCDInstallStageCommit,
    TCDInstallStageFinish
};

@interface TCDInstallStep : NSObject
@property (nonatomic, assign) TCDInstallStage stage;
@property (nonatomic, copy)   NSString *title;
@property (nonatomic, copy)   NSString *detail;
@property (nonatomic, assign) double fraction;   // 0..1 across the whole plan
@property (nonatomic, assign) BOOL finished;
@end

@interface TCDInstallSession : NSObject
@property (nonatomic, readonly) NSArray *steps;
@property (nonatomic, readonly) TCDPackage *primaryPackage;
@property (nonatomic, readonly) BOOL finished;
@property (nonatomic, readonly) BOOL cancelled;
@property (nonatomic, readonly) NSString *failureReason;
/* the exact version being installed, and how it relates to what is on disk */
@property (nonatomic, readonly) NSString *targetVersion;
@property (nonatomic, readonly) TCDVersionRelation relation;
@property (nonatomic, readonly) NSString *verb;   // Install / Update / Downgrade / Reinstall
@property (nonatomic, copy) void (^stepChanged)(TCDInstallStep *step);
@property (nonatomic, copy) void (^logLine)(NSString *line, BOOL isError);
- (void)cancel;
@end

@interface TCDInstaller : NSObject

- (id)initWithAuthorizer:(id)authorizer signer:(id)signer;

/* Downloads, verifies, installs and records. Calls back on the main queue. */
- (TCDInstallSession *)installPlan:(TCDInstallPlan *)plan;

/* Removes a package plus any auto-installed dependencies that nothing else
   needs. The caller is responsible for having checked removalBlockers. */
- (void)removePackage:(TCDPackage *)pkg
             orphans:(NSArray *)orphans
            progress:(void (^)(double fraction, NSString *step))progress
            done:(void (^)(BOOL success, NSString *message))done;

@end
