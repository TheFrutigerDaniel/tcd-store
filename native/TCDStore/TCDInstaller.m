//
//  TCDInstaller.m
//  TCD Store
//

#import "TCDInstaller.h"
#import "TCDProcessRunner.h"
#import "TCDAuthorizer.h"
#import "TCDSigner.h"
#import "TCDPackageDatabase.h"

#import <CommonCrypto/CommonDigest.h>

static NSString *const kTCDInstallerPath   = @"/usr/sbin/installer";
static NSString *const kTCDKextUtilPath    = @"/usr/sbin/kextutil";
static NSString *const kTCDPackageRoot     = @"/Library/Package Receipts";

@implementation TCDInstallStep
- (NSString *)description { return self.title; }
@end

@interface TCDInstallSession ()
@property (nonatomic, strong) NSMutableArray *mutableSteps;
@property (nonatomic, weak)   TCDInstaller *installer;
@property (nonatomic, assign) BOOL cancelledFlag;
@end

/* The verb shown in the window, and whether the user is being moved
   backwards. A downgrade is allowed but warned about: files written by the
   newer version are not cleaned up. */
static NSString *TCDVerbForRelation(TCDVersionRelation r) {
    return [TCDPackage stringForRelation:r];
}

@implementation TCDInstallSession

- (NSArray *)steps { return self.mutableSteps; }
- (void)cancel { self.cancelledFlag = YES; }
- (BOOL)cancelled { return self.cancelledFlag; }

@end

@interface TCDInstaller ()
@property (nonatomic, strong) TCDAuthorizer *authorizer;
@property (nonatomic, strong) TCDSigner    *signer;
@property (nonatomic, strong) dispatch_queue_t work;
- (BOOL)installOnePackage:(TCDPackage *)p
                 fromPath:(NSString *)path
                     log:(void (^)(NSString *line, BOOL isError))log
                  error:(NSError **)error;
@end

@implementation TCDInstaller

