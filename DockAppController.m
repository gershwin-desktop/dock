#import <AppKit/AppKit.h>
#import "DockAppController.h"
#import "DockGroup.h"
#import "DockIcon.h"

@implementation DockAppController

- (instancetype) init
{
    self = [super init];
    if (self)
      {
        _isUnified = YES;
        _fileManagerAppName = @"Workspace";
        _fileManagerGroup = nil;
        _defaultIcons = [NSArray arrayWithObjects:/*@"Workspace",*/ @"Terminal", @"SystemPreferences", nil];
        _dockPosition = @"Bottom";
        
        _showDocked = YES;
        _showRunning = YES;
        _showPlaces = NO;
        
        _workspace = [NSWorkspace sharedWorkspace];  // Initialize the workspace property with the shared instance
        _iconSize = 96;
        _activeLight = 10;
        _padding = 16;

        _dropTarget = nil;

        // EVENTS
        NSNotificationCenter *workspaceNotificationCenter = [self.workspace notificationCenter];
        // Subscribe to the NSWorkspaceWillLaunchApplicationNotification
        [workspaceNotificationCenter addObserver:self
                                        selector:@selector(applicationIsLaunching:)
                                            name:NSWorkspaceWillLaunchApplicationNotification 
                                          object:nil];

        // Subscribe to the NSWorkspaceDidLaunchApplicationNotification
        [workspaceNotificationCenter addObserver:self
                                        selector:@selector(applicationDidFinishLaunching:)
                                            name:NSWorkspaceDidLaunchApplicationNotification 
                                          object:nil];

        // Subscribe to NSWorkspaceDidActivateApplicationNotification: Sent when an application is terminated.
        [workspaceNotificationCenter addObserver:self
                                        selector:@selector(applicationTerminated:)
                                            name:NSWorkspaceDidTerminateApplicationNotification
                                           object:nil];

        // Subscribe to NSApplicationDidBecomeActiveNotification: Sent when an application becomes active.
        [workspaceNotificationCenter addObserver:self
                                        selector:@selector(activeApplicationChanged:)
                                            name:NSApplicationDidBecomeActiveNotification // is NSWorkspaceDidActivateApplicationNotification on MacOS
                                           object:nil];

        // Register to listen for DockGroup updates
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(iconIsDragging:)
                                                     name:@"DockIconIsDraggingNotification"
                                                   object:nil];

        // Register to listen for DockGroup updates
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(iconAddedToGroup:)
                                                     name:@"DockIconAddedToGroupNotification"
                                                   object:nil];

        // Register to listen for DockGroup updates
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(iconRemovedFromWindow:)
                                                     name:@"DockIconRemovedFromWindowNotification"
                                                   object:nil];
        
        [self setupDockWindow];
      }
    return self;
}

- (void) dealloc
{
    // Remove self as an observer to avoid memory leaks
    [[NSNotificationCenter defaultCenter] removeObserver:self]; 
}

- (void) resetDockedIcons
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *appNames = [self.dockedGroup listIconNames];

    [defaults setObject:appNames forKey:@"DockedIcons"];
    [defaults synchronize]; // Optional, to save changes immediately 
}

- (void) saveDockedIconsToUserDefaults
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    // Reset the local array to match user defaults
    /*NSMutableArray *newArray = [[NSMutableArray alloc] init];
    self.dockedGroup.dockedIcons = newArray;
    for (int index = 0; index < [self.defaultIcons count]; index ++) {
      NSString *appName = [self.defaultIcons objectectAtIndex:index];
      [self.dockedGroup addIcon:appName withImage:[self.workspace appIconForApp:appName]];
    }*/
  
    // Reset the NSUserDefaults array
    NSMutableArray *appNames = [self.dockedGroup listIconNames];
    NSLog(@"SAVE DOCK METHOD: APPNAMES = %@", appNames);
    [defaults setObject:appNames forKey:@"DockedIcons"];
    [defaults synchronize]; // Optional, to save changes immediately 
}

