#import <AppKit/AppKit.h>
#import "DockAppController.h"
#import "DockGroup.h"
#import "DockIcon.h"

@implementation DockGroup

- (instancetype) init
{
    self = [super init]; 
    if (self)
      {
        // Register for string types to allow for dragging DockIcons
        
        [self registerForDraggedTypes:@[
          NSFilenamesPboardType,    // For file URLs
          NSStringPboardType // For our DockIcon instances
        ]];

        _groupName = @"Unknown";
        _workspace = [NSWorkspace sharedWorkspace];
        _dockWindow = nil;
        _defaultIcons = [NSArray arrayWithObjects:@"Workspace", @"Terminal", @"SystemPreferences", nil];
        _dockPosition = @"Bottom";
        _direction = @"Horizontal";
        _startX = 0;
        _startY = 0;
        _dockedIcons = [[NSMutableArray alloc] init];
        _iconSize = 64;
        _activeLight = 10;
        _padding = 16;

        _acceptedType = @"Application";
        _acceptsIcons = NO;
        _canDragReorder = NO;
        _canDragRemove = NO;
        _canDragMove = NO;
        _screenEdge = nil; // set by DockAppController

        _hoverEngaged = NO;
        _isSwapping = NO;
      }
    return self;
}

- (NSString *) getGroupName
{
  return _groupName;
}

- (void) setGroupName:(NSString *)groupName
{
  _groupName = groupName;
}

- (CGFloat) calculateDockWidth
{
    CGFloat dockWidth = [_dockedIcons count] * self.iconSize;
    return dockWidth;
}

// Updates the width of the view
- (void) updateFrame
{
    // Adjust the width
    CGFloat dockWidth = [self calculateDockWidth];

    NSSize newContentSize = [_direction isEqualToString:@"Horizontal"] ? NSMakeSize(dockWidth, self.iconSize) : NSMakeSize(self.iconSize, dockWidth);
    NSRect currentFrame = [self frame]; 
    NSRect newFrame = NSMakeRect(currentFrame.origin.x, 0, newContentSize.width, newContentSize.height);

    [self setFrame:newFrame]; 
    [self setNeedsDisplay:YES];
}

- (void) swapIconPositions:(NSUInteger)draggedIndex withEmptyIndex:(NSUInteger)emptyIndex
{
  NSLog(@"SWAP METHOD");
  if (self.isSwapping)
    {
      return;
    }
  DockIcon *draggedIcon = [self.dockedIcons objectAtIndex:draggedIndex];
  DockIcon *emptyIcon = [self.dockedIcons objectAtIndex:emptyIndex];
  NSLog(@"AFTER CHECK");

  self.isSwapping = YES;
  BOOL swapHorizontal = [self.dockPosition isEqualToString:@"Bottom"];
  if (swapHorizontal)
    {
      // Swap in the view
      NSRect aFrame = [draggedIcon frame];
      NSRect bFrame = [emptyIcon frame];

      NSRect aNewFrame = NSMakeRect(bFrame.origin.x, bFrame.origin.y, aFrame.size.width, aFrame.size.height);
      NSRect bNewFrame = NSMakeRect(aFrame.origin.x, aFrame.origin.y, aFrame.size.width, aFrame.size.height);

      // TODO Animations here
      
      [draggedIcon setFrame:aNewFrame];
      [emptyIcon setFrame:bNewFrame];
      [self updateFrame];
    }
  // Swap in the array

  id temp = [self.dockedIcons objectAtIndex:draggedIndex];
  [self.dockedIcons replaceObjectAtIndex:draggedIndex withObject:[self.dockedIcons objectAtIndex:emptyIndex]];
  [self.dockedIcons replaceObjectAtIndex:emptyIndex withObject:temp];

  self.isSwapping = NO;
}

- (void) updateIconPositions:(NSUInteger)startIndex
                  expandDock:(BOOL)isExpanding
{
    // If isDocked, we need to move subset of dockedIcons and all of the undockedIcons so we create a global array.
    // Otherwise we move subset of undockedIcons only.

    for (NSUInteger i = startIndex; i < [self.dockedIcons count]; i++)
      { 
        DockIcon *dockIcon = [self.dockedIcons objectAtIndex:i];
        NSRect currentFrame = [dockIcon frame];
        // Horizontal adjustments
        if([self.dockPosition isEqualToString:@"Bottom"]) {

          if(isExpanding)
            {
              CGFloat expandedX = currentFrame.origin.x + self.iconSize;          
              NSRect expandedFrame = NSMakeRect(expandedX, currentFrame.origin.y , self.iconSize, self.iconSize);
              [dockIcon setFrame:expandedFrame]; // Replace with tween
            } else {
              CGFloat contractedX = currentFrame.origin.x - self.iconSize;
              NSRect contractedFrame = NSMakeRect(contractedX, currentFrame.origin.y , self.iconSize, self.iconSize);
              [dockIcon setFrame:contractedFrame]; // Replace with tween
            } 
  
        }

      }   
}

