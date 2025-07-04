#import "ActiveLight.h"
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

@interface DockIcon : NSButton <NSDraggingSource>

@property CGFloat iconSize;
@property CGFloat activeLightDiameter;
;
@property CGFloat iconSizeMultiplier;
@property (strong) NSImage *iconImage;
@property (strong) NSString *appName;
@property BOOL showLabel;
@property (strong) NSWindow *dragWindow;
@property BOOL isDragging;
@property BOOL isDragEnabled;
@property (strong) NSWorkspace *workspace;
@property (strong) ActiveLight *activeLight;

// Define properties to store target and actions
@property (nonatomic, weak) id target;
@property (nonatomic) SEL mouseUpAction;

- (void)setupDockIcon;

- (void)setLabelVisibility:(BOOL)isVisible;

- (NSImage *)getIconImage;

- (void)setIconImage:(NSImage *)iconImage;

- (CGFloat)getIconSize;

- (void)setIconSize:(CGFloat)iconSize;

- (NSString *)getAppName;

- (void)setAppName:(NSString *)name;

- (void)setActiveLightVisibility:(BOOL)isVisible;

- (void)selfDestruct;

@end
