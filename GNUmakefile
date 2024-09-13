include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = Dock  # Name of the application
Dock_OBJC_FILES = main.m DockAppController.m DockGroup.m DockIcon.m ActiveLight.m DockDivider.m # List of Objective-C source files
Dock_RESOURCE_FILES = Resources/Info-gnustep.plist  Resources/Icons/*.png # Resource files (plist, images, etc.)

# Compiler flags to enable ARC
ADDITIONAL_OBJCFLAGS = -fobjc-arc

include $(GNUSTEP_MAKEFILES)/application.make

