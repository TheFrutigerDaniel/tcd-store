//
//  TCDSigner.m
//  TCD Store
//

#import "TCDSigner.h"
#import "TCDProcessRunner.h"
#import <Security/SecCode.h>
#import <Security/SecStaticCode.h>
#import <Security/SecRequirement.h>
#import <Security/CSCommon.h>   // kSecCSCheckAllArchitectures, kSecCSCheckNestedCode
#import <errno.h>              // ENOENT

/* The default CSSearchMode is zero. Upstream spells it as a named constant in
   CSBase.h, which the 10.9 SDK does not ship, so the value is named here
   rather than depending on a header that is not there. */
static const SecCSFlags kTCDDefaultSearchMode = 0;

static NSString *const kTCDSigningPolicyKey = @"TCDSigningPolicy";
static NSString *const kTCDIdentity        = @"TCD Store";

@interface TCDSigner ()
// readonly publicly because the policy is chosen once at construction; reopened
// here so -init has synthesised storage to write into
@property (nonatomic, assign) TCDSigningPolicy policy;
@end

@implementation TCDSigner

- (id)initWithPolicy:(TCDSigningPolicy)policy {
    self = [super init];
    if (self) { _policy = policy; }
    return self;
}

+ (TCDSigningPolicy)policyFromDefaults {
    NSString *s = [[NSUserDefaults standardUserDefaults] stringForKey:kTCDSigningPolicyKey];
    return [s isEqualToString:@"adhoc"] ? TCDSigningPolicyAdHoc : TCDSigningPolicyOptIn;
}

+ (void)setPolicyInDefaults:(TCDSigningPolicy)policy {
    NSString *s = (policy == TCDSigningPolicyAdHoc) ? @"adhoc" : @"optin";
    [[NSUserDefaults standardUserDefaults] setObject:s forKey:kTCDSigningPolicyKey];
}

- (BOOL)requiresPrivilege {
    return self.policy == TCDSigningPolicyAdHoc;
}

- (NSString *)policyTitle {
    return self.policy == TCDSigningPolicyAdHoc
        ? @"Ad-hoc re-sign installed payloads"
        : @"User opt-in (recommended)";
}

- (NSString *)policySummary {
    return self.policy == TCDSigningPolicyAdHoc
        ? @"Every bundle on the payload path is re-signed with the TCD Store identity, so what you install just runs. Requires a persistent privileged helper."
        : @"Signatures are never modified. The store ships a self-signed certificate and an spctl profile and walks you through enabling it once.";
}

- (NSArray *)additionalPipelineSteps {
    if (self.policy != TCDSigningPolicyAdHoc) return [NSArray array];
    return [NSArray arrayWithObjects:@"Re-signing payload", @"Committing receipts", nil];
}

/* Walks `path` and collects every .app, .framework, .bundle, .kext and
   .prefPane. Order matters: nested code must be signed before its container. */
- (NSArray *)signableBundlesUnderPath:(NSString *)path {
    NSMutableArray *found = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *e = [fm enumeratorAtPath:path];
    NSArray *exts = [NSArray arrayWithObjects:@"app", @"framework", @"bundle",
                     @"kext", @"prefPane", @"plugin", nil];
    for (NSString *rel in e) {
        if ([[rel pathExtension] caseInsensitiveCompare:@"app"] == NSOrderedSame) {
            // A helper inside an .app is already covered by signing the app.
            continue;
        }
        for (NSString *ext in exts) {
            if ([[rel pathExtension] caseInsensitiveCompare:ext] == NSOrderedSame) {
                [found addObject:[path stringByAppendingPathComponent:rel]];
                break;
            }
        }
    }
    [found sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        NSUInteger da = [[a pathComponents] count], db = [[b pathComponents] count];
        return da == db ? NSOrderedSame : (da < db ? NSOrderedAscending : NSOrderedDescending);
    }];
    if ([[path pathExtension] length]) [found insertObject:path atIndex:0];
    return found;
}

- (NSArray *)resignPayloadAtPath:(NSString *)payloadPath error:(NSError **)error {
    if (self.policy != TCDSigningPolicyAdHoc) return [NSArray array];
    if (!payloadPath.length || ![[NSFileManager defaultManager] fileExistsAtPath:payloadPath]) {
        if (error) *error = [NSError errorWithDomain:@"TCDStore" code:404 userInfo:
            [NSDictionary dictionaryWithObject:@"payload path does not exist"
                                         forKey:NSLocalizedDescriptionKey]];
        return nil;
    }
    if (![TCDProcessRunner isExecutableAvailable:@"/usr/bin/codesign"]) {
        if (error) *error = [NSError errorWithDomain:@"TCDStore" code:ENOENT userInfo:
            [NSDictionary dictionaryWithObject:@"/usr/bin/codesign is missing"
                                         forKey:NSLocalizedDescriptionKey]];
        return nil;
    }

    NSArray *bundles = [self signableBundlesUnderPath:payloadPath];
    NSMutableArray *touched = [NSMutableArray array];
    for (NSString *bundle in bundles) {
        // --deep covers the contents; --force overwrites any existing sig.
        NSArray *args = [NSArray arrayWithObjects:
                         @"-f", @"-s", kTCDIdentity, @"--deep", bundle, nil];
        TCDProcessResult *r = [TCDProcessRunner runSynchronously:@"/usr/bin/codesign"
                                                       arguments:args
                                                     environment:nil];
        if (!r.succeeded) {
            if (error) *error = [NSError errorWithDomain:@"TCDStore" code:r.exitCode userInfo:
                [NSDictionary dictionaryWithObject:(r.standardError ?: @"codesign failed")
                                             forKey:NSLocalizedDescriptionKey]];
            return nil;
        }
        [touched addObject:bundle];
    }
    return touched;
}

- (BOOL)payloadAtPathIsTrusted:(NSString *)payloadPath {
    if (!payloadPath.length) return NO;
    // the API takes a URL, not a path string
    CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:payloadPath];
    SecStaticCodeRef sc = NULL;
    if (SecStaticCodeCreateWithPath(url, kTCDDefaultSearchMode, &sc) != errSecSuccess)
        return NO;

    SecCSFlags flags = kSecCSCheckAllArchitectures | kSecCSCheckNestedCode;
    SecRequirementRef req = NULL;
    if (SecRequirementCreateWithString((__bridge CFStringRef)@"anchor apple generic",
                                       kTCDDefaultSearchMode, &req) != errSecSuccess) {
        CFRelease(sc);
        return NO;
    }
    // three arguments; the variant that reports a CFError is a different call
    OSStatus st = SecStaticCodeCheckValidity(sc, flags, req);
    CFRelease(req);
    CFRelease(sc);
    return st == errSecSuccess;
}

@end