- (id)initWithAuthorizer:(TCDAuthorizer *)authorizer signer:(TCDSigner *)signer {
    self = [super init];
    if (self) {
        _authorizer = authorizer;
        _signer = signer;
        _work = dispatch_queue_create("dev.tcd-store.install", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

#pragma mark - step list

- (NSMutableArray *)stepsForPlan:(TCDInstallPlan *)plan {
    NSMutableArray *steps = [NSMutableArray array];
    void (^add)(TCDInstallStage, NSString *, NSString *) =
        ^(TCDInstallStage s, NSString *t, NSString *d) {
        TCDInstallStep *step = [[TCDInstallStep alloc] init];
        step.stage = s; step.title = t; step.detail = d;
        [steps addObject:step];
    };

    add(TCDInstallStageDownload,   @"Downloading…", [NSString stringWithFormat:
        @"%@ v%@", plan.packages.lastObject.name, plan.primaryVersion ?: plan.packages.lastObject.version]);
    add(TCDInstallStageVerify,     @"Verifying checksum…", @"SHA-256 against the source index");
    add(TCDInstallStageAuthorise,  @"Requesting authorisation…", @"Needed for system-level packages");
    add(TCDInstallStageInstall,    @"Installing…",    @"/usr/sbin/installer -target /");
    for (NSString *title in [self.signer additionalPipelineSteps]) {
        BOOL isSign = [title hasPrefix:@"Re-sign"];
        add(isSign ? TCDInstallStageResign : TCDInstallStageCommit, title,
            isSign ? @"codesign -f -s \"TCD Store\"" : @"Recording receipts");
    }
    add(TCDInstallStageFinish,     @"Finishing…",    @"Writing package records");
    return steps;
}

#pragma mark - install

/* The verb the window opens with, so "Downgrade" is stated up front rather
   than discovered halfway through. */
- (NSString *)verbForPlan:(TCDInstallPlan *)plan {
    return TCDVerbForRelation(plan.primaryRelation);
}

- (TCDInstallSession *)installPlan:(TCDInstallPlan *)plan {
    TCDInstallSession *session = [[TCDInstallSession alloc] init];
    session.mutableSteps = [self stepsForPlan:plan];
    session.primaryPackage = plan.packages.lastObject;
    session.targetVersion = plan.primaryVersion;
    session.relation      = plan.primaryRelation;
    session.verb          = TCDVerbForRelation(plan.primaryRelation);
    session.installer = self;

    dispatch_async(self.work, ^{
        [self executePlan:plan session:session];
    });
    return session;
}

- (void)advance:(TCDInstallSession *)session toStage:(TCDInstallStage)stage {
    NSUInteger total = session.mutableSteps.count;
    for (NSUInteger i = 0; i < total; i++) {
        TCDInstallStep *step = session.mutableSteps[i];
        step.finished = (step.stage < stage);
        step.fraction = (double)i / (double)MAX(total, (NSUInteger)1);
    }
    void (^cb)(TCDInstallStep *) = session.stepChanged;
    if (cb) dispatch_async(dispatch_get_main_queue(), ^{ cb(session.mutableSteps.lastObject); });
}

- (void)log:(TCDInstallSession *)session line:(NSString *)line error:(BOOL)isError {
    void (^cb)(NSString *, BOOL) = session.logLine;
    if (!cb) return;
    dispatch_async(dispatch_get_main_queue(), ^{ cb(line, isError); });
}

- (void)executePlan:(TCDInstallPlan *)plan session:(TCDInstallSession *)session {
    if (![plan isValid]) {
        session.failureReason = plan.failureReason
            ?: [NSString stringWithFormat:@"%lu blocking conflict(s)",
                (unsigned long)plan.blockingConflicts.count];
        [self finishSession:session];
        return;
    }

    NSMutableDictionary *downloads = [NSMutableDictionary dictionary];
    NSString *scratch = [NSTemporaryDirectory()
        stringByAppendingPathComponent:[NSString stringWithFormat:@"tcd-%@",
            [[NSProcessInfo processInfo] globallyUniqueString]]];
    [[NSFileManager defaultManager] createDirectoryAtPath:scratch
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];

    // ---- download -----------------------------------------------------
    [self advance:session toStage:TCDInstallStageDownload];
    for (TCDPackage *p in plan.packages) {
        if (session.cancelled) { [self abandon:session scratch:scratch]; return; }
        NSString *dest = [scratch stringByAppendingPathComponent:
            [p.downloadURLString lastPathComponent]];
        NSError *err = nil;
        NSData *data = [self downloadURLString:p.downloadURLString error:&err];
        if (!data.length) {
            session.failureReason = [NSString stringWithFormat:@"download failed: %@",
                                     err.localizedDescription ?: @"unknown"];
            [self finishSession:session];
            [[NSFileManager defaultManager] removeItemAtPath:scratch error:NULL];
            return;
        }
        if (![data writeToFile:dest atomically:YES]) {
            session.failureReason = @"could not write the download to disk";
            [self finishSession:session];
            [[NSFileManager defaultManager] removeItemAtPath:scratch error:NULL];
            return;
        }
        downloads[p.identifier] = dest;
        [self log:session line:[NSString stringWithFormat:@"GET %@ (%lu bytes)",
            p.downloadURLString, (unsigned long)p.sizeBytes] error:NO];
    }

    // ---- verify -------------------------------------------------------
    [self advance:session toStage:TCDInstallStageVerify];
    for (TCDPackage *p in plan.packages) {
        if (session.cancelled) { [self abandon:session scratch:scratch]; return; }
        NSString *digest = [self sha256OfFileAtPath:downloads[p.identifier]];
        if (p.sha256.length && digest && [digest caseInsensitiveCompare:p.sha256] != NSOrderedSame) {
            session.failureReason = [NSString stringWithFormat:
                @"checksum mismatch for %@ — refusing to install", p.name];
            [self log:session line:@"checksum mismatch" error:YES];
            [self finishSession:session];
            [[NSFileManager defaultManager] removeItemAtPath:scratch error:NULL];
            return;
        }
        [self log:session line:[NSString stringWithFormat:@"sha256 %@  ok", p.name] error:NO];
    }

    // ---- install ------------------------------------------------------
    [self advance:session toStage:TCDInstallStageInstall];
    __block NSError *installError = nil;
    __block BOOL authorised = [self.authorizer withPrivilegesForReason:
        @"TCD Store needs to install system-level packages."
        authorize:^{
            for (TCDPackage *p in plan.packages) {
                if (session.cancelled) return;
                NSError *err = nil;
                if (![self installOnePackage:p
                                   fromPath:downloads[p.identifier]
                                      log:^(NSString *line, BOOL isErr){
                                          [self log:session line:line error:isErr];
                                      }
                                     error:&err]) {
                    installError = err;
                    return;
                }
            }
        } error:&installError];

    if (session.cancelled) { [self abandon:session scratch:scratch]; return; }
    if (!authorised || installError) {
        session.failureReason = installError.localizedDescription
            ?: @"authorisation was not granted";
        [self finishSession:session];
        [[NSFileManager defaultManager] removeItemAtPath:scratch error:NULL];
        return;
    }

    // ---- re-sign ------------------------------------------------------
    if ([self.signer requiresPrivilege]) {
        [self advance:session toStage:TCDInstallStageResign];
        __block NSError *signError = nil;
        [self.authorizer withPrivilegesForReason:@"TCD Store needs to re-sign installed payloads."
                                       authorize:^{
            for (TCDPackage *p in plan.packages) {
                NSString *payload = [self payloadPathForPackage:p];
                if (!payload) continue;
                if (![self.signer resignPayloadAtPath:payload error:&signError]) return;
            }
        } error:&signError];
        if (signError) {
            session.failureReason = signError.localizedDescription;
            [self finishSession:session];
            [[NSFileManager defaultManager] removeItemAtPath:scratch error:NULL];
            return;
        }
    }

    // ---- commit -------------------------------------------------------
    [self advance:session toStage:TCDInstallStageFinish];
    NSArray *primary = plan.primaryIdentifiers;
    for (TCDPackage *p in plan.packages) {
        // A package sitting on something other than the newest version in its
        // source is still updatable — that is the entire point of the version
        // menu, and it has to survive a round trip through the database.
        // -hasUpdate is derived from exactly this pair of strings, so no
        // extra flag is needed to keep it correct after a downgrade.
        NSString *landed = [overrides objectForKey:p.identifier] ?: p.version;
        p.installed = YES;
        p.installedVersion = landed;
        // Only packages the user actually asked for are eligible for
        // autoremove later; see TCDResolver -orphansAfterRemovingPackage:.
        p.autoInstalled = ![primary containsObject:p.identifier];
    }
    TCDPackageDatabase *db = [TCDPackageDatabase sharedDatabase];
    for (TCDPackage *p in plan.packages) [db upsertPackage:p];
    [db commit];
    [self log:session line:@"package records written" error:NO];

    [[NSFileManager defaultManager] removeItemAtPath:scratch error:NULL];
    [self finishSession:session];
}

- (void)abandon:(TCDInstallSession *)session scratch:(NSString *)scratch {
    [[NSFileManager defaultManager] removeItemAtPath:scratch error:NULL];
    [self finishSession:session];
}

- (void)finishSession:(TCDInstallSession *)session {
    for (TCDInstallStep *step in session.mutableSteps) step.finished = YES;
    session.finished = YES;
    void (^cb)(TCDInstallStep *) = session.stepChanged;
    if (cb) dispatch_async(dispatch_get_main_queue(), ^{ cb(session.mutableSteps.lastObject); });
}

#pragma mark - per-kind install

- (BOOL)installOnePackage:(TCDPackage *)p
                 fromPath:(NSString *)path
                     log:(void (^)(NSString *line, BOOL isError))log
                  error:(NSError **)error {
    if (![TCDProcessRunner isExecutableAvailable:kTCDInstallerPath]) {
        if (error) *error = [NSError errorWithDomain:@"TCDStore" code:ENOENT userInfo:
            [NSDictionary dictionaryWithObject:@"/usr/sbin/installer not found"
                                         forKey:NSLocalizedDescriptionKey]];
        return NO;
    }

    if (p.type == TCDPackageTypePkg) {
        NSArray *args = [NSArray arrayWithObjects:@"-pkg", path, @"-target", @"/", nil];
        TCDProcessResult *r = [TCDProcessRunner runSynchronously:kTCDInstallerPath
                                                     arguments:args
                                                   environment:nil];
        if (log) {
            for (NSString *line in [r.standardOutput componentsSeparatedByString:@"\n"]) {
                if (line.length) log(line, NO);
            }
        }
        if (!r.succeeded) {
            if (log) for (NSString *line in [r.standardError componentsSeparatedByString:@"\n"]) {
                if (line.length) log(line, YES);
            }
            if (error) *error = [NSError errorWithDomain:@"TCDStore" code:r.exitCode userInfo:
                [NSDictionary dictionaryWithObject:(r.standardError ?: @"installer failed")
                                             forKey:NSLocalizedDescriptionKey]];
            return NO;
        }
        // Record the receipt so we can uninstall it later.
        p.receiptID = [self receiptIDForInstalledPackageNamed:p.name];
        return YES;
    }

    // .app / .kext / .prefPane: move the bundle into place.
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dest = p.installPrefix;
    if (!dest.length) {
        NSString *name = [path lastPathComponent];
        if (![name.pathExtension length]) name = [name stringByAppendingPathExtension:@"app"];
        dest = [[self applicationsDirectory] stringByAppendingPathComponent:name];
    }
    NSString *destParent = [dest stringByDeletingLastPathComponent];
    [fm createDirectoryAtPath:destParent withIntermediateDirectories:YES attributes:nil error:NULL];
    if ([fm fileExistsAtPath:dest]) [fm removeItemAtPath:dest error:NULL];
    if (![fm moveItemAtPath:path toPath:dest error:error]) return NO;

    if (p.type == TCDPackageTypeKext && [TCDProcessRunner isExecutableAvailable:kTCDKextUtilPath]) {
        [TCDProcessRunner runSynchronously:kTCDKextUtilPath
                                arguments:[NSArray arrayWithObject:@"-nt"]
                              environment:nil];
    }
    return YES;
}

#pragma mark - removal

- (void)removePackage:(TCDPackage *)pkg
             orphans:(NSArray *)orphans
            progress:(void (^)(double, NSString *))progress
            done:(void (^)(BOOL, NSString *))done {
    dispatch_async(self.work, ^{
        NSArray *all = [orphans arrayByAddingObject:pkg];
        double per = 1.0 / (double)MAX(all.count, (NSUInteger)1);
        __block BOOL ok = YES;
        __block NSString *message = nil;
        NSError *installErr = nil;

        [self.authorizer withPrivilegesForReason:@"TCD Store needs to remove a package."
                                       authorize:^{
            NSUInteger i = 0;
            for (TCDPackage *p in all) {
                if (p.type == TCDPackageTypePkg && p.receiptID.length) {
                    TCDProcessResult *r = [TCDProcessRunner runSynchronously:kTCDInstallerPath
                        arguments:[NSArray arrayWithObjects:@"-uninstall", p.receiptID,
                                    @"-target", @"/", nil]
                      environment:nil];
                    if (!r.succeeded) { ok = NO; message = r.standardError; }
                } else {
                    NSString *path = p.installPrefix;
                    if (path.length && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
                        if (![[NSFileManager defaultManager] removeItemAtPath:path error:NULL]) {
                            ok = NO; message = [NSString stringWithFormat:@"could not remove %@", path];
                        }
                    }
                }
                i++;
                if (progress) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        progress(i * per, [NSString stringWithFormat:@"Removing %@", p.name]);
                    });
                }
            }
        } error:&installErr];

        if (ok && !installErr) {
            TCDPackageDatabase *db = [TCDPackageDatabase sharedDatabase];
            for (TCDPackage *p in all) {
                p.installed = NO; p.installedVersion = nil; p.autoInstalled = NO;
                [db upsertPackage:p];
            }
            [db commit];
        }
        if (done) {
            dispatch_async(dispatch_get_main_queue(), ^{
                done(ok, ok ? [NSString stringWithFormat:@"Removed %@", pkg.name] : message);
            });
        }
    });
}