- (DockIcon *) addIcon:(NSString *)appName withImage:(NSImage *)iconImage atIndex:(NSUInteger)index
{
    DockIcon *dockIcon = [self generateIcon:appName withImage:iconImage atIndex:index];
    [self.dockedIcons insertObject:dockIcon atIndex:index];
    [self addSubview:dockIcon];

    if(index < [self.dockedIcons count])
      { 
        [self updateIconPositions:index + 1 expandDock:YES]; 
      }
    
    [self updateFrame];

    // Force redraw
    [self setNeedsDisplay:YES];

    return dockIcon;
}

- (void) removeIcon:(NSString *)appName
{
    BOOL iconExists = [self hasIcon:appName];
    if (iconExists)
      { 
        NSUInteger index = [self indexOfIcon:appName];
        DockIcon *undockedIcon = [self.dockedIcons objectAtIndex:index];
        NSLog(@"appName = %@ && removing icon named: %@", appName, [undockedIcon getAppName]);
        [self.dockedIcons removeObjectAtIndex:index];
        [undockedIcon selfDestruct];

        // Update Undocked Icons
        if(index < [self.dockedIcons count])
        {}
        [self updateIconPositions:index expandDock:NO]; 
        [self updateFrame];
      } else {
        NSLog(@"Error: Either not found or out of range. Could not remove %@", appName);
      }

    // Force redraw
    [self setNeedsDisplay:YES];
}

- (BOOL) hasIcon:(NSString *)appName
{
    BOOL defaultValue = NO;
    NSUInteger index = [self indexOfIcon:appName];

    if(index != NSNotFound)
      {
        return YES;
      } else {
        return defaultValue;
      }
}

- (NSUInteger) indexOfIcon:(NSString *)appName
{ 
    NSUInteger index = [self.dockedIcons indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        // 'obj' is the current object in the array 
        DockIcon *dockIcon = (DockIcon *)obj;
        
        return [[dockIcon getAppName] isEqualToString:appName];
    }];

    return index;
}

- (DockIcon *) getIconByName:(NSString *)appName
{ 
    NSMutableArray *iconsArray = _dockedIcons;
    NSUInteger index = [self indexOfIcon:appName];
    
    if (index != NSNotFound)
      {
        return [iconsArray objectAtIndex: index];
      } else {
        return nil;
      }
}

- (void) setIconActive:(NSString *)appName
{
  DockIcon *dockIcon = [self.dockedIcons objectAtIndex:[self indexOfIcon:appName]];
  [dockIcon setActiveLightVisibility:YES];
}

- (void) setIconTerminated:(NSString *)appName
{
  DockIcon *dockIcon = [self.dockedIcons objectAtIndex:[self indexOfIcon:appName]];
  [dockIcon setActiveLightVisibility:NO];
}


- (NSRect) generateLocation:(NSString *)dockPosition
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
                    atIndex:(NSUInteger)index
{
    CGFloat iconCount = [self.dockedIcons count];
    NSRect location = [self generateLocation:_dockPosition atIndex:index]; 
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
}

// Events
- (NSMutableArray *)listIconNames
{ 
    NSMutableArray *appNames = [NSMutableArray array];

    for (int i = 0; i < [_dockedIcons count]; i++) {
        DockIcon *dockIcon = [_dockedIcons objectAtIndex:i];
        NSString *appName = [dockIcon getAppName];
        [appNames addObject:appName];
    }
    return appNames;
}


// Drag and drop stuff

// Handle dragging entered into the DockGroup
- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
    NSPasteboard *pasteboard = [sender draggingPasteboard];
    // Handle file drops
    if ([[pasteboard types] containsObject:NSFilenamesPboardType]) {
        NSArray *draggedFilenames = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
        NSString *appBundleName = [[[draggedFilenames objectAtIndex:0] lastPathComponent] stringByDeletingPathExtension];
        BOOL alreadyDocked = [self hasIcon:appBundleName];

        if (!alreadyDocked)
        {
          return NSDragOperationCopy;  // Allow file drops
        }
    }

    // Handle DockIcon drags
    if ([[pasteboard types] containsObject:NSStringPboardType]) {        
        NSString *appName = [pasteboard stringForType:NSStringPboardType];
        BOOL alreadyDocked = [self hasIcon:appName];

        if (!alreadyDocked)
        {
          return NSDragOperationMove;  // Allow moving the DockIcon within DockGroup
        }
    }

    return NSDragOperationNone;
}

