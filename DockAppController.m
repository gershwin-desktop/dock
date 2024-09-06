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
        _defaultIcons = [NSArray arrayWithObjects:@"Workspace", @"Terminal", @"SystemPreferences", nil];
        _dockPosition = @"Bottom";
        
        _showDocked = YES;
        _showRunning = YES;
        _showPlaces = NO;
        
        _workspace = [NSWorkspace sharedWorkspace];  // Initialize the workspace property with the shared instance
        _iconSize = 72;
        _activeLight = 10;
        _padding = 16;

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

        // Register to listen for DockIcon click notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(iconClicked:)
                                                     name:@"DockIconClickedNotification"
                                                   object:nil];

        // Register to listen for DockIcon click notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(iconDropped:)
                                                     name:@"DockIconDroppedNotification"
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

- (void) saveDockedIconsToUserDefaults:(BOOL)reset
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (reset){
      // Reset the local array to match user defaults
      NSMutableArray *newArray = [[NSMutableArray alloc] init];
      // _dockedIcons = newArray;
      for (int index = 0; index < [_defaultIcons count]; index ++) {
        // [self addIcon:[_defaultIcons objectAtIndex:index] toDockedArray:YES];
      }

      // Reset the NSUserDefaults array
      [defaults setObject:_defaultIcons forKey:@"DockedIcons"];
      [defaults synchronize]; // Optional, to save changes immediately 
    } else {
      // Reset the local array to match app defaults
      // [self resetDockedIcons]; // FIXME: Needs to save the docked icons list      
    }
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

  if (self.showDocked)
      {
        self.dockedGroup = [[DockGroup alloc] init];  
        self.dockedGroup.iconSize = self.iconSize;
        self.dockedGroup.acceptsIcons = YES;
        [[self.dockWindow contentView] addSubview:self.dockedGroup];

        // Fetch Docked Apps from Prefs 
        [self loadDockedIconsFromUserDefaults];
      }

  if (self.showRunning)
    {
        self.runningGroup = [[DockGroup alloc] init];  
        self.runningGroup.iconSize = self.iconSize;
        [[self.dockWindow contentView] addSubview:self.runningGroup];
    }

  // TODO: Create Dividers

  // Fetch Running Apps from Workspace
  NSArray *runningApps = [self.workspace launchedApplications];
  for (int i = 0; i < [runningApps count]; i++)
    {
      NSString *runningAppName = [[runningApps objectAtIndex: i] objectForKey: @"NSApplicationName"];  
      BOOL isDockIcon = [runningAppName isEqualToString:@"Dock"];
      if (!isDockIcon && self.showDocked && self.dockedGroup)
        {
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

      BOOL isDocked = [self.dockedGroup hasIcon:runningAppName];
      if (!isDockIcon && isDocked && self.showDocked)
        {
          [self.dockedGroup setIconActive:runningAppName];
        } else if (!isDocked && self.showRunning && self.runningGroup) {
          NSLog(@"Finding undockedIcon for %@", runningAppName);
      }
    }
}

// Events
- (void) iconDropped:(NSNotification *)notification
{
    NSString *appName = notification.userInfo[@"appName"];
    BOOL isRunning = [self.runningGroup hasIcon:appName];
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
   
    

    if (self.isUnified)
      {
        [self updateDockWindow];
      }
}

- (void) iconClicked:(NSNotification *)notification
{
    NSLog(@"Callback from DockAppController");
    // DockIcon *dockIcon = (DockIcon *)sender;
    // NSString *appName = [dockIcon getAppName];
    NSString *appName = notification.userInfo[@"appName"];
    DockIcon *dockIcon = notification.object;
    
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
  
        //TODO  Manage the undocked list here
        BOOL isDocked = _showDocked ? [self.dockedGroup hasIcon:appName] : NO;
        if (_showDocked && isDocked) {
          // DockIcon *dockedIcon = [self getIconByName:appName withDockedStatus:YES];
          [self.dockedGroup setIconActive:appName];
        } else if (_showRunning && !isDocked) {
          [self.runningGroup addIcon:appName withImage:[self.workspace appIconForApp:appName]];
          [self.runningGroup setIconActive:appName];
        }
        // [self checkForNewActivatedIcons];

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

@end
