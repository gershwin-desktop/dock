#import "ActiveLight.h"

@implementation ActiveLight

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _isVisible = YES;  // Initially, the circle is invisible
    }
    return self;
}

// Override drawRect: to draw the circle
- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    if (self.isVisible) {
        // Set the fill color to grey
        [[NSColor grayColor] setFill];
        
        // Define the circle's diameter and radius
        CGFloat circleDiameter = 4.0;
        CGFloat circleRadius = circleDiameter / 2.0;
        
        // Calculate the center point to draw the circle in the middle of the view
        NSRect bounds = [self bounds];
        NSPoint center = NSMakePoint(NSMidX(bounds), NSMidY(bounds));
        
        // Define the rectangle for the circle
        NSRect circleRect = NSMakeRect(center.x - circleRadius, center.y - circleRadius, circleDiameter, circleDiameter);
        
        // Create a bezier path for the circle
        NSBezierPath *circlePath = [NSBezierPath bezierPathWithOvalInRect:circleRect];
        
        // Fill the circle
        [circlePath fill];
    }
}

- (BOOL)getVisibility {
    return _isVisible;
}

// Method to toggle the visibility of the circle
- (void)setVisibility:(BOOL)isVisible {
    _isVisible = isVisible;  // Toggle the visibility state
    [self setNeedsDisplay:YES];  // Mark the view as needing display, which calls drawRect:
}

@end

