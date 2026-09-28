//
//  main.m
//  TCD Store
//
//  From the tcd-store-beta base, with one fix: the activation policy.
//
//  Everything here is built in code, so there is no NIB to load and
//  NSApplicationMain() is not used -- calling it would look for MainMenu.nib
//  and fail. Without a NIB, though, AppKit defaults the policy to
//  NSApplicationActivationPolicyProhibited, which means no Dock icon, no menu
//  bar focus and a window that cannot reliably come to the front. Setting it
//  to Regular is what makes this a normal, switchable app.
//
//  No NSAutoreleasePool is released by hand: the target builds with ARC, which
//  forbids sending -release explicitly, and AppKit installs a pool for the
//  duration of the run loop.
//

#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

int main(int argc, const char *argv[]) {
    (void)argc; (void)argv;

    NSApplication *app = [NSApplication sharedApplication];
    [app setActivationPolicy:NSApplicationActivationPolicyRegular];

    AppDelegate *delegate = [[AppDelegate alloc] init];
    [app setDelegate:delegate];

    [app run];
    return 0;
}
