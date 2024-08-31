#import <AppKit/AppKit.h>
#import "DockAppController.h"
#import "DockIcon.h"

@implementation DockAppController

- (instancetype)init {
    self = [super init];
    if (self) {
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

- (void)setupDockWindow {
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
    
    // Set the dock window content view
    // NSView *contentView = [self.dockWindow contentView];
    
    // TODO: Fetch Docked Apps from Prefs
    
    // Add default applications icons to the dock window (Replace this with NSUserDefaults)
    [self addIcon:@"Workspace" toDockedArray:YES];
    [self addIcon:@"Terminal" toDockedArray:YES];
    [self addIcon:@"SystemPreferences" toDockedArray:YES];

    // TODO: Create Divider

    // Fetch Running Apps from Workspace
    NSArray *runningApps = [self.workspace launchedApplications];
    for (int i = 0; i < [runningApps count]; i++) {
        NSString *runningAppName = [[runningApps objectAtIndex: i] objectForKey: @"NSApplicationName"];
        // DockIcon *dockedIcon = [_dockedIcons objectForKey:runningAppName];
        // DockIcon *undockedIcon = [_undockedIcons objectForKey:runningAppName];
  
        if ([self isIconDocked:runningAppName]) {
          DockIcon *dockedIcon = [self getIconByName:runningAppName withDockedStatus:YES];          
          [dockedIcon setActiveLightVisibility:YES]; 
        } else if([runningAppName isEqualToString:@"Dock"]) {
          // Don't show dock
        } else {
          [self addIcon:runningAppName toDockedArray:NO];
        }
  
        // NSLog(@"Running App: %@", runningAppName);
    }
    
    
    // Set all the active lights for running apps
    [self checkForNewActivatedIcons];

    //Resize Dock Window
    [self updateDockWindow];
    
    [self.dockWindow makeKeyAndOrderFront:nil];
}

- (CGFloat)calculateDockWidth {
    CGFloat dockWidth = (self.padding * 2 + ([_dockedIcons count] + [_undockedIcons count]) * self.iconSize);
    return dockWidth;
}

- (void)updateDockWindow {
    // NSLog(@"Updating dock window...");
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

    // Update Undocked Icons
    //[self updateIconPositions:NO];
}

- (void)updateIconPositions:(BOOL)isDocked {
    NSMutableArray *iconsArray = isDocked ? self.dockedIcons : self.undockedIcons;
    CGFloat index = isDocked ? 0 : [self.dockedIcons count];

    // Update Docked Icon Positions
    // for(NSString *appName in iconsArray) {
      // DockIcon *dockIcon = [iconsArray objectForKey:appName];
    for(CGFloat i = 0; i < [iconsArray count]; i++) {
      DockIcon *dockIcon = [iconsArray objectAtIndex:i];      
      // Arrange Icons 
      NSRect currentFrame = [dockIcon frame];
      NSRect newFrame = [self generateLocation:@"Bottom" forDockedStatus:isDocked atIndex:index];  
      
      // NSLog(@"%@", dockIcon.getAppName);
      
      [dockIcon setFrame:newFrame];
      index += 1;
    }
   
}

- (void)addDivider {}

- (DockIcon *)addIcon:(NSString *)appName toDockedArray:(BOOL)isDocked{
    // Adds icon to the array. Function will also contain animation logic
    // TODO: Animation Logic
    NSMutableArray *iconsArray = isDocked ? _dockedIcons : _undockedIcons;
    DockIcon *dockIcon = [self generateIcon:appName withDockedStatus:isDocked];
    [iconsArray addObject:dockIcon];
    [[self.dockWindow contentView] addSubview:dockIcon];
    // NSLog(@"Undocked Count: %lu",(unsigned long)[_undockedIcons count]);
    return dockIcon;
}

- (void)removeIcon:(NSString *)appName fromDockedArray:(BOOL)isDocked{
    // Adds icon to the array. Function will also contain animation logic
    // TODO: Animation Logic
    NSMutableArray *iconsArray = isDocked ? _dockedIcons : _undockedIcons;
    NSUInteger index = [self indexOfIcon:appName byDockedStatus:isDocked];
    if(index != NSNotFound){ 
      // NSLog(@"RemoveIcon Method: Removing %@", appName);
      DockIcon *undockedIcon = [iconsArray objectAtIndex:index];
      [undockedIcon selfDestruct];
      [iconsArray removeObjectIdenticalTo:undockedIcon];
    } else {
      NSLog(@"Error: Either not found or out of range. Could not remove %@", appName);
      // NSLog(@"Index:%f , Length: %f",index,[iconsArray count]);
    }
}

- (BOOL)isIconDocked:(NSString *)appName {
    BOOL defaultValue = NO;
    // DockIcon *dockedApp = [self.dockedIcons objectForKey:appName];
    NSUInteger index = [self indexOfIcon:appName byDockedStatus: YES];
    return index != NSNotFound ? YES : defaultValue;
}

- (NSUInteger)indexOfIcon:(NSString *)appName byDockedStatus:(BOOL)isDocked{
    NSMutableArray *iconsArray = isDocked ? _dockedIcons : _undockedIcons;
    NSUInteger index = [iconsArray indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        // 'obj' is the current object in the array 
        DockIcon *dockIcon = (DockIcon *)obj;
        
        // Return YES if the DockIcon name matches the appName param
        return [[dockIcon getAppName] isEqualToString:appName];
    }];

    return index;
}

- (DockIcon *)getIconByName:(NSString *)appName withDockedStatus:(BOOL)isDocked { 
    NSMutableArray *iconsArray = isDocked ? _dockedIcons : _undockedIcons;
    NSUInteger index = [self indexOfIcon:appName byDockedStatus: YES];
    
    if (index != NSNotFound) {
      return [iconsArray objectAtIndex: index];
    } else {
      NSLog(@"getIconByName Method: index not found for %@", appName);
      NSLog(@"getIconByName Method: iconsArray count is %lu",(unsigned long)[iconsArray count]);
    }
}

- (void) checkForNewActivatedIcons {
  // Update Dock Icons Arrays
  NSLog(@"checkForNewActivatedIcons Method...");
  // Get the list of running applications
  NSArray *runningApps = [self.workspace launchedApplications];
  for (int i = 0; i < [runningApps count]; i++) {
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
        // DockIcon *undockedIcon = [self addIcon:runningAppName toDockedArray:NO];
        NSUInteger found = [self indexOfIcon:runningAppName byDockedStatus:NO];
        NSLog(@"Finding undockedIcon for %@", runningAppName);
        //NSLog(@"undockedIcon name is %@", [undockedIcon getAppName]);
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

- (NSRect)generateLocation:(NSString *)dockPosition forDockedStatus:(BOOL)isDocked atIndex:(CGFloat)index{
    if([dockPosition isEqualToString:@"Left"]) {
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

- (DockIcon *)generateIcon:(NSString *)appName withDockedStatus:(BOOL)isDocked {
    CGFloat iconCount = isDocked ? [self.dockedIcons count] : [self.dockedIcons count] + [self.undockedIcons count];
    NSRect location = [self generateLocation:@"Bottom" forDockedStatus:isDocked atIndex:iconCount];  
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

- (void)iconClicked:(DockIcon *)sender{
    DockIcon *dockIcon = (DockIcon *)sender;
    NSString *appName = [dockIcon getAppName];
    
    if ([appName isEqualToString:@"Trash"]) {
      // TODO Pull up Trash UI
    } else if ([appName isEqualToString:@"Dock"]) {
      // IGNORE this app if it comes up in the list
      // DockIcon *undockedIcon = [_undockedIcons objectForKey:appName];
      //[_undockedIcons removeObjectForKey:appName];
    } else {
      [self.workspace launchApplication:appName];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    NSString *appName = userInfo[@"NSApplicationName"];
    if (appName) {
      if ([appName isEqualToString:@"Dock"]) {
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

- (void)applicationIsLaunching:(NSNotification *)notification {
    // TODO: ICON BOUNCE
    NSLog(@"Get ready to bounce"); 
}

- (void)applicationTerminated:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    NSString *appName = userInfo[@"NSApplicationName"];
    if (appName) {
      // Manage the undocked list here
      BOOL isDocked = [self isIconDocked:appName];
      if (isDocked) {
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

- (void)activeApplicationChanged:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    NSString *appName = userInfo[@"NSApplicationName"];
    if (appName) {
      // NSLog(@"%@ is active", appName);
    } else {
      // NSLog(@"Active application changed, but could not retrieve name.");
    }
}

@end
