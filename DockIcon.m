#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "DockGroup.h"
#import "DockIcon.h"
#import "ActiveLight.h"

@implementation DockIcon

NSPoint initialDragLocation;  // Declare instance variable inside @implementation

- (instancetype) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];

    if (self)
      {
          _iconSize = 64;
          _iconSizeMultiplier = 0.75;
          _iconImage = nil;
          _appName = @"Unknown";
          _showLabel = YES; // Change this to NO 
          _activeLight = nil; // Change this to NO
          _activeLightDiameter = 4.0;

          _isDragging = NO;
          _isDragEnabled = NO;
          _dragWindow = nil;
  
        [self setupDockIcon];
      }
    return self;
}

- (void) setupDockIcon
{    
    // Calculate the frame for the ActiveLight view
    NSRect bounds = [self bounds];

    [self setTitle:@""]; // Remove NSButton label
    [self setBordered:NO]; // No borders
    // [self setBezelStyle:NSBezelStyleRegularSquare];


    // Calculate the x and y position to center the ActiveLight horizontally and place it at the bottom
    CGFloat xPosition = NSMidX(bounds) - (self.activeLightDiameter / 2.0);
    CGFloat yPosition = bounds.size.height - 4;  // Set a small margin from the bottom edge

    NSRect activeLightFrame = NSMakeRect(xPosition, yPosition, self.activeLightDiameter, self.activeLightDiameter);
    
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
}

- (NSImage *) getIconImage
{
  return _iconImage;
}

- (void) setIconImage:(NSImage *)iconImage
{
    _iconImage = iconImage;
    [self setNeedsDisplay:YES];
}

- (CGFloat) getIconSize
{
  return _iconSize;
}

- (void) setIconSize:(CGFloat)iconSize
{
  // We actually make ths icon size a little smaller to account for the activity light
  _iconSize = iconSize * _iconSizeMultiplier;
  [self setNeedsDisplay:YES];
}

- (void) selfDestruct
{
    [self removeFromSuperview];
}

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];

    if (self.iconImage && !_isDragging)
    {        
        NSSize fixedSize = NSMakeSize(self.iconSize, self.iconSize);

        // Calculate the position to center the image in the view
        NSRect bounds = self.bounds;
        CGFloat xPosition = (NSWidth(bounds) - fixedSize.width) / 2;
        CGFloat yPosition = (NSHeight(bounds) - fixedSize.height) / 2;
        NSRect imageRect = NSMakeRect(xPosition, yPosition, fixedSize.width, fixedSize.height);

        // Save the current graphics state
        [[NSGraphicsContext currentContext] saveGraphicsState];

        // Apply a vertical flip transformation to fix the upside-down image issue
        NSAffineTransform *transform = [NSAffineTransform transform];
        [transform translateXBy:0 yBy:NSHeight(bounds)];
        [transform scaleXBy:1.0 yBy:-1.0];
        [transform concat];

        // Explicitly draw a rectangular path without rounded corners
        [[NSColor clearColor] setFill]; // Make sure there's no background fill
        NSBezierPath *rectPath = [NSBezierPath bezierPathWithRect:imageRect]; // No rounded corners
        [rectPath fill];

        // Draw the iconImage within the fixed 64x64 rect
        [self.iconImage drawInRect:imageRect
                          fromRect:NSZeroRect
                         operation:NSCompositeSourceOver  // Use NSCompositeSourceOver for GNUstep
                          fraction:1.0];

        // Restore the previous graphics state
        [[NSGraphicsContext currentContext] restoreGraphicsState];

        // Draw a custom border around the image
        /*[[NSColor blackColor] setStroke]; // Border color
        NSBezierPath *borderPath = [NSBezierPath bezierPathWithRect:imageRect];
        [borderPath setLineWidth:2.0]; // Border thickness
        [borderPath stroke];*/
    }
}


// Events
- (void)mouseDown:(NSEvent *)event
{
    NSLog(@"DockIcon MouseDown EVENT");
    // Capture the initial drag location (in window coordinates)
    initialDragLocation = [event locationInWindow];
}

- (void)mouseUp:(NSEvent *)event
{
    NSLog(@"DockIcon MouseUp EVENT");


    // Call the target's action if set
    if (self.target && [self.target respondsToSelector:self.mouseUpAction])
      {
        [self.target performSelector:self.mouseUpAction withObject:self];
      }
}

