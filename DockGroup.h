#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "DockIcon.h"

@class DockAppController;  // Forward declaration

@interface DockGroup : NSView 

@property (nonatomic, weak) DockAppController *controller; // Required for Target-Action

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
@property BOOL hoverEngaged;
@property BOOL isSwapping;


// Icon Management
- (DockIcon *) addIcon:(NSString *)appName withImage:(NSImage *)iconImage atIndex:(NSUInteger)index;
- (void) removeIcon:(NSString *)appName;
- (DockIcon *) generateIcon:(NSString *)appName withImage:(NSImage *)iconImage atIndex:(NSUInteger)index;
- (NSRect) generateLocation:(NSString *)dockPosition atIndex:(CGFloat)index;
- (NSMutableArray *) listIconNames;

// Movers & Helpers
- (BOOL) hasIcon:(NSString *)appName;
- (void) setIconActive:(NSString *)appName;
- (void) setIconTerminated:(NSString *)appName;
- (NSUInteger) indexOfIcon:(NSString *)appName;
- (void) updateFrame;

// Hover Effects
- (void)onHover:(NSString *)appName fromOtherGroup:(BOOL)isExternal;
- (void)startHover:(NSUInteger)index fromOtherGroup:(BOOL)isExternal;
- (void)endHover;
- (NSImage *)createPlaceholderImage;

- (CGFloat) calculateDockWidth;
- (DockIcon *) getIconByName:(NSString *)appName;
- (void) updateIconPositions:(NSUInteger)startIndex expandDock:(BOOL)isExpanding;
- (void) swapIconPositions:(NSUInteger)draggedIndex withEmptyIndex:(NSUInteger)emptyIndex;

// Getters & Setters
- (NSString *)  getGroupName;
- (void)  setGroupName:(NSString *)groupName;

@end

