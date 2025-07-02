#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

@interface ActiveLight : NSView

@property (nonatomic, assign) BOOL isVisible; // Property to track circle visibility

- (BOOL)getVisibility; // Method to toggle the visibility of the circle

- (void)setVisibility:(BOOL)isVisible; // Method to toggle the visibility of the circle

@end