#pragma mark - helpers

- (NSString *)applicationsDirectory {
    NSArray *a = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory,
                                                     NSLocalDomainMask, YES);
    return a.count ? a[0] : @"/Applications";
}

- (NSString *)payloadPathForPackage:(TCDPackage *)p {
    return p.installPrefix;
}

- (NSString *)receiptIDForInstalledPackageNamed:(NSString *)name {
    NSString *file = [name stringByAppendingPathExtension:@"pkg"];
    NSString *dir  = kTCDPackageRoot;
    NSArray *found = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:NULL];
    for (NSString *f in found) {
        if ([f caseInsensitiveCompare:file] == NSOrderedSame) return f.lastPathComponent;
    }
    return nil;
}

- (NSData *)downloadURLString:(NSString *)urlString error:(NSError **)error {
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        if (error) *error = [NSError errorWithDomain:@"TCDStore" code:400 userInfo:
            [NSDictionary dictionaryWithObject:@"bad URL" forKey:NSLocalizedDescriptionKey]];
        return nil;
    }
    // NSURLSession does not exist on 10.7.
    NSURLRequest *req = [NSURLRequest requestWithURL:url
                                         cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                     timeoutInterval:60.0];
    __block NSData *data = nil;
    __block NSError *err = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [NSURLConnection sendAsynchronousRequest:req
                                      queue:[NSOperationQueue mainQueue]
                          completionHandler:^(NSURLResponse *response, NSData *body, NSError *e) {
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        if (!e && (http.statusCode < 200 || http.statusCode > 299)) {
            e = [NSError errorWithDomain:@"TCDStore" code:http.statusCode userInfo:
                  [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"HTTP %ld",
                      (long)http.statusCode] forKey:NSLocalizedDescriptionKey]];
        }
        data = body; err = e;
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    if (err && error) *error = err;
    return data;
}

- (NSString *)sha256OfFileAtPath:(NSString *)path {
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:NULL];
    if (!data.length) return nil;
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", digest[i]];
    return hex;
}

@end
