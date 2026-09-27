//
//  TCDProcessRunner.h
//  TCD Store
//
//  NSTask did not exist until 10.13, so a 10.7-compatible app has to spawn
//  processes itself. Everything the store shells out to — /usr/sbin/installer,
//  /usr/sbin/kextutil, /usr/bin/codesign, /usr/sbin/spctl — goes through
//  here so there is exactly one place that deals with pipes, exit codes and
//  the privilege boundary.
//

#import <Foundation/Foundation.h>

@interface TCDProcessResult : NSObject
@property (nonatomic, assign) int status;        // waitpid() status
@property (nonatomic, assign) int exitCode;      // WEXITSTATUS(status)
@property (nonatomic, assign) BOOL signalled;
@property (nonatomic, copy)   NSString *standardOutput;
@property (nonatomic, copy)   NSString *standardError;
@property (nonatomic, copy)   NSString *launchPath;
@property (nonatomic, copy)   NSArray  *arguments;
- (BOOL)succeeded;
@end

@interface TCDProcessRunner : NSObject

/* Runs `launchPath` with `arguments`, capturing both streams. Blocks the
   calling thread. Returns nil if the binary could not be executed at all. */
+ (TCDProcessResult *)runSynchronously:(NSString *)launchPath
                            arguments:(NSArray *)arguments
                          environment:(NSDictionary *)environment;

/* Same, but delivers output lines to `handler` on a private queue as they
   arrive, and reports completion on `completionQueue`. Use this for long
   installs so the progress window can paint. */
+ (TCDProcessResult *)runAsynchronously:(NSString *)launchPath
                              arguments:(NSArray *)arguments
                            environment:(NSDictionary *)environment
                          lineHandler:(void (^)(NSString *line, BOOL isError))lineHandler
                            onQueue:(dispatch_queue_t)queue
                           completion:(void (^)(TCDProcessResult *result))completion;

/* YES if the path exists and is executable. */
+ (BOOL)isExecutableAvailable:(NSString *)path;

@end
