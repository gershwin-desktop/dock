#import <AppKit/AppKit.h>
#import "DockAppController.h"
#import "DockIcon.h"

@implementation DockAppController

- (instancetype)init {
    self = [super init];
    if (self)
      {
        _defaultIcons = [NSArray arrayWithObjects:@"Workspace", @"Terminal", @"SystemPreferences", nil];
        _dockPosition = @"Bottom";
        _dockedIcons = [[NSMutableArray alloc] init];
        _undockedIcons = [[NSMutableArray alloc] init];
        _workspace = [NSWorkspace sharedWorkspace];  // Initialize the workspace property with the shared instance
        _iconSize = 64;
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

        [self setupDockWindow];
      }
    return self;
}

- (void)dealloc {
    // Remove self as an observer to avoid memory leaks
    [[NSNotificationCenter defaultCenter] removeObserver:self]; 
}

- (void) resetDockedIcons
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *appNames = [NSMutableArray array];

    for (int i = 0; i < [_dockedIcons count]; i++) {
        DockIcon *dockIcon = [_dockedIcons objectAtIndex:i];
        NSString *appName = [dockIcon getAppName];
        [appNames addObject:appName];
    }
    [defaults setObject:appNames forKey:@"DockedIcons"];
    [defaults synchronize]; // Optional, to save changes immediately 
}

- (void) saveDockedIconsToUserDefaults:(BOOL)reset
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (reset){
      // Reset the local array
      NSMutableArray *newArray = [[NSMutableArray alloc] init];
      _dockedIcons = newArray;
      for (int index = 0; index < [_defaultIcons count]; index ++) {
        [self addIcon:[_defaultIcons objectAtIndex:index] toDockedArray:YES];
      }

      // Reset the NSUserDefaults array
      [defaults setObject:_defaultIcons forKey:@"DockedIcons"];
      [defaults synchronize]; // Optional, to save changes immediately 
    } else {
      [self resetDockedIcons];
    }
}

- (void) loadDockedIconsFromUserDefaults
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray<NSString *> *retrievedDockedIcons = [defaults objectForKey:@"DockedIcons"];

    if ([retrievedDockedIcons count] > 0)
      {
      NSLog(@"Defaults Exist");
      NSMutableArray *newArray = [[NSMutableArray alloc] init];
      _dockedIcons = newArray;
  
      for (int i = 0; i < [retrievedDockedIcons count]; i++) {
        NSString *iconName = [retrievedDockedIcons objectAtIndex:i];
        NSLog(@"Retrieved icon for %@", iconName);
        [self addIcon:[retrievedDockedIcons objectAtIndex:i] toDockedArray:YES];
      }
      _dockedIcons = newArray;
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
  CGFloat dockWidth = [self calculateDockWidth];// (self.padding * 2 + totalIcons * self.iconSize);
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
  
  // Fetch Docked Apps from Prefs 
  [self loadDockedIconsFromUserDefaults];

  // TODO: Create Divider

  // Fetch Running Apps from Workspace
  NSArray *runningApps = [self.workspace launchedApplications];
  for (int i = 0; i < [runningApps count]; i++)
    {
      NSString *runningAppName = [[runningApps objectAtIndex: i] objectForKey: @"NSApplicationName"];  
      if ([self isIconDocked:runningAppName]) {
        DockIcon *dockedIcon = [self getIconByName:runningAppName withDockedStatus:YES];          
        [dockedIcon setActiveLightVisibility:YES]; 
      } else if([runningAppName isEqualToString:@"Dock"]) {
        // Don't show dock
      } else {
        [self addIcon:runningAppName toDockedArray:NO];
      }
    }
  
  // Set all the active lights for running apps
  [self checkForNewActivatedIcons];

  //Resize Dock Window
  [self updateDockWindow];
  
  [self.dockWindow makeKeyAndOrderFront:nil];
}

- (CGFloat) calculateDockWidth
{
    CGFloat dockWidth = (self.padding * 2 + ([_dockedIcons count] + [_undockedIcons count]) * self.iconSize);
    return dockWidth;
}