- (void) loadDockedIconsFromUserDefaults
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray<NSString *> *retrievedDockedIcons = [defaults objectForKey:@"DockedIcons"];

    if (self.showDocked && [retrievedDockedIcons count] > 0)
      {
      NSLog(@"Defaults Exist");
      for (int i = 0; i < [retrievedDockedIcons count]; i++)
        {
          NSString *iconName = [retrievedDockedIcons objectAtIndex:i];
          NSLog(@"NSUserDefaults found icon for %@", iconName);
          [self.dockedGroup addIcon:[retrievedDockedIcons objectAtIndex:i] withImage:[self.workspace appIconForApp:iconName]];
        }
      // _dockedIcons = newArray;
      [self updateDockWindow];

      } else {
        NSLog(@"Defaults not found. Generating defaults");
        // If NSUserDefaults are missing, reset to defaults
        [self resetDockedIcons];
        [self updateDockWindow];
      }
}

- (void) setupDockWindow
{  
  // Create a dock window without a title bar or standard window buttons 
  CGFloat dockWidth = [self calculateDockWidth];
  // Get the main screen (primary display)
  NSScreen *mainScreen = [NSScreen mainScreen];
  NSRect viewport = [mainScreen frame];
  CGFloat x = (viewport.size.width / 2) - (dockWidth / 2);
  NSRect frame = NSMakeRect(x, 16, dockWidth, 8 + self.activeLight + self.iconSize);  // Set size and position of the dock (x, y, w, h)

  self.dockWindow = [[NSWindow alloc] initWithContentRect:frame
                                                styleMask:NSWindowStyleMaskBorderless
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];
  [self.dockWindow setTitle:@"Dock"];
  [self.dockWindow setLevel:NSFloatingWindowLevel];
  [self.dockWindow setOpaque:NO];
 
  // Set the window's background color with transparency (alpha < 1.0)
  NSColor *semiTransparentColor = [NSColor colorWithCalibratedWhite:0.1 alpha:0.75];
  [self.dockWindow setBackgroundColor:semiTransparentColor];



  if (self.fileManagerAppName)
      {
        self.fileManagerGroup = [[DockGroup alloc] init];  
        self.fileManagerGroup.iconSize = self.iconSize;

        // Permissions
        self.fileManagerGroup.acceptedType = @"Application";
        self.fileManagerGroup.acceptsIcons = NO;
        self.fileManagerGroup.canDragReorder = NO;
        self.fileManagerGroup.canDragRemove = NO;
        self.fileManagerGroup.canDragMove = NO;
        self.fileManagerGroup.screenEdge = self.dockPosition;
        self.fileManagerGroup.controller = self;

        [self.fileManagerGroup setGroupName:@"FileManagerGroup"];
        [[self.dockWindow contentView] addSubview:self.fileManagerGroup];

        // Fetch Docked Apps from Prefs 
        [self.fileManagerGroup addIcon:self.fileManagerAppName withImage:[self.workspace appIconForApp:self.fileManagerAppName]];
      }

  if (self.showDocked)
      {
        self.dockedGroup = [[DockGroup alloc] init];  
        self.dockedGroup.iconSize = self.iconSize;

        // Permissions
        self.dockedGroup.acceptedType = @"Application";
        self.dockedGroup.acceptsIcons = YES;
        self.dockedGroup.canDragReorder = YES;
        self.dockedGroup.canDragRemove = YES;
        self.dockedGroup.canDragMove = YES;
        self.dockedGroup.screenEdge = self.dockPosition;
        self.dockedGroup.controller = self;

        [self.dockedGroup setGroupName:@"DockedGroup"];
        [[self.dockWindow contentView] addSubview:self.dockedGroup];

        // Fetch Docked Apps from Prefs 
        [self loadDockedIconsFromUserDefaults];
      }

  if (self.showRunning)
    {
        self.runningGroup = [[DockGroup alloc] init];  
        self.runningGroup.iconSize = self.iconSize;

        // Permissions
        self.runningGroup.acceptedType = @"Application";
        self.runningGroup.acceptsIcons = NO;
        self.runningGroup.canDragReorder = NO;
        self.runningGroup.canDragRemove = NO;
        self.runningGroup.canDragMove = YES;
        self.runningGroup.screenEdge = self.dockPosition;
        self.runningGroup.controller= self;

        [self.runningGroup setGroupName:@"RunningGroup"];
        [[self.dockWindow contentView] addSubview:self.runningGroup];
    }

  // TODO: Create Dividers

  // Fetch Running Apps from Workspace
  NSArray *runningApps = [self.workspace launchedApplications];
  for (int i = 0; i < [runningApps count]; i++)
    {
      NSString *runningAppName = [[runningApps objectAtIndex: i] objectForKey: @"NSApplicationName"];  
      BOOL isDockIcon = [runningAppName isEqualToString:@"Dock"];
      BOOL isFileManagerIcon = [runningAppName isEqualToString:self.fileManagerAppName];
      if (isFileManagerIcon)
        {
          [self.fileManagerGroup setIconActive:runningAppName];
          continue;
        } else if (!isDockIcon && self.showDocked && self.dockedGroup) {
          BOOL dockedIconExists = [self.dockedGroup hasIcon:runningAppName];
          if (dockedIconExists)
            {
              [self.dockedGroup setIconActive:runningAppName];
            }
        }

      if (self.showRunning && self.runningGroup)
        {
          BOOL runningIconExists = [self.dockedGroup hasIcon:runningAppName];
          if (!runningIconExists)
          {
            [self.runningGroup addIcon:runningAppName withImage:[self.workspace appIconForApp:runningAppName]];
            [self.runningGroup setIconActive:runningAppName];
          }
        }
    }
  
  // TODO: Create Places group

  //Resize Dock Window
  [self updateDockWindow];
  
  [self.dockWindow makeKeyAndOrderFront:nil];
}

