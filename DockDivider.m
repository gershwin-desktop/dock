#import <AppKit/AppKit.h>
#import "DockDivider.h"

@implementation DockDivider


- (instancetype) init
{
    self = [super init]; 
    // self = [super initWithFrame:frameRect];
    if (self)
      {
        _groupName = @"Unknown";
        _workspace = [NSWorkspace sharedWorkspace];
        _dockPosition = @"Bottom";
        _direction = @"Horizontal";
        _length = 64;
        _padding = 16;
        _screenEdge = nil; // set by DockAppController
      }
    return self;
}

- (void) dealloc
{
    // Remove self as an observer to avoid memory leaks
    [[NSNotificationCenter defaultCenter] removeObserver:self]; 
}

// Override drawRect: to draw the line
- (void) drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];

    if ([self.dockPosition isEqualToString:@"Bottom"])
      {
        // Set the fill color to grey
        [[NSColor grayColor] setStroke];

          // Create a new path
        NSBezierPath *linePath = [NSBezierPath bezierPath];
    
        // Set line width to 1 pixel
        [linePath setLineWidth:1.0];
    
        // Define start and end points for the line (vertical line, N pixels tall)
        NSPoint startPoint = NSMakePoint(self.padding, 0);   // Starting point (centered horizontally)
        NSPoint endPoint = NSMakePoint(self.padding, self.length);    // Ending point, N pixels down
    
        // Move to start point and draw a line to the end point
        [linePath moveToPoint:startPoint];
        [linePath lineToPoint:endPoint];
    
        // Stroke the path to actually draw the line
        [linePath stroke];
          
      }
}

- (NSString *) getGroupName
{
  return _groupName;
}

- (void) setGroupName:(NSString *)groupName
{
  _groupName = groupName;
}


- (void) updateFrame
{
    // Adjust the width
    CGFloat dockWidth = 2 * self.padding + 1; //[self calculateDockWidth];
//    NSSize currentContentSize = [self frame].size;
   
    NSSize newContentSize = [_direction isEqualToString:@"Horizontal"] ? NSMakeSize(dockWidth, self.length) : NSMakeSize(self.length, dockWidth);
    NSRect currentFrame = [self frame]; 
    NSRect newFrame = NSMakeRect(currentFrame.origin.x, 0, newContentSize.width, newContentSize.height);

    [self setFrame:newFrame]; 
    [self setNeedsDisplay:YES];
}



/*- (NSRect) generateLocation:(NSString *)dockPosition
                    atIndex:(CGFloat) index
{
    if([dockPosition isEqualToString:@"Left"])
      {
        NSRect leftLocation = NSMakeRect(self.activeLight, [self.dockedIcons count] * self.iconSize + (self.padding), self.iconSize, self.iconSize);
        return leftLocation;
      } else if([dockPosition isEqualToString:@"Right"]) {
        NSRect rightLocation = NSMakeRect(self.activeLight, [self.dockedIcons count] * self.iconSize + (self.padding), self.iconSize, self.iconSize);
        return rightLocation;
      } else {
        // If unset we default to "Bottom"      
        NSRect bottomLocation = NSMakeRect(index * self.iconSize, self.activeLight, self.iconSize, self.iconSize);     
        return bottomLocation;
      }
}

- (DockIcon *) generateIcon:(NSString *)appName
                  withImage:(NSImage *)iconImage
{
    CGFloat iconCount = [self.dockedIcons count];
    NSRect location = [self generateLocation:_dockPosition atIndex:iconCount]; 
    DockIcon *iconButton = [[DockIcon alloc] initWithFrame:location];
    [iconButton setIconSize:self.iconSize];
    [iconButton setIconImage:iconImage];
    [iconButton setAppName:appName];
    [iconButton setBordered:NO];
    iconButton.isDragEnabled = self.canDragMove;

    // Set the DockAppController as the target for the DockIcon events
    iconButton.target = self.controller;  // Reference to DockAppController
    iconButton.mouseUpAction = @selector(iconMouseUp:);

    return iconButton;
}*/

@end
