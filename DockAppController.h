#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "DockIcon.h"

@interface DockAppController : NSObject <NSApplicationDelegate>

@property (strong) NSWindow *dockWindow;
@property (strong) NSMutableDictionary *dockedIcons;
@property (strong) NSMutableDictionary *undockedIcons;
@property (strong) NSWorkspace *workspace;
@property CGFloat iconSize;
@property CGFloat activeLight;
@property CGFloat padding;

- (void)setupDockWindow;
- (void)addApplicationIcon:(NSString *)appName withDockedStatus:(BOOL)isDocked;
- (DockIcon *)generateIcon:(NSString *)appName withDockedStatus:(BOOL)isDocked;
- (NSRect)generateLocation:(NSString *)dockPosition forDockedStatus:(BOOL)isDocked;
- (void)addDivider;
- (void)iconClicked:(id)sender;
- (void)dockIcon:(NSString *)appName;
- (void)undockIcon:(NSString *)appName;
- (BOOL)isAppDocked:(NSString *)appName;
- (void)applicationIsLaunching:(NSNotification *)notification;
- (void)applicationDidFinishLaunching:(NSNotification *)notification;
- (void)applicationTerminated:(NSNotification *)notification;
- (void)activeApplicationChanged:(NSNotification *)notification;
- (void)checkForNewActivatedIcons;
- (CGFloat)calculateDockWidth;
- (void)updateDockWindow;


@end