- (CGFloat) calculateDockWidth
{ 
  NSLog(@"DockAppController: calculateDockWidth...");
  CGFloat totalIcons = 0;

  // For the file manager
  totalIcons += 1;

  if (self.showDocked && self.dockedGroup)
  {
    totalIcons += [[self.dockedGroup listIconNames] count];
    NSLog(@"Adding Docked Icons");
  }

  if (self.showRunning && self.runningGroup)
  {
    NSLog(@"Adding Running Icons");
    totalIcons += [[self.runningGroup listIconNames] count];
  }

  if (self.showPlaces && self.placesGroup)
  {
    NSLog(@"Adding Places Icons");
    totalIcons += [[self.placesGroup listIconNames] count];
  }

  // For the Trash Can
  // totalIcons += 1;

  CGFloat dockWidth = (self.padding * 2) + (totalIcons * self.iconSize);
  return dockWidth;
}

- (void) updateDockWindow
{
  // Adjust the width
  CGFloat dockWidth = [self calculateDockWidth]; // Contents + padding
  NSSize currentContentSize = [self.dockWindow.contentView frame].size;
  NSSize newContentSize = NSMakeSize(dockWidth, currentContentSize.height); // width, height
  [self.dockWindow setContentSize:newContentSize];

  // Adjust Groups
  CGFloat newGroupX = self.padding;
  if (self.fileManagerGroup)
  {
    NSRect fileManagerFrame = [self.fileManagerGroup frame];
    NSRect newDockedFrame = NSMakeRect(newGroupX, fileManagerFrame.origin.y, fileManagerFrame.size.width, fileManagerFrame.size.height);
    [self.fileManagerGroup setFrame:newDockedFrame];

    // Update X for next check
    newGroupX += fileManagerFrame.size.width;
  }

  if (self.showDocked && self.dockedGroup)
  {
    NSRect dockedFrame = [self.dockedGroup frame];
    NSRect newDockedFrame = NSMakeRect(newGroupX, dockedFrame.origin.y, dockedFrame.size.width, dockedFrame.size.height);
    [self.dockedGroup setFrame:newDockedFrame];

    // Update X for next check
    newGroupX += dockedFrame.size.width;
  }

  if (self.showRunning && self.runningGroup)
  {
    NSRect runningFrame = [self.runningGroup frame];
    NSRect newRunningFrame = NSMakeRect(newGroupX, runningFrame.origin.y, runningFrame.size.width, runningFrame.size.height);
    [self.runningGroup setFrame:newRunningFrame];

    // Update X for next check
    newGroupX += runningFrame.size.width;
  }

  if (self.showPlaces && self.placesGroup)
  {
    NSRect placesFrame = [self.runningGroup frame];
    placesFrame.origin.x = newGroupX;

    // Update X for next check
    newGroupX += placesFrame.size.width;
  }

  /*if (self.trashGroup)
  {
    NSRect trashFrame = [self.trashGroup frame];
    NSRect newDockedFrame = NSMakeRect(newGroupX, trashFrame.origin.y, trashFrame.size.width, trashFrame.size.height);
    [self.trashGroup setFrame:newDockedFrame];

    // Update X for next check
    newGroupX += trashFrame.size.width;
  }*/

  // Center on screen  
  NSScreen *mainScreen = [NSScreen mainScreen];
  NSRect viewport = [mainScreen frame];
  CGFloat newX = (viewport.size.width / 2) - (dockWidth / 2);
  NSRect currentFrame = [self.dockWindow.contentView frame];
  NSRect newFrame = NSMakeRect(newX, self.padding, currentFrame.size.width, currentFrame.size.height);
  [self.dockWindow setFrame:newFrame display:YES];
}

