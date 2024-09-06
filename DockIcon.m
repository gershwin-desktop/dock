#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "DockIcon.h"
#import "ActiveLight.h"

@implementation DockIcon

- (instancetype) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];

    if (self)
      {
          // _iconImage = nil;
          _appName = @"Unknown";
          _showLabel = YES; // Change this to NO 
          _activeLight = nil; // Change this to NO 
  
        [self setupDockIcon];
      }
    return self;
}

- (void) setupDockIcon
{
    // Do Stuff
    [super setToolTip:_appName];

    // Calculate the frame for the ActiveLight view
    CGFloat lightDiameter = 4.0;
    NSRect bounds = [self bounds];
    // bounds.size.height += 4;

    // Calculate the x and y position to center the ActiveLight horizontally and place it at the bottom
    CGFloat xPosition = NSMidX(bounds) - (lightDiameter / 2.0);
    CGFloat yPosition = bounds.size.height - 4;  // Set a small margin from the bottom edge

    NSRect activeLightFrame = NSMakeRect(xPosition, yPosition, lightDiameter, lightDiameter);
    
    // Instantiate the ActiveLight view
    _activeLight = [[ActiveLight alloc] initWithFrame:activeLightFrame];
    [_activeLight setVisibility:NO];

    
    // Add ActiveLight as a subview to DockIcon
    [self addSubview:_activeLight];
};

- (void) setLabelVisibility:(BOOL) isVisible
{
  self.showLabel = isVisible;
}

- (void) setActiveLightVisibility:(BOOL)isVisible
{
    // Implement visibility toggle in ActiveLight Class
    // Toggle visibility of ActiveLight
    [self.activeLight setVisibility:isVisible];
}

- (NSString *) getAppName
{
  return _appName;
}

- (void) setAppName:(NSString *)name
{
    _appName = name;
    [super setToolTip:_appName]; 
}

- (void) selfDestruct
{
    [self removeFromSuperview];
}

- (void)mouseDown:(NSEvent *)event {
    [super mouseDown:event];

    // Post a notification when DockIcon is clicked
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DockIconClickedNotification"
                                                        object:self
                                                      userInfo:@{@"appName": self.appName}];
}

@end

