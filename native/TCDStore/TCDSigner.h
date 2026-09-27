//
//  TCDSigner.h
//  TCD Store
//
//  What happens to the signature of an installed payload.
//
//  Apple retired third-party Mac App Store distribution in 2012, so there is
//  no way for any store to be a trusted publisher on these systems. Every
//  policy here is a compromise; see docs/SIGNING.md for the full argument.
//
//  TCDSigningPolicyOptIn  never modify a signature. Ship a self-signed cert
//                         and an spctl profile, walk the user through
//                         enabling it. Nothing we do can break a signature
//                         that already works.  (default)
//
//  TCDSigningPolicyAdHoc  re-sign every bundle on the payload path with our
//                         own identity so it launches without a prompt.
//                         Needs the persistent privileged helper.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, TCDSigningPolicy) {
    TCDSigningPolicyOptIn = 0,
    TCDSigningPolicyAdHoc
};

@interface TCDSigner : NSObject

@property (nonatomic, readonly) TCDSigningPolicy policy;
@property (nonatomic, readonly) BOOL requiresPrivilege;

- (id)initWithPolicy:(TCDSigningPolicy)policy;

+ (TCDSigningPolicy)policyFromDefaults;
+ (void)setPolicyInDefaults:(TCDSigningPolicy)policy;

/* Name shown in the UI for the current policy. */
- (NSString *)policyTitle;
- (NSString *)policySummary;

/* Extra pipeline steps this policy inserts, in order. The install window
   renders these directly, so the two stay in step. */
- (NSArray *)additionalPipelineSteps;

/* Re-signs everything under `payloadPath`. No-op under the opt-in policy.
   Must be called with privilege. Returns the list of paths it touched. */
- (NSArray *)resignPayloadAtPath:(NSString *)payloadPath error:(NSError **)error;

/* Check only — used to show the user a warning before they install something
   that will need the opt-in dance. */
- (BOOL)payloadAtPathIsTrusted:(NSString *)payloadPath;

@end