- (void) addDivider
{
  // TODO
}

- (void) checkForNewActivatedIcons
{
  // Update Dock Icons Arrays
  NSLog(@"checkForNewActivatedIcons Method...");
  // Get the list of running applications
  NSArray *runningApps = [self.workspace launchedApplications];
  for (int i = 0; i < [runningApps count]; i++)
    {
      NSString *runningAppName = [[runningApps objectAtIndex: i] objectForKey: @"NSApplicationName"];
      BOOL isDockIcon = [runningAppName isEqualToString:@"Dock"];
      BOOL isFileManagerIcon = [runningAppName isEqualToString:self.fileManagerAppName];

      BOOL isDocked = [self.dockedGroup hasIcon:runningAppName];
      if (isFileManagerIcon)
        {
          [self.fileManagerGroup setIconActive:runningAppName];
        } else if (!isDockIcon && isDocked && self.showDocked) {
          [self.dockedGroup setIconActive:runningAppName];
        } else if (!isDocked && self.showRunning && self.runningGroup) {
          NSLog(@"Finding undockedIcon for %@ at index %lu", runningAppName, (long)[self.runningGroup indexOfIcon:runningAppName]);
        }
    }
}

- (BOOL) isAppRunning:(NSString *)appName
{
  NSArray *runningApps = [self.workspace launchedApplications];
  NSLog(@"Is app running method...");
  for (int i = 0; i < [runningApps count]; i++)
    {      
      NSString *runningAppName = [[runningApps objectAtIndex: i] objectForKey: @"NSApplicationName"];
      if ([runningAppName isEqualToString:appName])
        {
          NSLog(@"%@ is running", runningAppName);
          return YES;
        }
    }

  return NO;
}

// Events
// We receive DockIcon movement events directly using target-action paradigm.
// The actual drops use notification center since they are not as time sensitive

- (void)iconMouseUp:(id)sender {
    // Handle mouse up event
    NSLog(@"DockIcon mouse up event received by DockAppController.");
    
    NSString *appName = [sender getAppName];
    
    if ([appName isEqualToString:@"Trash"])
      {
        // TODO Pull up Trash UI
      }
    
    if ([appName isEqualToString:@"Dock"])
      {
        // IGNORE this app if it comes up in the list
        return;
      } else {
        [self.workspace launchApplication:appName];
      }

    if (self.isUnified)
      {
        [self updateDockWindow];
      }
}