// Handle dragging entered into the DockGroup
- (void)draggingExited:(id<NSDraggingInfo>)sender
{
    NSPasteboard *pasteboard = [sender draggingPasteboard];
    if ([[pasteboard types] containsObject:NSFilenamesPboardType])
      {
        NSArray *draggedFilenames = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
        NSString *appBundleName = [[[draggedFilenames objectAtIndex:0] lastPathComponent] stringByDeletingPathExtension];
        BOOL alreadyDocked = [self hasIcon:appBundleName];
      }

    // Handle DockIcon drags
    if ([[pasteboard types] containsObject:NSStringPboardType])
      {
        NSString *appName = [pasteboard stringForType:NSStringPboardType];
        BOOL alreadyDocked = [self hasIcon:appName];
      }
}

// Called after dragging has ended, allowing you to detect if the drag was outside
- (void)draggingEnded:(id<NSDraggingInfo>)sender
{
    NSPoint dropLocation = [sender draggingLocation];
    BOOL isInsideDockGroup = NSPointInRect(dropLocation, self.frame);

    NSPasteboard *pasteboard = [sender draggingPasteboard];
    if ([[pasteboard types] containsObject:NSFilenamesPboardType]) {
        NSArray *draggedFilenames = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
        NSString *appBundleName = [[[draggedFilenames objectAtIndex:0] lastPathComponent] stringByDeletingPathExtension];
        BOOL alreadyDocked = [self hasIcon:appBundleName];
    }

    // Handle DockIcon drags
    if ([[pasteboard types] containsObject:NSStringPboardType]) {        
        NSString *appName = [pasteboard stringForType:NSStringPboardType];
        BOOL alreadyDocked = [self hasIcon:appName];
    }
    
}

// Get ready to drop
- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender {
    NSPasteboard *pasteboard = [sender draggingPasteboard];
    if ([[pasteboard types] containsObject:NSFilenamesPboardType])
      {
        return YES;
      }
    if ([[pasteboard types] containsObject:NSStringPboardType])
      {
        return YES;
      }
    return NO;
}


// Perform the drop operation
- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    NSPasteboard *pasteboard = [sender draggingPasteboard];

    // For app bundles from file manager
    if ([[pasteboard types] containsObject:NSFilenamesPboardType])
    {
      NSArray *draggedFilenames = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
      NSString *appName = [[[draggedFilenames objectAtIndex:0] lastPathComponent] stringByDeletingPathExtension];
      BOOL alreadyDocked = [self hasIcon:appName];
  
      if (self.acceptsIcons && [[[draggedFilenames objectAtIndex:0] pathExtension] isEqual:@"app"] && !alreadyDocked)
      {
        [self.controller iconDropped:appName inGroup: self];
        return YES;
      } else {
          return NO;
      }
    }

  
    return NO;
}

// Provide feedback as the dragging session progresses
- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender
{
    return NSDragOperationPrivate;
}

- (NSImage *)createPlaceholderImage
{
  NSSize imageSize = NSMakeSize(64, 64); // 64x64 size

  // Create a new NSImage with the specified size
  NSImage *transparentImage = [[NSImage alloc] initWithSize:imageSize];
  
  // Lock focus on the image to begin drawing
  [transparentImage lockFocus];
  
  // Set the transparent color
  [[NSColor clearColor] set];
  
  // Fill the image with the transparent color
  NSRect imageRect = NSMakeRect(0, 0, imageSize.width, imageSize.height);
  NSRectFill(imageRect);
  
  // Unlock focus to complete the drawing
  [transparentImage unlockFocus];
  
  return transparentImage;
}

- (void)onHover:(NSString *)appName fromOtherGroup:(BOOL)isExternal
{
  if (!self.canDragReorder)
    {
      return;
    }

  self.hoverEngaged = YES;
}

- (void)startHover:(NSUInteger)index fromOtherGroup:(BOOL)isExternal
{
  if (!self.canDragReorder)
    {
      return;
    }

  // Prep the group for hover
  self.hoverEngaged = YES;
}

- (void)endHover
{
  // Clean up placeholder icon
  self.hoverEngaged = NO;
}
@end
