#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "DockIcon.h"

@interface DockAppController : NSObject <NSApplicationDelegate>

@property (strong) NSWindow *dockWindow;
@property (strong) NSMutableArray *dockedIcons;
@property (strong) NSMutableArray *undockedIcons;
@property (strong) NSWorkspace *workspace;
@property CGFloat iconSize;
@property CGFloat activeLight;
@property CGFloat padding;

- (void)setupDockWindow;
- (void)addApplicationIcon:(NSString *)appName withDockedStatus:(BOOL)isDocked;
- (NSButton *)generateIcon:(NSString *)appName;
- (NSRect)generateLocation:(NSString *)dockPosition;
- (void)addDivider;
- (void)iconClicked:(id)sender;
- (void)dockIcon:(NSString *)appName;
- (void)undockIcon:(NSString *)appName;
- (BOOL)isAppDocked:(NSString *)appName;
- (void)applicationIsLaunching:(NSNotification *)notification;
- (void)applicationDidFinishLaunching:(NSNotification *)notification;
- (void)applicationTerminated:(NSNotification *)notification;
- (void)checkForNewActivatedIcons;


@end

