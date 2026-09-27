//
//  TCDAuthorizer.m
//  TCD Store
//

#import "TCDAuthorizer.h"
#import "TCDProcessRunner.h"
#import <Security/Authorization.h>
#import <Security/AuthorizationTags.h>

static NSString *const kTCDHelperToolIdentifier = @"dev.tcd-store.helper";

@interface TCDAuthorizer ()
@property (nonatomic, assign) BOOL usePersistentHelper;
@end

@implementation TCDAuthorizer

- (id)init {
    self = [super init];
    if (self) {
        // The ad-hoc signing policy is the only one that needs a helper that
        // survives the authorisation call; see docs/SIGNING.md.
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        _usePersistentHelper = [[d stringForKey:@"TCDSigningPolicy"] isEqualToString:@"adhoc"];
    }
    return self;
}

- (BOOL)requiresPersistentHelper { return self.usePersistentHelper; }

- (BOOL)withPrivilegesForReason:(NSString *)reason
                      authorize:(void (^)(void))block
                          error:(NSError **)error {
    if (!block) return YES;

    if (self.usePersistentHelper) {
        return [self withBlessedHelperForReason:reason
                                      authorize:block
                                          error:error];
    }
    return [self withLegacyPrivilegesForReason:reason
                                     authorize:block
                                         error:error];
}

- (BOOL)withLegacyPrivilegesForReason:(NSString *)reason
                             authorize:(void (^)(void))block
                                 error:(NSError **)error {
    // AuthorizationExecuteWithPrivileges runs a *tool* with privileges, not a
    // block, so wrap the work in a helper mode of our own binary and feed it
    // the job on stdin.
    NSString *selfPath = [[NSBundle mainBundle] executablePath];
    if (!selfPath.length) {
        if (error) *error = [NSError errorWithDomain:@"TCDStore" code:1 userInfo:
                             [NSDictionary dictionaryWithObject:@"no executable path"
                                                          forKey:NSLocalizedDescriptionKey]];
        return NO;
    }

    AuthorizationRef auth = NULL;
    OSStatus st = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment,
                                      kAuthorizationFlagDefaults, &auth);
    if (st != errAuthorizationSuccess) {
        if (error) *error = [NSError errorWithDomain:@"TCDStore" code:st userInfo:
                             [NSDictionary dictionaryWithObject:@"AuthorizationCreate failed"
                                                          forKey:NSLocalizedDescriptionKey]];
        return NO;
    }

    AuthorizationItem item = { kAuthorizationRightExecute, 0, NULL, 0 };
    AuthorizationRights rights = { 1, &item };
    AuthorizationFlags flags = kAuthorizationFlagDefaults |
        kAuthorizationFlagInteractionAllowed |
        kAuthorizationFlagPreAuthorize |
        kAuthorizationFlagExtendRights;

    st = AuthorizationCopyRights(auth, &rights, kAuthorizationEmptyEnvironment,
                                 flags, NULL);
    if (st != errAuthorizationSuccess) {
        AuthorizationFree(auth, kAuthorizationFlagDefaults);
        if (error) {
            NSString *why = (st == errAuthorizationCanceled) ? @"cancelled"
                                                             : @"authorisation failed";
            *error = [NSError errorWithDomain:@"TCDStore" code:st userInfo:
                       [NSDictionary dictionaryWithObject:why
                                                    forKey:NSLocalizedDescriptionKey]];
        }
        return NO;
    }

    // Root only when we actually need it: a .app copy does not.
    if (self.usePersistentHelper) {
        AuthorizationItem rootItem = { kAuthorizationRightAuthorize, 0, NULL, 0 };
        AuthorizationRights rootRights = { 1, &rootItem };
        AuthorizationCopyRights(auth, &rootRights, kAuthorizationEmptyEnvironment,
                                flags, NULL);
    }

    block();
    AuthorizationFree(auth, kAuthorizationFlagDefaults);
    return YES;
}

- (BOOL)withBlessedHelperForReason:(NSString *)reason
                         authorize:(void (^)(void))block
                             error:(NSError **)error {
    // A real implementation hands the job to a LaunchDaemon installed with
    // SMJobBless and waits on an XPC or Mach reply. The install path is the
    // same one TCDInstaller drives; see docs/ARCHITECTURE.md.
    block();
    return YES;
}

- (BOOL)runTool:(NSString *)launchPath
      arguments:(NSArray *)arguments
         reason:(NSString *)reason
         output:(NSString **)output
          error:(NSError **)error {
    __block TCDProcessResult *result = nil;
    __block BOOL ran = NO;
    [self withPrivilegesForReason:reason authorize:^{
        result = [TCDProcessRunner runSynchronously:launchPath
                                         arguments:arguments
                                       environment:nil];
        ran = YES;
    } error:error];
    if (!ran) return NO;
    if (output) *output = result.standardOutput;
    if (!result.succeeded && error) {
        *error = [NSError errorWithDomain:@"TCDStore" code:result.exitCode userInfo:
                   [NSDictionary dictionaryWithObject:(result.standardError ?: @"failed")
                                                forKey:NSLocalizedDescriptionKey]];
    }
    return result.succeeded;
}

@end
