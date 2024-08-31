#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "DockAppController.h"

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        [NSApplication sharedApplication];
        DockAppController *controller = [[DockAppController alloc] init];
        [NSApp setDelegate:controller];
        return NSApplicationMain(argc, argv);
    }
}

