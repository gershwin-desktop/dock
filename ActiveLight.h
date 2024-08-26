#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface ActiveLight : NSView

@property (nonatomic, assign) BOOL isVisible;  // Property to track circle visibility

- (BOOL)getVisibility;  // Method to toggle the visibility of the circle

- (void)setVisibility:(BOOL)isVisible;  // Method to toggle the visibility of the circle

@end
