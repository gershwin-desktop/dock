#import <AppKit/AppKit.h>
#import "DockAppController.h"
#import "DockDivider.h"
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
        _trashGroup = nil;
        _dockedDivider = nil;
        _runningDivider = nil;
        _defaultIcons = [NSArray arrayWithObjects:/*@"Workspace",*/ @"Terminal", @"SystemPreferences", nil];
        _dockPosition = @"Bottom";
        
        _showDocked = YES;
        _showRunning = YES;
        _showPlaces = NO;
        
        _workspace = [NSWorkspace sharedWorkspace];  // Initialize the workspace property with the shared instance
        _iconSize = 64;
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
                                                 selector:@selector(iconIsAboutToDrag:)
                                                     name:@"DockIconIsAboutToDragNotification"
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

- (void) resetDockedIcons
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    [defaults setObject:self.defaultIcons forKey:@"DockedIcons"];
    [defaults synchronize]; // Optional, to save changes immediately 
}

- (void) saveDockedIconsToUserDefaults
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
  
    // Reset the NSUserDefaults array
    NSMutableArray *appNames = [self.dockedGroup listIconNames];

    [defaults setObject:appNames forKey:@"DockedIcons"];
    [defaults synchronize]; // Optional, to save changes immediately 
}

- (void) loadDockedIconsFromUserDefaults
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray<NSString *> *retrievedDockedIcons = [defaults objectForKey:@"DockedIcons"];

    if (self.showDocked && [retrievedDockedIcons count] > 0)
      {
        for (NSUInteger i = 0; i < [retrievedDockedIcons count]; i++)
          {
            NSString *iconName = [retrievedDockedIcons objectAtIndex:i];
            [self.dockedGroup addIcon:[retrievedDockedIcons objectAtIndex:i] withImage:[self.workspace appIconForApp:iconName] atIndex:i];
          }

        // [self updateDockWindow];
      } else {
        // If NSUserDefaults are missing, reset to defaults
        [self resetDockedIcons];
        for (NSUInteger i = 0; i < [self.defaultIcons count]; i++)
          {
            NSString *iconName = [self.defaultIcons objectAtIndex:i];
            [self.dockedGroup addIcon:[self.defaultIcons objectAtIndex:i] withImage:[self.workspace appIconForApp:iconName] atIndex:i];
          }
        // [self updateDockWindow];
      }
}

