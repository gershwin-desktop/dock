#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

@interface DockDivider : NSView

// Placement
// @property (strong) NSWindow *dockWindow;
@property (strong) NSString *dockPosition;
@property (strong) NSString *direction;

// Cosmetic Properties
@property CGFloat length;
@property CGFloat padding;

// Group Properties
@property (strong) NSString *groupName;
@property (strong) NSString *screenEdge; // set by DockAppController

// Helpers
@property (strong) NSWorkspace *workspace;

// Drawing Management
- (void)updateFrame;

// Getters & Setters
- (NSString *)getGroupName;
- (void)setGroupName:(NSString *)groupName;

@end
