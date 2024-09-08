#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "DockGroup.h"
#import "DockIcon.h"

@interface DockAppController : NSObject <NSApplicationDelegate>

@property (strong) NSArray *defaultIcons;
@property (strong) NSString *dockPosition;
@property (strong) NSWindow *dockWindow;
@property (strong) NSWorkspace *workspace;
@property (strong) DockGroup *dockedGroup;
@property (strong) DockGroup *runningGroup;
@property (strong) DockGroup *placesGroup;

// Style
@property CGFloat iconSize;
@property CGFloat activeLight;
@property CGFloat padding;
@property BOOL isUnified;
@property BOOL showDocked;
@property BOOL showRunning;
@property BOOL showPlaces;

// Dock Window Management
- (void)setupDockWindow;
- (void)updateDockWindow;

// Icon Management
- (void)addDivider;
- (void)iconClicked:(NSNotification *)notification;
- (void)iconDropped:(NSNotification *)notification;
- (void)iconAddedToGroup:(NSNotification *)notification;

// Workspace Events
- (void)applicationIsLaunching:(NSNotification *)notification;
- (void)applicationDidFinishLaunching:(NSNotification *)notification;
- (void)applicationTerminated:(NSNotification *)notification;
- (void)activeApplicationChanged:(NSNotification *)notification;

// Movers & Helpers
- (void)checkForNewActivatedIcons;
- (CGFloat)calculateDockWidth;

// Defaults
- (void)resetDockedIcons;
- (void)saveDockedIconsToUserDefaults:(BOOL)reset;
- (void)loadDockedIconsFromUserDefaults;

@end