// Called by DockGroup when Drop source is an external app
- (void) iconDropped:(NSString *)appName inGroup:(DockGroup *)dockGroup
{
    // NSString *appName = notification.userInfo[@"appName"];
    BOOL isRunning = [self.runningGroup hasIcon:appName];
   
    // Add it to the docked group
    if (dockGroup.acceptsIcons)
    {
      [dockGroup addIcon:appName withImage:[self.workspace appIconForApp:appName]];
    }

    // If it's in the running group then remove it
    if (self.showRunning && self.runningGroup)
    {
      if (isRunning)
      {
        [self.runningGroup removeIcon:appName]; 
        [self.dockedGroup setIconActive:appName];
      }
    }
    
    if (self.isUnified)
      {
        [self updateDockWindow];
      }

    if([[self.dockedGroup getGroupName] isEqualToString:[dockGroup getGroupName]])
      {
        [self saveDockedIconsToUserDefaults];
      }
}

// Drop source is from inside Dock app
- (void) iconAddedToGroup:(NSNotification *)notification
{
    NSLog(@"CONTROLLER CALLBACK");

    if (!self.dropTarget)
      {
        NSLog(@"Drop Target is NIL");
        self.dropTarget = nil;
        return;
      } else if (!self.dropTarget.acceptsIcons)
      {
        NSString *targetName = [self.dropTarget getGroupName];
        NSLog(@"Drop Target %@ DOES NOT ACCEPT ICONS", targetName);
        self.dropTarget = nil;
        return;
      }


    NSString *appName = notification.userInfo[@"appName"];
    NSString *groupName = [self.dropTarget getGroupName];
    BOOL isRunning = [self.runningGroup hasIcon:appName];

    // Avoid Duplicates
    if ([self.dropTarget hasIcon:appName])
    {
      self.dropTarget = nil;
      return;
    }

    NSLog(@"Controller: App %@ is being added to group %@", appName, groupName);

   
    if ([groupName isEqualToString:[self.dockedGroup getGroupName]])
    {
      // Add it to the docked group
      [self.dockedGroup addIcon:appName withImage:[self.workspace appIconForApp:appName]];
  
      // If it's in the running group then remove it
      if (self.showRunning && self.runningGroup)
      {
        if (isRunning)
        {
          [self.runningGroup removeIcon:appName]; 
          [self.dockedGroup setIconActive:appName];
        }
      }

      [self saveDockedIconsToUserDefaults];
    }
    
    if (self.isUnified)
      {
        [self updateDockWindow];
      }

    self.dropTarget = nil;
}

- (void) iconRemovedFromWindow:(NSNotification *)notification
{
    NSString *appName = notification.userInfo[@"appName"];
    NSString *groupName = notification.userInfo[@"groupName"];
    BOOL isDockedGroup = NO;

    // Group the icon is being removed from
    DockGroup *dockGroup = nil;
    if ([groupName isEqualToString:[self.dockedGroup getGroupName]])
      {
        dockGroup = self.dockedGroup;
        isDockedGroup = YES;
      } else if ([groupName isEqualToString:[self.runningGroup getGroupName]])
      {
        dockGroup = self.runningGroup;
      } else if ([groupName isEqualToString:[self.placesGroup getGroupName]])
      {
        dockGroup = self.placesGroup;
      }

      if (dockGroup.canDragRemove)
        {
          NSLog(@"App %@ can be removed from group %@...", appName, groupName);
          [dockGroup removeIcon:appName];
          [dockGroup updateFrame];
      
        // If it's in the running group then remove it
        BOOL isRunning = [self isAppRunning:appName];
        if (self.showRunning && self.runningGroup && isRunning)
          {       
            NSLog(@"App %@ is to be removed from the running group ...", appName);
            NSImage *appImage = [self.workspace appIconForApp:appName];
            [self.runningGroup addIcon:appName withImage:appImage];
            [self.runningGroup setIconActive:appName];               
          }
       
        [self checkForNewActivatedIcons];
        if (_isUnified)
          {
            [self updateDockWindow];
          }

        if(isDockedGroup)
          {
            [self saveDockedIconsToUserDefaults];
          }

      }
}

