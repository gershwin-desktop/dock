#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "ActiveLight.h"

@interface DockIcon : NSButton 

@property (strong) NSImage *iconImage;
@property (strong) NSString *appName;
@property  BOOL showLabel;
@property (strong) NSWorkspace *workspace;
@property (strong) ActiveLight *activeLight;


- (void)setupDockIcon;

- (void)setLabelVisibility:(BOOL)isVisible;

// - (NSImage *)getIconImage;

// - (void)setIconImage:(NSImage *)iconImage;

- (NSString *)getAppName;

- (void)setAppName:(NSString *)name;

- (void)setActiveLightVisibility:(BOOL)isVisible;

- (void)selfDestruct;

@end