- (void) setupDockWindow
{  
  // Create a dock window without a title bar or standard window buttons 
  CGFloat dockWidth = [self calculateDockWidth];
  CGFloat dockHeight = 8 + self.activeLight + self.iconSize;
  // Get the main screen (primary display)
  NSScreen *mainScreen = [NSScreen mainScreen];
  NSRect viewport = [mainScreen frame];
  CGFloat x = (viewport.size.width / 2) - (dockWidth / 2);
  NSRect frame = NSMakeRect(x, 16, dockWidth, dockHeight);  // Set size and position of the dock (x, y, w, h)

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

  // Create our DockGroups

  // File Manager Group
  if (self.fileManagerAppName)
      {
        // We use our own icon
        // Get the path to the icon file from the Resources directory
        NSString *iconImagePath = [[NSBundle mainBundle] pathForResource:@"Home" ofType:@"png"];

        // Create an NSImage object from the .icns file
        NSImage *appIcon = [[NSImage alloc] initWithContentsOfFile:iconImagePath];

        self.fileManagerGroup = [[DockGroup alloc] init];  
        self.fileManagerGroup.iconSize = self.iconSize;
        self.fileManagerGroup.dockPosition = self.dockPosition;

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
        [self.fileManagerGroup addIcon:self.fileManagerAppName withImage:appIcon atIndex:[[self.fileManagerGroup listIconNames] count]];
      }

  if (self.showDocked)
      {
        self.dockedGroup = [[DockGroup alloc] init];  
        self.dockedGroup.iconSize = self.iconSize;
        self.dockedGroup.dockPosition = self.dockPosition;

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

        // Divider
        self.dockedDivider = [[DockDivider alloc] init];
        self.dockedDivider.length = dockHeight - (2 * self.padding);
        [self.dockedDivider setNeedsDisplay:YES];
        self.dockedDivider.dockPosition = self.dockPosition;
        self.dockedDivider.padding = self.padding;
        [self.dockedDivider updateFrame];
        [self.dockedDivider setGroupName:@"Docked"];

        NSRect dockedDividerFrame = [self.dockedDivider frame];
        NSRect newDockedDividerFrame = NSMakeRect(0, self.padding, dockedDividerFrame.size.width, dockedDividerFrame.size.height);
        [self.dockedDivider setFrame:newDockedDividerFrame];
        [[self.dockWindow contentView] addSubview:self.dockedDivider];

      }

  if (self.showRunning)
    {
        self.runningGroup = [[DockGroup alloc] init];  
        self.runningGroup.iconSize = self.iconSize;
        self.runningGroup.dockPosition = self.dockPosition;

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

        // Divider
        self.runningDivider = [[DockDivider alloc] init];
        self.runningDivider.length = dockHeight - (2 * self.padding);
        [self.runningDivider setNeedsDisplay:YES];
        self.runningDivider.dockPosition = self.dockPosition;
        self.runningDivider.padding = self.padding;
        [self.runningDivider updateFrame];
        [self.runningDivider setGroupName:@"Running"];

        NSRect runningDividerFrame = [self.runningDivider frame];
        NSRect newDockedDividerFrame = NSMakeRect(0, self.padding, runningDividerFrame.size.width, runningDividerFrame.size.height);
        [self.runningDivider setFrame:newDockedDividerFrame];
        [[self.dockWindow contentView] addSubview:self.runningDivider];

    }

  if (self.showPlaces)
    {
        self.placesGroup = [[DockGroup alloc] init];  
        self.placesGroup.iconSize = self.iconSize;
        self.placesGroup.dockPosition = self.dockPosition;

        // Permissions
        self.placesGroup.acceptedType = @"Application";
        self.placesGroup.acceptsIcons = NO;
        self.placesGroup.canDragReorder = NO;
        self.placesGroup.canDragRemove = NO;
        self.placesGroup.canDragMove = YES;
        self.placesGroup.screenEdge = self.dockPosition;
        self.placesGroup.controller= self;

        [self.placesGroup setGroupName:@"PlacesGroup"];
        [[self.dockWindow contentView] addSubview:self.placesGroup];
    }

  // Trash Group
  if (self)
      {
        // We use our own icon
        // Get the path to the icon file from the Resources directory
        NSString *trashImagePath = [[NSBundle mainBundle] pathForResource:@"Trash" ofType:@"png"];

        // Create an NSImage object from the .icns file
        NSImage *trashIcon = [[NSImage alloc] initWithContentsOfFile:trashImagePath];

        self.trashGroup = [[DockGroup alloc] init];  
        self.trashGroup.iconSize = self.iconSize;
        self.trashGroup.dockPosition = self.dockPosition;

        // Permissions
        self.trashGroup.acceptedType = @"Application";
        self.trashGroup.acceptsIcons = NO;
        self.trashGroup.canDragReorder = NO;
        self.trashGroup.canDragRemove = NO;
        self.trashGroup.canDragMove = NO;
        self.trashGroup.screenEdge = self.dockPosition;
        self.trashGroup.controller = self;

        [self.trashGroup setGroupName:@"TrashGroup"];
        [[self.dockWindow contentView] addSubview:self.trashGroup];

        // Fetch Docked Apps from Prefs 
        [self.trashGroup addIcon:@"Trash" withImage:trashIcon atIndex:[[self.trashGroup listIconNames] count]];
      }


  // Fetch Running Apps from Workspace
  NSArray *runningApps = [self.workspace launchedApplications];
  for (NSUInteger i = 0; i < [runningApps count]; i++)
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
            [self.runningGroup addIcon:runningAppName
                             withImage:[self.workspace appIconForApp:runningAppName]
                               atIndex:[[self.runningGroup listIconNames] count] ];
            [self.runningGroup setIconActive:runningAppName];
          }
        }
    }

  //Resize Dock Window
  [self updateDockWindow];
  
  [self.dockWindow makeKeyAndOrderFront:nil];
}

