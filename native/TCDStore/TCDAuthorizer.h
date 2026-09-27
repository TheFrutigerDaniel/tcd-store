//
//  TCDAuthorizer.h
//  TCD Store
//
//  Getting root, on 10.7, for an app that is not in the Mac App Store.
//
//  AuthorizationExecuteWithPrivileges is available on 10.7 and needs no
//  helper, but it is deprecated from 10.7 onward and Apple has never
//  guaranteed it. It is the only option that works on a machine where the
//  user cannot install a LaunchDaemon, so it is the default.
//
//  SMJobBless is the supported route and is required for the ad-hoc signing
//  policy (see TCDSigner), because re-signing installed payloads needs a
//  privileged identity that outlives a single authorisation call.
//
//  Pick per policy at construction; the rest of the app only sees
//  -withPrivilegesFor:reason:execute:.
//

#import <Foundation/Foundation.h>

@interface TCDAuthorizer : NSObject

@property (nonatomic, readonly) BOOL requiresPersistentHelper;   // YES under SMJobBless

/* Runs `block` as root.
   Returns NO and fills *error if the user cancelled or authorisation failed. */
- (BOOL)withPrivilegesForReason:(NSString *)reason
                      authorize:(void (^)(void))block
                          error:(NSError **)error;

/* Convenience: run one tool as root and give back the output. */
- (BOOL)runTool:(NSString *)launchPath
      arguments:(NSArray *)arguments
         reason:(NSString *)reason
         output:(NSString **)output
          error:(NSError **)error;

@end
