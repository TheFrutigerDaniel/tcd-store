// main.m
#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

int main(int argc, const char * argv[])
{
    @autoreleasepool {
        // Manually create the app and delegate — no NIB involved at all.
        NSApplication *app      = [NSApplication sharedApplication];
        AppDelegate   *delegate = [[AppDelegate alloc] init];
        [app setDelegate:delegate];

        // Do NOT call NSApplicationMain() — that would load the NIB
        // and fire applicationDidFinishLaunching a second time.
        [app run];
    }
    return 0;
}