- (void) updateDockWindow
{
    // Adjust the width
    CGFloat dockWidth = [self calculateDockWidth];
    NSSize currentContentSize = [self.dockWindow.contentView frame].size;
    NSSize newContentSize = NSMakeSize(dockWidth, currentContentSize.height); // width, height
    [self.dockWindow setContentSize:newContentSize];

    // Center on screen  
    NSScreen *mainScreen = [NSScreen mainScreen];
    NSRect viewport = [mainScreen frame];
    CGFloat newX = (viewport.size.width / 2) - (dockWidth / 2);
    NSRect currentFrame = [self.dockWindow.contentView frame];
    NSRect newFrame = NSMakeRect(newX, self.padding, currentFrame.size.width, currentFrame.size.height);
    [self.dockWindow setFrame:newFrame display:YES];
}

- (void) updateIconPositions:(NSUInteger)startIndex
             fromDockedIcons:(BOOL)isDocked
                  expandDock:(BOOL)isExpanding
{
    // If isDocked, we need to move subset of dockedIcons and all of the undockedIcons so we create a global array.
    // Otherwise we move subset of undockedIcons only.
    NSMutableArray *targetArray = nil;
    if(isDocked)
      {
        targetArray = [_dockedIcons arrayByAddingObjectsFromArray:_undockedIcons];
      } else {
        targetArray = _undockedIcons;
      }

    for (int i = startIndex; i < [targetArray count]; i++)
      {
        DockIcon *dockIcon = [targetArray objectAtIndex:i];
        NSRect currentFrame = [dockIcon frame];
  
        // Horizontal adjustments
        if([_dockPosition isEqualToString:@"Bottom"]) {
          CGFloat startX = currentFrame.origin.x;
  
          if(isExpanding){
            CGFloat expandedX = currentFrame.origin.x + _iconSize;          
            NSRect expandedFrame = NSMakeRect(expandedX, currentFrame.origin.y , self.iconSize, self.iconSize);
            [dockIcon setFrame:expandedFrame]; // Replace with tween
          } else {
            CGFloat contractedX = currentFrame.origin.x - _iconSize;
            NSRect contractedFrame = NSMakeRect(contractedX, currentFrame.origin.y , self.iconSize, self.iconSize);
            [dockIcon setFrame:contractedFrame]; // Replace with tween
          } 
  
        }
      }   
}

- (void) addDivider
{
  // TODO
}

- (DockIcon *) addIcon:(NSString *)appName
         toDockedArray:(BOOL)isDocked
{
    // TODO: Animation Logic
    NSMutableArray *iconsArray = isDocked ? _dockedIcons : _undockedIcons;
    DockIcon *dockIcon = [self generateIcon:appName withDockedStatus:isDocked];
    [iconsArray addObject:dockIcon];
    [[self.dockWindow contentView] addSubview:dockIcon];

    if (isDocked) {
      [self saveDockedIconsToUserDefaults:NO];
    }
    return dockIcon;
}

- (void) removeIcon:(NSString *)appName
    fromDockedArray:(BOOL)isDocked
{
    // TODO: Animation Logic
    NSMutableArray *iconsArray = isDocked ? _dockedIcons : _undockedIcons;
    NSUInteger index = [self indexOfIcon:appName byDockedStatus:isDocked];
    if (index != NSNotFound)
      { 
        // NSLog(@"RemoveIcon Method: Removing %@", appName);
        DockIcon *undockedIcon = [iconsArray objectAtIndex:index];
        [undockedIcon selfDestruct];
        [iconsArray removeObjectIdenticalTo:undockedIcon];
        // Update Undocked Icons
        [self updateIconPositions:index fromDockedIcons:isDocked expandDock:NO];
        if (isDocked) {
          [self saveDockedIconsToUserDefaults:NO];
        }
      } else {
        NSLog(@"Error: Either not found or out of range. Could not remove %@", appName);
      }
}

- (BOOL) isIconDocked:(NSString *)appName
{
    BOOL defaultValue = NO;
    // DockIcon *dockedApp = [self.dockedIcons objectForKey:appName];
    NSUInteger index = [self indexOfIcon:appName byDockedStatus: YES];
    return index != NSNotFound ? YES : defaultValue;
}

- (NSUInteger) indexOfIcon:(NSString *)appName
            byDockedStatus:(BOOL)isDocked
{
    NSMutableArray *iconsArray = isDocked ? _dockedIcons : _undockedIcons;
    NSUInteger index = [iconsArray indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        // 'obj' is the current object in the array 
        DockIcon *dockIcon = (DockIcon *)obj;
        
        return [[dockIcon getAppName] isEqualToString:appName];
    }];

    return index;
}

