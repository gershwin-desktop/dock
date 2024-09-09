#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "DockIcon.h"

@interface DockGroup : NSView 

// Placement
@property (strong) NSWindow *dockWindow;
@property (strong) NSArray *defaultIcons;
@property (strong) NSString *dockPosition;
@property (strong) NSString *direction;
@property (strong) NSMutableArray *dockedIcons;
@property CGFloat startX;
@property CGFloat startY;

// Cosmetic Properties
@property CGFloat iconSize;
@property CGFloat activeLight;
@property CGFloat padding;

// Group Properties
@property (strong) NSString *groupName;
@property (strong) NSString *acceptedType;
@property BOOL acceptsIcons;
@property BOOL canDragReorder;
@property BOOL canDragRemove;
@property BOOL canDragMove;
@property (strong) NSString *screenEdge; // set by DockAppController

// Helpers
@property (strong) NSWorkspace *workspace;

// Icon Management
- (DockIcon *) generateIcon:(NSString *)appName withImage:(NSImage *)iconImage;
- (NSRect) generateLocation:(NSString *)dockPosition atIndex:(CGFloat)index;
- (NSMutableArray *) listIconNames;
- (DockIcon *) addIcon:(NSString *)appName withImage:(NSImage *)iconImage;
- (void) removeIcon:(NSString *)appName;

// Movers & Helpers
- (BOOL) hasIcon:(NSString *)appName;
- (void) setIconActive:(NSString *)appName;
- (void) setIconTerminated:(NSString *)appName;
- (NSUInteger) indexOfIcon:(NSString *)appName;
- (BOOL) isAppRunning:(NSString *)appName;
- (void) updateFrame;

- (CGFloat) calculateDockWidth;
- (DockIcon *) getIconByName:(NSString *)appName;
- (void) updateIconPositions:(NSUInteger)startIndex expandDock:(BOOL)isExpanding;

// Getters & Setters
- (NSString *)  getGroupName;
- (void)  setGroupName:(NSString *)groupName;

@end

