//
//  TCDProcessRunner.m
//  TCD Store
//

#import "TCDProcessRunner.h"
#import <spawn.h>
#import <unistd.h>
#import <sys/wait.h>
#import <errno.h>

extern char **environ;

@implementation TCDProcessResult

- (BOOL)succeeded {
    return !self.signalled && self.exitCode == 0;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ %@ -> %@ (%d)",
            self.launchPath, [self.arguments componentsJoinedByString:@" "],
            self.succeeded ? @"ok" : @"failed", self.exitCode];
}

@end

@implementation TCDProcessRunner

+ (BOOL)isExecutableAvailable:(NSString *)path {
    if (!path.length) return NO;
    return access([path fileSystemRepresentation], X_OK) == 0;
}

+ (TCDProcessResult *)runSynchronously:(NSString *)launchPath
                            arguments:(NSArray *)arguments
                          environment:(NSDictionary *)environment {
    return [self runAsynchronously:launchPath
                         arguments:arguments
                       environment:environment
                     lineHandler:nil
                          onQueue:nil
                       completion:nil];
}

+ (TCDProcessResult *)runAsynchronously:(NSString *)launchPath
                              arguments:(NSArray *)arguments
                            environment:(NSDictionary *)environment
                            lineHandler:(void (^)(NSString *, BOOL))lineHandler
                                onQueue:(dispatch_queue_t)queue
                             completion:(void (^)(TCDProcessResult *))completion {

    NSParameterAssert(launchPath.length);
    TCDProcessResult *result = [[TCDProcessResult alloc] init];
    result.launchPath = launchPath;
    result.arguments  = arguments;
    result.status     = -1;

    // The whole spawn-and-drain is factored out so the synchronous path can
    // run it inline. Firing it off with dispatch_async and then dispatch_sync
    // on a *concurrent* queue would not wait for it at all.
    TCDProcessResult *(^execute)(void) = ^TCDProcessResult *{
        int outPipe[2], errPipe[2];
        if (pipe(outPipe) != 0) return result;
        if (pipe(errPipe) != 0) { close(outPipe[0]); close(outPipe[1]); return result; }

        // Build argv. posix_spawn needs a NULL-terminated char**.
        NSUInteger count = arguments.count;
        char **argv = calloc(count + 2, sizeof(char *));
        argv[0] = strdup([launchPath fileSystemRepresentation]);
        for (NSUInteger i = 0; i < count; i++) {
            argv[i + 1] = strdup([[arguments objectAtIndex:i] fileSystemRepresentation]);
        }
        argv[count + 1] = NULL;

        char **envp = NULL;
        BOOL envOwned = NO;
        if (environment) {
            NSArray *keys = [[environment allKeys] sortedArrayUsingSelector:@selector(compare:)];
            envp = calloc(keys.count + 1, sizeof(char *));
            NSUInteger e = 0;
            for (NSString *k in keys) {
                NSString *entry = [NSString stringWithFormat:@"%@=%@", k, environment[k]];
                envp[e++] = strdup([entry fileSystemRepresentation]);
            }
            envp[e] = NULL;
            envOwned = YES;
        } else {
            envp = environ;
        }

        posix_spawn_file_actions_t actions;
        posix_spawn_file_actions_init(&actions);
        posix_spawn_file_actions_adddup2(&actions, outPipe[1], STDOUT_FILENO);
        posix_spawn_file_actions_adddup2(&actions, errPipe[1], STDERR_FILENO);
        posix_spawn_file_actions_addclose(&actions, outPipe[0]);
        posix_spawn_file_actions_addclose(&actions, errPipe[0]);
        posix_spawn_file_actions_addclose(&actions, outPipe[1]);
        posix_spawn_file_actions_addclose(&actions, errPipe[1]);

        pid_t pid = 0;
        int rc = posix_spawn(&pid, [launchPath fileSystemRepresentation],
                             &actions, NULL, argv, envp);
        posix_spawn_file_actions_destroy(&actions);

        close(outPipe[1]);
        close(errPipe[1]);

        if (rc != 0) {
            close(outPipe[0]); close(errPipe[0]);
            result.standardError = [NSString stringWithFormat:@"posix_spawn: %s", strerror(rc)];
            result.exitCode = -1;
            if (envOwned) { for (NSUInteger i = 0; envp[i]; i++) free(envp[i]); free(envp); }
            for (NSUInteger i = 0; i <= count + 1; i++) free(argv[i]);
            free(argv);
            return result;
        }

        // Drain both pipes with poll() so a full pipe buffer on stderr cannot
        // deadlock us against a child that is blocked writing to stdout.
        NSMutableString *outBuf = [NSMutableString string];
        NSMutableString *errBuf = [NSMutableString string];
        __block NSString *pending = nil;
        __block NSString *pendingErr = nil;

        void (^pump)(int, NSMutableString *, NSString **, BOOL) =
            ^(int fd, NSMutableString *buf, NSString **carry, BOOL isErr) {
            char chunk[4096];
            ssize_t n;
            while ((n = read(fd, chunk, sizeof(chunk))) > 0) {
                NSString *piece = [[NSString alloc] initWithBytes:chunk
                                                            length:(NSUInteger)n
                                                          encoding:NSUTF8StringEncoding];
                if (!piece) continue;
                NSString *text = [piece stringByAppendingString:*carry ?: @""];
                NSArray *lines = [text componentsSeparatedByString:@"\n"];
                *carry = [lines.lastObject copy];
                for (NSUInteger i = 0; i + 1 < lines.count; i++) {
                    NSString *line = lines[i];
                    [buf appendFormat:@"%@\n", line];
                    if (lineHandler) lineHandler(line, isErr);
                }
            }
        };

        struct pollfd fds[2];
        fds[0].fd = outPipe[0]; fds[0].events = POLLIN;
        fds[1].fd = errPipe[0]; fds[1].events = POLLIN;
        int open_fds = 2;
        while (open_fds > 0) {
            int pr = poll(fds, 2, -1);
            if (pr < 0) { if (errno == EINTR) continue; break; }
            for (int i = 0; i < 2; i++) {
                if (fds[i].fd < 0) continue;
                if (fds[i].revents & (POLLIN | POLLHUP | POLLERR)) {
                    pump(fds[i].fd, i == 0 ? outBuf : errBuf,
                         i == 0 ? &pending : &pendingErr, i == 1);
                    close(fds[i].fd);
                    fds[i].fd = -1;
                    open_fds--;
                }
            }
        }
        if (pending.length) {
            [outBuf appendString:pending];
            if (lineHandler) lineHandler(pending, NO);
        }
        if (pendingErr.length) {
            [errBuf appendString:pendingErr];
            if (lineHandler) lineHandler(pendingErr, YES);
        }

        int status = 0;
        while (waitpid(pid, &status, 0) < 0 && errno == EINTR) { }
        result.status = status;
        result.exitCode = WIFEXITED(status) ? WEXITSTATUS(status) : -1;
        result.signalled = WIFSIGNALED(status);
        result.standardOutput = outBuf;
        result.standardError = errBuf;

        if (envOwned) { for (NSUInteger i = 0; envp[i]; i++) free(envp[i]); free(envp); }
        for (NSUInteger i = 0; i <= count + 1; i++) free(argv[i]);
        free(argv);
        return result;
    };

    if (completion) {
        dispatch_queue_t work = queue ?: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(work, ^{
            TCDProcessResult *r = execute();
            dispatch_async(dispatch_get_main_queue(), ^{ completion(r); });
        });
        return result;   // returned unfilled; use the completion block
    }

    return execute();    // synchronous: run inline and hand back a real result
}

@end
