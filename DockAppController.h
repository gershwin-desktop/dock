#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "DockGroup.h"
#import "DockIcon.h"
#import "DockDivider.h"

@interface DockAppController : NSObject <NSApplicationDelegate>

@property (strong) NSArray *defaultIcons;
@property (strong) NSString *dockPosition;
@property (strong) NSString *fileManagerAppName;
@property (strong) NSWindow *dockWindow;
@property (strong) NSWorkspace *workspace;

@property (strong) DockGroup *fileManagerGroup;
@property (strong) DockGroup *trashGroup;
@property (strong) DockGroup *dockedGroup;
@property (strong) DockGroup *runningGroup;
@property (strong) DockGroup *placesGroup;

@property (strong) DockDivider *dockedDivider;
@property (strong) DockDivider *runningDivider;

// Style
@property CGFloat iconSize;
@property CGFloat activeLight;
@property CGFloat padding;
@property BOOL isUnified;
@property BOOL showDocked;
@property BOOL showRunning;
@property BOOL showPlaces;

@property DockGroup *dropTarget;

// Dock Window Management
- (void)setupDockWindow;
- (void)updateDockWindow;

// Icon Management
- (void)addDivider;
- (void)iconIsDragging:(NSNotification *)notification;
- (void)iconDropped:(NSString *)appName inGroup:(DockGroup *)dockGroup;
- (void)iconAddedToGroup:(NSNotification *)notification;
- (void)iconRemovedFromWindow:(NSNotification *)notification;

// Workspace Events
- (void)applicationIsLaunching:(NSNotification *)notification;
- (void)applicationDidFinishLaunching:(NSNotification *)notification;
- (void)applicationTerminated:(NSNotification *)notification;
- (void)activeApplicationChanged:(NSNotification *)notification;

// Movers & Helpers
- (void)checkForNewActivatedIcons;
- (CGFloat)calculateDockWidth;
- (BOOL)detectHover:(NSString *)appName inGroup:(DockGroup *)dockGroup currentX:(CGFloat)currentX currentY:(CGFloat)currentY;

// Defaults
- (void)resetDockedIcons;
- (void)saveDockedIconsToUserDefaults;
- (void)loadDockedIconsFromUserDefaults;

// Define methods that will handle events from DockIcon
- (void)iconMouseUp:(id)sender;

@end