- (CGFloat) calculateDockWidth
{ 
  CGFloat totalIcons = 0;
  CGFloat totalDividers = 0;

  // For the file manager
  totalIcons += 1;

  if (self.showDocked && self.dockedGroup)
  {
    totalIcons += [[self.dockedGroup listIconNames] count];
    totalDividers += 1;
  }

  if (self.showRunning && self.runningGroup)
  {
    totalIcons += [[self.runningGroup listIconNames] count];
    totalDividers += 1;
  }

  if (self.showPlaces && self.placesGroup)
  {
    totalIcons += [[self.placesGroup listIconNames] count];
  }

  // For the Trash Can
  totalIcons += 1;

  CGFloat dockWidth = (self.padding * 2) + (totalIcons * self.iconSize) + totalDividers * (self.padding * 2 + 1);
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

    NSRect dockedDividerFrame = [self.dockedDivider frame];
    NSRect newDockedDividerFrame = NSMakeRect(newGroupX, dockedDividerFrame.origin.y, dockedDividerFrame.size.width, dockedDividerFrame.size.height);
    [self.dockedDivider setFrame:newDockedDividerFrame];

    newGroupX += [self.dockedDivider frame].size.width;
  }

  if (self.showRunning && self.runningGroup)
  {
    NSRect runningFrame = [self.runningGroup frame];
    NSRect newRunningFrame = NSMakeRect(newGroupX, runningFrame.origin.y, runningFrame.size.width, runningFrame.size.height);
    [self.runningGroup setFrame:newRunningFrame];

    // Update X for next check
    newGroupX += runningFrame.size.width;


    NSRect runningDividerFrame = [self.runningDivider frame];
    NSRect newDockedDividerFrame = NSMakeRect(newGroupX, runningDividerFrame.origin.y, runningDividerFrame.size.width, runningDividerFrame.size.height);
    [self.runningDivider setFrame:newDockedDividerFrame];

    newGroupX += [self.runningDivider frame].size.width;
  }

  if (self.showPlaces && self.placesGroup)
  {
    NSRect placesFrame = [self.runningGroup frame];
    placesFrame.origin.x = newGroupX;

    // Update X for next check
    newGroupX += placesFrame.size.width;
  }

  if (self.trashGroup)
  {
    NSRect trashFrame = [self.trashGroup frame];
    NSRect newDockedFrame = NSMakeRect(newGroupX, trashFrame.origin.y, trashFrame.size.width, trashFrame.size.height);
    [self.trashGroup setFrame:newDockedFrame];
  }

  // Center on screen  
  NSScreen *mainScreen = [NSScreen mainScreen];
  NSRect viewport = [mainScreen frame];
  CGFloat newX = (viewport.size.width / 2) - (dockWidth / 2);
  NSRect currentFrame = [self.dockWindow.contentView frame];
  NSRect newFrame = NSMakeRect(newX, self.padding, currentFrame.size.width, currentFrame.size.height);
  [self.dockWindow setFrame:newFrame display:YES];
}

- (void) checkForNewActivatedIcons
{
  // Get the list of running applications
  NSArray *runningApps = [self.workspace launchedApplications];
  for (int i = 0; i < [runningApps count]; i++)
    {
      NSString *runningAppName = [[runningApps objectAtIndex: i] objectForKey: @"NSApplicationName"];
      BOOL isDockIcon = [runningAppName isEqualToString:@"Dock"];
      if(isDockIcon)
        {
          continue;
        }
      BOOL isFileManagerIcon = [runningAppName isEqualToString:self.fileManagerAppName];

      BOOL isDocked = [self.dockedGroup hasIcon:runningAppName];
      if (isFileManagerIcon)
        {
          [self.fileManagerGroup setIconActive:runningAppName];
        } else if (!isDockIcon && isDocked && self.showDocked) {
          [self.dockedGroup setIconActive:runningAppName];
        } else if (!isDocked && self.showRunning && self.runningGroup) {
          // TODO
        }
    }
}

