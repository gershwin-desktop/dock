#import <AppKit/AppKit.h>
#import "DockAppController.h"
#import "DockIcon.h"

@implementation DockAppController

- (instancetype)init {
    self = [super init];
    if (self) {
        _dockedIcons = [[NSMutableDictionary alloc] init];
        _undockedIcons = [[NSMutableDictionary alloc] init];
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

    // TODO: Calculate based on state. Will hard code for now
    CGFloat totalIcons = 12;
    // Create a dock window without a title bar or standard window buttons 
    CGFloat dockWidth = (self.padding * 2 + totalIcons * self.iconSize);
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
    NSView *contentView = [self.dockWindow contentView];
    
    // Add default applications icons to the dock window
    [self addApplicationIcon:@"GWorkspace" withDockedStatus:YES];
    [self addApplicationIcon:@"Terminal" withDockedStatus:YES];
    [self addApplicationIcon:@"SystemPreferences" withDockedStatus:YES];
    //[self addApplicationIcon:@"Ycode" withDockedStatus:YES];
    //[self addApplicationIcon:@"Chess" withDockedStatus:YES];
    
    // Set all the active lights for running apps
    [self checkForNewActivatedIcons];

    // TODO: Fetch Docked Apps from Prefs

    // TODO: Create Divider

    // TODO: Fetch Running Apps from Workspace
    
    
    [self.dockWindow makeKeyAndOrderFront:nil];
}

- (void)addApplicationIcon:(NSString *)appName withDockedStatus:(BOOL)isDocked {
    //NSButton *appButton = [self generateIcon:appName];
    DockIcon *appButton = [self generateIcon:appName];
    [[self.dockWindow contentView] addSubview:appButton];
    if(isDocked) {
      [self.dockedIcons setObject:appButton forKey:appName];
    } else {
      [self.undockedIcons setObject:appButton forKey:appName];
    }
}

- (void)addDivider {}
- (void)dockIcon:(NSString *)appName {} // Remove
- (void)undockIcon:(NSString *)appName {} // Remove

- (BOOL)isAppDocked:(NSString *)appName {
    BOOL defaultValue = NO;
    DockIcon *dockedApp = [self.dockedIcons objectForKey:appName];
    return dockedApp ? YES : defaultValue;
}

- (void) checkForNewActivatedIcons {
  // Update Dock Icons Arrays
  NSLog(@"Looking up launchedApplications...");
  // Get the list of running applications
  NSArray *runningApps = [self.workspace launchedApplications];
  for (int i = 0; i < [runningApps count]; i++) {
      NSString *runningAppName = [[runningApps objectAtIndex: i] objectForKey: @"NSApplicationName"];
      DockIcon *dockedIcon = [_dockedIcons objectForKey:runningAppName];

      if (dockedIcon) {
        [dockedIcon setActiveLightVisibility:YES];
      } else {
        DockIcon *undockedIcon = [_undockedIcons objectForKey:runningAppName];
        [undockedIcon setActiveLightVisibility:YES];
      }

      NSLog(@"Running App: %@", runningAppName);
  }
}

- (NSRect)generateLocation:(NSString *)dockPosition  {
    if([dockPosition isEqualToString:@"Left"]) {
      NSRect leftLocation = NSMakeRect(self.activeLight, [self.dockedIcons count] * self.iconSize + (self.padding), self.iconSize, self.iconSize);
      return leftLocation;
    } else if([dockPosition isEqualToString:@"Right"]) {
      NSRect rightLocation = NSMakeRect(self.activeLight, [self.dockedIcons count] * self.iconSize + (self.padding), self.iconSize, self.iconSize);
      return rightLocation;
    } else {
      // If unset we default to "Bottom"
      NSRect bottomLocation = NSMakeRect([self.dockedIcons count] * self.iconSize + (self.padding), self.activeLight, self.iconSize, self.iconSize);
      return bottomLocation;
    }
}

- (DockIcon *)generateIcon:(NSString *)appName  {
    NSRect location = [self generateLocation:@"Bottom"];  
    DockIcon *appButton = [[DockIcon alloc] initWithFrame:location];
    NSImage *iconImage = [self.workspace appIconForApp:appName]; 

    [appButton setImage:iconImage];
    [appButton setAppName:appName];
    [appButton setBordered:NO];
    [appButton setAction:@selector(iconClicked:)];
    [appButton setTarget:self]; 

    return appButton;
}

- (void)iconClicked:(DockIcon *)sender{
    DockIcon *dockIcon = (DockIcon *)sender;
    NSString *appName = [dockIcon getAppName];
    
    if ([appName isEqualToString:@"Trash"]) {
      // TODO Pull up Trash UI
    } else if ([appName isEqualToString:@"Dock"]) {
      // IGNORE this app if it comes up in the list
      DockIcon *undockedIcon = [_undockedIcons objectForKey:appName];
      [_undockedIcons removeObjectForKey:appName];
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

      NSLog(@"%@ launched", appName);
      //TODO  Manage the undocked list here
      BOOL isDocked = [self isAppDocked:appName];
      if (isDocked) {
        DockIcon *dockedIcon = [_dockedIcons objectForKey:appName];
        [dockedIcon setActiveLightVisibility:YES];
        // [self checkForNewActivatedIcons];
      } else {
        // Add to undocked list
        [self addApplicationIcon:appName withDockedStatus:NO];        
      }
    } else {
      NSLog(@"Application launched, but could not retrieve name.");
    }

    [self checkForNewActivatedIcons];
}

- (void)applicationIsLaunching:(NSNotification *)notification {
  // TODO: ICON BOUNCE
  NSLog(@"Get ready to bounce");
}

- (void)applicationTerminated:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    NSString *appName = userInfo[@"NSApplicationName"];
    if (appName) {
      NSLog(@"%@ terminated", appName);
      //TODO  Manage the undocked list here
      BOOL isDocked = [self isAppDocked:appName];
      if (isDocked) {
        DockIcon *dockedIcon = [_dockedIcons objectForKey:appName];
        [dockedIcon setActiveLightVisibility:NO];
        // [self checkForNewActivatedIcons];
      } else {
        // Remove from undocked list
        DockIcon *undockedIcon = [_undockedIcons objectForKey:appName];
        [_undockedIcons removeObjectForKey:appName];
        [undockedIcon selfDestruct];
      }

    } else {
      NSLog(@"Application terminated, but could not retrieve name.");
    }
}

- (void)activeApplicationChanged:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    NSString *appName = userInfo[@"NSApplicationName"];
    if (appName) {
      NSLog(@"%@ is active", appName);
      //DockIcon *dockedIcon = [_dockedIcons objectForKey:appName];
      //[dockedIcon setActiveLightVisibility:YES];

      //TODO  Manage the undocked list here
      //[self checkForNewActivatedIcons];
    } else {
      NSLog(@"Active application changed, but could not retrieve name.");
    }
}

@end
