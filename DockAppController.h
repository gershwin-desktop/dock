#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "DockIcon.h"

@interface DockAppController : NSObject <NSApplicationDelegate>

@property (strong) NSString *dockPosition;
@property (strong) NSWindow *dockWindow;
@property (strong) NSMutableArray *dockedIcons;
@property (strong) NSMutableArray *undockedIcons;
@property (strong) NSWorkspace *workspace;
@property CGFloat iconSize;
@property CGFloat activeLight;
@property CGFloat padding;

// Dock Window Management
- (void)setupDockWindow;
- (void)updateDockWindow;

// Icon Management
// - (void)addApplicationIcon:(NSString *)appName withDockedStatus:(BOOL)isDocked; // DEPRECATED
- (DockIcon *)generateIcon:(NSString *)appName withDockedStatus:(BOOL)isDocked;
- (NSRect)generateLocation:(NSString *)dockPosition forDockedStatus:(BOOL)isDocked atIndex:(CGFloat)index;
- (void)addDivider;
- (void)iconClicked:(id)sender;
- (DockIcon *)addIcon:(NSString *)appName toDockedArray:(BOOL)isDocked;
- (void)removeIcon:(NSString *)appName fromDockedArray:(BOOL)isDocked;

// Workspace Events
- (void)applicationIsLaunching:(NSNotification *)notification;
- (void)applicationDidFinishLaunching:(NSNotification *)notification;
- (void)applicationTerminated:(NSNotification *)notification;
- (void)activeApplicationChanged:(NSNotification *)notification;

// Movers & Helpers
- (BOOL)isIconDocked:(NSString *)appName;
// - (BOOL)isAppRunning:(NSString *)appName;
- (NSUInteger)indexOfIcon:(NSString *)appName byDockedStatus:(BOOL)isDocked;
- (void)checkForNewActivatedIcons;
- (CGFloat)calculateDockWidth;
- (DockIcon *)getIconByName:(NSString *)appName withDockedStatus:(BOOL)isDocked;
- (void)updateIconPositions:(NSUInteger)startIndex fromDockedIcons:(BOOL)isDocked expandDock:(BOOL)isExpanding;


@end

