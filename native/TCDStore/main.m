//
//  main.m
//  TCD Store
//

#import <Cocoa/Cocoa.h>
#import "TCDAppDelegate.h"

int main(int argc, const char *argv[]) {
    (void)argc; (void)argv;

    // No NSAutoreleasePool release: the target builds with ARC, which forbids
    // sending -release explicitly. AppKit installs a pool for the duration of
    // the run loop, so nothing is needed here.
    NSApplication *app = [NSApplication sharedApplication];
    TCDAppDelegate *delegate = [[TCDAppDelegate alloc] init];
    [app setDelegate:delegate];
    [app setActivationPolicy:NSApplicationActivationPolicyRegular];
    [app run];
    return 0;
}