- (DockIcon *) getIconByName:(NSString *)appName
            withDockedStatus:(BOOL)isDocked
{ 
    NSMutableArray *iconsArray = isDocked ? _dockedIcons : _undockedIcons;
    NSUInteger index = [self indexOfIcon:appName byDockedStatus: YES];
    
    if (index != NSNotFound) {
      return [iconsArray objectAtIndex: index];
    } else {
      NSLog(@"getIconByName Method: index not found for %@", appName);
      NSLog(@"getIconByName Method: iconsArray count is %lu",(unsigned long)[iconsArray count]);
    }
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
      if ([runningAppName isEqualToString:@"Dock"]) {
        NSLog(@"Ignoring Dock App");
        continue;
      }
      BOOL isDocked = [self isIconDocked:runningAppName];

      if (isDocked) {
        DockIcon *dockedIcon = [self getIconByName:runningAppName withDockedStatus:YES];
        NSLog(@"Finding dockedIcon for %@", runningAppName);
        NSLog(@"dockedIcon name is %@", [dockedIcon getAppName]);
        [dockedIcon setActiveLightVisibility:YES];
      } else {
        NSUInteger found = [self indexOfIcon:runningAppName byDockedStatus:NO];
        NSLog(@"Finding undockedIcon for %@", runningAppName);

        if (found != NSNotFound){
          NSLog(@"Icon found for app %@", runningAppName);
          // DockIcon *undockedIcon = [self getIconByName:runningAppName withDockedStatus:NO];
          DockIcon *undockedIcon = [_undockedIcons objectAtIndex:found];
          NSLog(@"undockedIcon name is %@", [undockedIcon getAppName]);
          [undockedIcon setActiveLightVisibility:YES];
        } else {
          NSLog(@"undockedIcon index not found for app %@ :", runningAppName);
          NSLog(@"%lu undocked icons :(", (unsigned long)[_undockedIcons count]);
          NSLog(@"%lu docked icons :(", (unsigned long)[_dockedIcons count]);
          if([_undockedIcons count] == 1) {
            NSLog(@"Manually fetched undockedIcon name is %@", [[_undockedIcons objectAtIndex:0] getAppName]);
          }
        }
      }
    }
}

- (NSRect) generateLocation:(NSString *)dockPosition
            forDockedStatus:(BOOL)isDocked
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
        NSRect bottomLocation = NSMakeRect(index * self.iconSize + (self.padding), self.activeLight, self.iconSize, self.iconSize);     
        return bottomLocation;
      }
}

- (DockIcon *) generateIcon:(NSString *)appName
           withDockedStatus:(BOOL)isDocked
{
    CGFloat iconCount = isDocked ? [self.dockedIcons count] : [self.dockedIcons count] + [self.undockedIcons count];
    NSRect location = [self generateLocation:_dockPosition forDockedStatus:isDocked atIndex:iconCount];  
    DockIcon *appButton = [[DockIcon alloc] initWithFrame:location];
    NSImage *iconImage = [self.workspace appIconForApp:appName]; 

    [appButton setImage:iconImage];
    [appButton setAppName:appName];
    [appButton setBordered:NO];
    [appButton setAction:@selector(iconClicked:)];
    [appButton setTarget:self]; 

    return appButton;
}

// Events

- (void) iconClicked:(DockIcon *)sender
{
    DockIcon *dockIcon = (DockIcon *)sender;
    NSString *appName = [dockIcon getAppName];
    
    if ([appName isEqualToString:@"Trash"])
      {
        // TODO Pull up Trash UI
      } else if ([appName isEqualToString:@"Dock"]) {
        // IGNORE this app if it comes up in the list
      } else {
        [self.workspace launchApplication:appName];
      }
}

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
        BOOL isDocked = [self isIconDocked:appName];
        if (isDocked) {
          DockIcon *dockedIcon = [self getIconByName:appName withDockedStatus:YES];
        } else {
          // Add to undocked list
          DockIcon *undockedIcon = [self addIcon:appName toDockedArray:NO];        
        }
        [self checkForNewActivatedIcons];
        [self updateDockWindow];
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
        // Manage the undocked list here
        BOOL isDocked = [self isIconDocked:appName];
        if (isDocked)
        {
          DockIcon *dockedIcon = [self getIconByName:appName withDockedStatus:YES];
          [dockedIcon setActiveLightVisibility:NO];
          [self checkForNewActivatedIcons];
        } else {
          [self removeIcon:appName fromDockedArray:NO];        
        }
        [self updateDockWindow];
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