- (BOOL) isAppRunning:(NSString *)appName
{
  NSArray *runningApps = [self.workspace launchedApplications];

  for (int i = 0; i < [runningApps count]; i++)
    {      
      NSString *runningAppName = [[runningApps objectAtIndex: i] objectForKey: @"NSApplicationName"];
      if ([runningAppName isEqualToString:appName])
        {
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
    NSString *appName = [sender getAppName];
    
    if ([appName isEqualToString:@"Trash"])
      {

        NSString *trashDirectory = [@"~/.Trash" stringByExpandingTildeInPath];
        BOOL success = [[NSWorkspace sharedWorkspace] openFile:trashDirectory];
        
        if (success) {
            NSLog(@"Directory opened successfully.");
        } else {
            NSLog(@"Failed to open directory.");
        }

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
      [dockGroup addIcon:appName withImage:[self.workspace appIconForApp:appName] atIndex:[[dockGroup listIconNames] count]];
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
    if (!self.dropTarget)
      {
        self.dropTarget = nil;
        return;
      } else if (!self.dropTarget.acceptsIcons)
      {
        NSString *targetName = [self.dropTarget getGroupName];

        self.dropTarget = nil;
        return;
      }


    NSString *appName = notification.userInfo[@"appName"];
    NSString *groupName = [self.dropTarget getGroupName];
    BOOL isRunning = [self.runningGroup hasIcon:appName];

   
    if ([groupName isEqualToString:[self.dockedGroup getGroupName]])
    {
      // Reveal hidden icon
      DockIcon *revealedIcon = [self.dropTarget getIconByName:appName];
      if(!revealedIcon)
      {
        NSLog(@"REVEALED ICON NOT FOUND");
      }
      [revealedIcon setHidden:NO];
  
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

    [self.dropTarget endHover];
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
          [dockGroup removeIcon:appName];
          [dockGroup updateFrame];
          [self updateDockWindow];
      
        // If it's in the running group then remove it
        BOOL isRunning = [self isAppRunning:appName];
        if (self.showRunning && self.runningGroup && isRunning)
          {       
            NSImage *appImage = [self.workspace appIconForApp:appName];
            [self.runningGroup addIcon:appName withImage:appImage
                               atIndex:[[self.runningGroup listIconNames] count]];
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

    [self.dropTarget endHover];
    self.dropTarget = nil;
}

- (void) iconIsAboutToDrag:(NSNotification *)notification
{
    NSString *appName = notification.userInfo[@"appName"];
    NSString *parentGroupName = notification.userInfo[@"parentGroup"];
    NSString *globalX = notification.userInfo[@"globalX"];
    NSString *globalY = notification.userInfo[@"globalY"];
  
    DockGroup *fromDockGroup = [self findDockGroupByName:parentGroupName];
    self.dropTarget = fromDockGroup;

    DockIcon *bottomIcon = [self detectIconHover:appName
                                       inGroup:fromDockGroup
                                      currentX:[globalX floatValue]
                                      currentY:[globalY floatValue]];
    [fromDockGroup startHover:[fromDockGroup indexOfIcon:appName] fromOtherGroup:NO];
}

- (void) iconIsDragging:(NSNotification *)notification
{
    NSString *appName = notification.userInfo[@"appName"];
    NSString *parentGroupName = notification.userInfo[@"parentGroup"];
    NSString *globalX = notification.userInfo[@"globalX"];
    NSString *globalY = notification.userInfo[@"globalY"];
    DockGroup *fromDockGroup = [self findDockGroupByName:parentGroupName];

    BOOL isOverDocked = [self detectGroupHover:appName
                                       inGroup:self.dockedGroup
                                      currentX:[globalX floatValue]
                                      currentY:[globalY floatValue]];
    if (isOverDocked)
      {
        if (!self.dropTarget || self.dropTarget != self.dockedGroup)
          {
            self.dropTarget = self.dockedGroup;
          }
        DockIcon *bottomIcon = [self detectIconHover:appName
                                           inGroup:self.dockedGroup
                                          currentX:[globalX floatValue]
                                          currentY:[globalY floatValue]];

        // If it doesn't exist, we preemptively add the dragged icon to docked icons group
        // and hide it so it looks like a gap
        if (![self.dropTarget hasIcon:appName])
          {
            DockIcon *draggedIcon = [fromDockGroup getIconByName:appName];
            [self.dropTarget addIcon:appName withImage:draggedIcon.iconImage
                                atIndex:[self.dropTarget indexOfIcon:bottomIcon.appName]];
            [[self.dockedGroup getIconByName:appName] setHidden:YES];
            [self.dropTarget updateFrame];
            [self updateDockWindow];            
          }

        BOOL isFromOtherGroup = (fromDockGroup.groupName == self.dropTarget.groupName);

        if ([[bottomIcon getAppName] isEqualToString:appName] == NO)
          {
            [self.dockedGroup swapIconPositions:[self.dockedGroup indexOfIcon:[bottomIcon getAppName]]
                                withEmptyIndex:[self.dockedGroup indexOfIcon:appName]];
          }
        return;
      }

    BOOL isOverRunning = [self detectGroupHover:appName
                                        inGroup:self.runningGroup
                                       currentX:[globalX floatValue]
                                       currentY:[globalY floatValue]];
    if (isOverRunning)
      {
        self.dropTarget = self.runningGroup;
        if (![parentGroupName isEqualToString:[self.dockedGroup getGroupName]] && [self.dockedGroup hasIcon:appName])
          {
            [self.dockedGroup removeIcon:appName];
            [self.dockedGroup updateFrame];
            [self updateDockWindow];
          }
        return;
      }

}

- (DockGroup *)findDockGroupByName:(NSString *)groupName
{
    DockGroup *fromDockGroup = nil;


    // Find the dock group with the matching name
    if ([groupName isEqualToString:[self.dockedGroup getGroupName]])
      {
        fromDockGroup = self.dockedGroup;
      } else if ([groupName isEqualToString:[self.runningGroup getGroupName]]) {
        fromDockGroup = self.runningGroup;
      } else if ([groupName isEqualToString:[self.placesGroup getGroupName]]) {
        fromDockGroup = self.placesGroup;
      }

    return fromDockGroup;
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
          } else if (self.showRunning && !isDocked) {
            [self.runningGroup addIcon:appName withImage:[self.workspace appIconForApp:appName] atIndex:[[self.runningGroup listIconNames] count]];
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
}

- (void) applicationIsLaunching:(NSNotification *)notification
{
    // TODO: ICON BOUNCE
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
        } else if (self.showRunning && !isDocked) {
          [self.runningGroup removeIcon:appName];
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
}

- (BOOL)detectGroupHover:(NSString *)appName inGroup:(DockGroup *)dockGroup currentX:(CGFloat)currentX currentY:(CGFloat)currentY
{
  BOOL isOverGroup = NO; // default to negative
  NSPoint globalPoint = NSMakePoint(currentX, currentY);
  NSRect globalDockGroupFrame = [[dockGroup window] convertRectToScreen:[dockGroup frame]];
  isOverGroup = NSPointInRect(globalPoint, globalDockGroupFrame); 

  return isOverGroup;
}

- (DockIcon *)detectIconHover:(NSString *)appName inGroup:(DockGroup *)dockGroup currentX:(CGFloat)currentX currentY:(CGFloat)currentY
{
    // Create a point from the global mouse coordinates
    NSPoint globalPoint = NSMakePoint(currentX, currentY);

    // Get the window of the DockGroup
    NSWindow *dockGroupWindow = dockGroup.window;

    // Convert the global point to window coordinates (relative to the window's content view)
    NSPoint windowPoint = [dockGroupWindow convertScreenToBase:globalPoint];

    // Convert the window point to DockGroup's local coordinates
    NSPoint localPoint = [dockGroup convertPoint:windowPoint fromView:nil];

    // Iterate through all the DockIcon subviews in the DockGroup
    for (DockIcon *dockIcon in self.dockedGroup.subviews) {
        // Check if the localPoint is within the dockIcon's frame
        if (NSPointInRect(localPoint, dockIcon.frame)) {
            return dockIcon;  // Found the DockIcon the mouse is hovering over
        }
    }

    // Return nil if no DockIcon is found at the given point
    return nil;
}

@end