- (void)mouseDragged:(NSEvent *)event
{ 
  if (!self.isDragEnabled)
    {
      NSLog(@"Parent group does not allow movement");
      return;
    }

    NSLog(@"DockIcon MouseDragged EVENT");

    _isDragging = YES;
    [self setHidden:YES];

    // Prepare the pasteboard for dragging the DockIcon
    NSPasteboard *pasteboard = [NSPasteboard pasteboardWithName:NSDragPboard];
    [pasteboard declareTypes:@[NSStringPboardType] owner:self];
    
    // Set some identifier or app name for the dragged item
    [pasteboard setString:self.appName forType:NSStringPboardType];

    // Ensure that iconImage is set before dragging
    if (!self.iconImage)
      {
        NSLog(@"No iconImage set for DockIcon");
        return;
      }

    NSLog(@"DockIcon is Dragging...");

    NSPoint dragLocation = [event locationInWindow]; // relative to window
    NSPoint iconOrigin = [self frame].origin;
    NSPoint superViewOrigin = [self.superview frame].origin;
    CGFloat activeLightOffset = self.activeLightDiameter;
    CGFloat offsetX = superViewOrigin.x + iconOrigin.x;
    CGFloat offsetY = superViewOrigin.y + iconOrigin.y + activeLightOffset;
    NSPoint initialOffset = NSMakePoint(dragLocation.x - offsetX, dragLocation.y - offsetY);

    
    // Get the current icon image size
    CGFloat scaled = self.iconSize;
    NSSize newSize = NSMakeSize(scaled, scaled);
    
    //Avoid duplicatess
    if (self.dragWindow)
    {
      self.dragWindow = nil;
    }
    // Create a temporary window for the drag, with the size of the icon image
    self.dragWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(dragLocation.x, dragLocation.y, newSize.width, newSize.height)
                                                       styleMask:NSWindowStyleMaskBorderless
                                                         backing:NSBackingStoreBuffered
                                                           defer:NO];

    [self.dragWindow setTitle:@"DockDragWindow"];
    [self.dragWindow setOpaque:NO];
    [self.dragWindow setBackgroundColor:[NSColor clearColor]];
    [self.dragWindow setReleasedWhenClosed:NO];

    // Create an NSImageView to hold the icon image with its original size
    NSImageView *imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, newSize.width, newSize.height)];
    NSImage *dragImage = [self drawImage:self.iconImage withSize:newSize];
    [imageView setImage:dragImage];

    [self.dragWindow.contentView addSubview:imageView];

    // Make the window visible
    [self.dragWindow makeKeyAndOrderFront:nil];
    NSPoint newDragLocation = [self convertPoint:[event locationInWindow] fromView:nil];

    DockGroup *parentView = self.superview; // Need this because compiler thinks this references NSView
    NSString *gName = [parentView getGroupName];

    NSLog(@"DOCK ICON PARENT VIEW: %@",[parentView getGroupName]);
    // Broadcast that dragging is about to start
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DockIconIsAboutToDragNotification"
                                                        object:self
                                                      userInfo:@{
                                                    @"appName": self.appName,
                                                    @"parentGroup": [parentView getGroupName],
                                                    @"globalX": [NSString stringWithFormat:@"%f", newDragLocation.x],
                                                    @"globalY": [NSString stringWithFormat:@"%f", newDragLocation.y]
                                                      }];        

    // Move the window as the user drags the mouse
    while ([event type] != NSEventTypeLeftMouseUp) {
        newDragLocation = [NSEvent mouseLocation];
        NSRect windowFrame = [self.dragWindow frame];
        windowFrame.origin.x = newDragLocation.x - initialOffset.x;
        windowFrame.origin.y = newDragLocation.y - initialOffset.y;
        [self.dragWindow setFrame:windowFrame display:YES];

        // Get the next event (match for left mouse dragging or mouse up)
        event = [[self window] nextEventMatchingMask:NSEventMaskFromType(NSEventTypeLeftMouseDragged) |
                                                    NSEventMaskFromType(NSEventTypeLeftMouseUp)];

        [[NSNotificationCenter defaultCenter] postNotificationName:@"DockIconIsDraggingNotification"
                                                            object:self
                                                          userInfo:@{
                                                        @"appName": self.appName,
                                                        @"parentGroup": [parentView getGroupName],
                                                        @"globalX": [NSString stringWithFormat:@"%f", newDragLocation.x],
                                                        @"globalY": [NSString stringWithFormat:@"%f", newDragLocation.y]
                                                          }];        
    }


    // After the drag ends, remove the window
    [self.dragWindow close];

    
    _isDragging = NO;
    [self setHidden:NO];

    // Check if the screen point is inside this window's frame
    if (NSPointInRect(newDragLocation, [[self window] frame]))
      {
        NSLog(@"Inside"); 
        // Put 
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DockIconAddedToGroupNotification"
                                                            object:self
                                                          userInfo:@{
                                                        @"appName": self.appName,
                                                        @"groupName": gName
                                                          }];        
      } else if (!NSPointInRect(newDragLocation, [[self window] frame]) && parentView.canDragRemove)
      {
        // NSLog(@"Outside");
        NSLog(@"Outside of %@", gName);
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DockIconRemovedFromWindowNotification"
                                                            object:self
                                                          userInfo:@{
                                                        @"appName": self.appName,
                                                        @"groupName": [parentView getGroupName]
                                                          }];        
      
        
      }

    // Force a full redraw after dragging
    [self setNeedsDisplay:YES];
    [self setNeedsDisplayInRect:self.bounds];

}

// Specify that this DockIcon supports the private drag operation
- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
    return NSDragOperationPrivate; // Undocumented but works
}

- (BOOL)ignoreModifierKeysWhileDragging
{
    return YES; // Optional, but can simplify drag handling
}

// Do we need this still?
- (NSImage *)drawImage:(NSImage *)image withSize:(NSSize)size
{
    // Create a new image with the provided size
    NSImage *newImage = [[NSImage alloc] initWithSize:size];

    // Lock focus on the new image to draw the original image into it
    [newImage lockFocus];

    [image drawInRect:NSMakeRect(0, 0, size.width, size.height)
             fromRect:NSZeroRect
            operation: NSCompositeSourceOver  // Use NSCompositeSourceOver for GNUstep
             fraction:1.0];

    [newImage unlockFocus];

    // Return the newly created image
    return newImage;
}

@end

