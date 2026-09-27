//
//  main.m
//  TCD Store
//

#import <Cocoa/Cocoa.h>
#import "TCDAppDelegate.h"

int main(int argc, const char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSApplication *app = [NSApplication sharedApplication];
    TCDAppDelegate *delegate = [[TCDAppDelegate alloc] init];
    [app setDelegate:delegate];
    [app setActivationPolicy:NSApplicationActivationPolicyRegular];
    [app run];
    [pool release];
    return 0;
}