- (void) iconIsDragging:(NSNotification *)notification
{
  NSLog(@"ICON IS DRAGGING METHOD");
    NSString *appName = notification.userInfo[@"appName"];
    NSString *parentGroupName = notification.userInfo[@"parentGroup"];
    NSString *globalX = notification.userInfo[@"globalX"];
    NSString *globalY = notification.userInfo[@"globalY"];
    DockGroup *fromDockGroup = nil;

    if ([parentGroupName isEqualToString:[self.dockedGroup getGroupName]])
      {
        fromDockGroup = self.dockedGroup;
      } else if ([parentGroupName isEqualToString:[self.runningGroup getGroupName]]) {
        fromDockGroup = self.runningGroup;
      } else if ([parentGroupName isEqualToString:[self.placesGroup getGroupName]]) {
        fromDockGroup = self.placesGroup;
      }

    BOOL isOverDocked = [self detectHover:appName inGroup:self.dockedGroup currentX:[globalX floatValue] currentY:[globalY floatValue]];
    if (isOverDocked)
      {
        NSLog(@"OVER DOCKED GROUP");
        self.dropTarget = self.dockedGroup;
        return;
      }

    BOOL isOverRunning = [self detectHover:appName inGroup:self.runningGroup currentX:[globalX floatValue] currentY:[globalY floatValue]];
    if (isOverRunning)
      {
        NSLog(@"OVER RUNNING GROUP");
        self.dropTarget = self.runningGroup;
        return;
      }

}

// When this Dock app has finished launching
- (void) applicationDidFinishLaunching:(NSNotification *)notification
{

    NSDictionary *userInfo = [notification userInfo];
    NSString *appName = userInfo[@"NSApplicationName"];
    if (appName)
      {
        if ([appName isEqualToString:@"Dock"]) 
        {
            return;
        }


        if ([appName isEqualToString:self.fileManagerAppName])
          {
            [self.fileManagerGroup setIconActive: self.fileManagerAppName];
            return;
          }
  
        // Manage the undocked list here
        BOOL isDocked = _showDocked ? [self.dockedGroup hasIcon:appName] : NO;
        if (self.showDocked && isDocked)
          {
            [self.dockedGroup setIconActive:appName];
          } else if (_showRunning && !isDocked) {
            [self.runningGroup addIcon:appName withImage:[self.workspace appIconForApp:appName]];
            [self.runningGroup setIconActive:appName];
          }

        if(_isUnified)
        {
          [self updateDockWindow];
        }
      } else {
        NSLog(@"Application launched, but could not retrieve name.");
      }

    // TODO: STOP BOUNCE
    NSLog(@"Stop the bounce");
}

- (void) applicationIsLaunching:(NSNotification *)notification
{
    // TODO: ICON BOUNCE
    NSLog(@"Get ready to bounce"); 
}

- (void) applicationTerminated:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    NSString *appName = userInfo[@"NSApplicationName"];
    if (appName)
      {
        BOOL isDocked = self.showDocked ? [self.dockedGroup hasIcon:appName] : NO;
        if (isDocked)
        {
          [self.dockedGroup setIconTerminated:appName];
          NSLog(@"DockAppController: setIconTerminated %@", appName);
        } else if (_showRunning && !isDocked) {
          [self.runningGroup removeIcon:appName];
          NSLog(@"DockAppController: removeIcon %@", appName);
        }

        if (_isUnified)
        {
          [self updateDockWindow];
        }

      } else {
        NSLog(@"Application terminated, but could not retrieve name.");
      }
}

- (void) activeApplicationChanged:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    NSString *appName = userInfo[@"NSApplicationName"];
    if (appName)
      {
        NSLog(@"%@ is active", appName);
      } else {
        NSLog(@"Active application changed, but could not retrieve name.");
      }
}

- (BOOL)detectHover:(NSString *)appName inGroup:(DockGroup *)dockGroup currentX:(CGFloat)currentX currentY:(CGFloat)currentY
{
  BOOL isOverGroup = NO; // default to negative
  NSPoint globalPoint = NSMakePoint(currentX, currentY);
  NSRect globalDockGroupFrame = [[dockGroup window] convertRectToScreen:[dockGroup frame]];
  isOverGroup = NSPointInRect(globalPoint, globalDockGroupFrame); 

  if (isOverGroup)
  {
    NSLog(@"Icon %@ is over group %@", appName, [dockGroup getGroupName]);
  }

  return isOverGroup;
}

@end
