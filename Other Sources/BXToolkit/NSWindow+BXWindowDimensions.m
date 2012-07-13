#import "NSWindow+BXWindowDimensions.h"
#import "BXGeometry.h"

@implementation NSWindow (BXWindowDimensions)

+ (NSWindow *) windowAtPoint: (NSPoint)screenPoint
{
    //Use the 10.6 method if it's available.
    if ([[NSWindow class] respondsToSelector: @selector(windowNumberAtPoint:belowWindowWithWindowNumber:)])
    {
        NSInteger windowNumber = [NSWindow windowNumberAtPoint: screenPoint
                                   belowWindowWithWindowNumber: 0];
        
        if (windowNumber) return [NSApp windowWithWindowNumber: windowNumber];
    }
    else
    {
        //TODO: this is not particularly clever and may give false positives/negatives.
        //For instance, it may return a window that is at that point but underneath
        //another app's window.
        for (NSWindow *window in [NSApp windows])
        {
            if ([window isVisible] && NSPointInRect(screenPoint, window.frame)) return window;
        }
    }
	return nil;
}

- (void) setFrameSize: (NSSize)newSize
		   anchoredOn: (NSPoint)anchor
			  display: (BOOL)displayViews
			  animate: (BOOL)performAnimation
{
	NSRect newFrame	= resizeRectFromPoint([self frame], newSize, anchor);
	//Constrain the result to fit tidily on screen
	newFrame		= [self fullyConstrainFrameRect: newFrame toScreen: [self screen]];
	
	[self setFrame: NSIntegralRect(newFrame) display: displayViews animate: performAnimation];
}

- (void) setFrameSizeKeepingWithinScreen: (NSSize)newSize
                                 display: (BOOL)displayViews
                                 animate: (BOOL)performAnimation
{
	NSRect windowFrame	= [self frame];
	NSRect screenFrame	= [[NSScreen mainScreen] visibleFrame];
	
	//We determine where the window's center is relative to the screen, then feed that back in as our anchor point when resizing
	NSPoint midPoint	= NSMakePoint(NSMidX(windowFrame), NSMidY(windowFrame));
	NSPoint anchor		= pointRelativeToRect(midPoint, screenFrame);

	anchor.y = 1; //Tweak: keep the window title in the same position instead of centering vertically

	[self setFrameSize:	newSize
			anchoredOn: anchor
			display:	displayViews
			animate:	performAnimation];
}

- (NSRect) fullyConstrainFrameRect: (NSRect)originalRect
                          toScreen: (NSScreen *)screen
{
    NSRect constrainedRect = originalRect;
	NSRect screenRect = screen.visibleFrame;
	
	//We're already constrained, don't bother with further checks
	if (NSContainsRect(screenRect, originalRect)) return constrainedRect;
	
	//Try to keep the right edge from flowing off screen...
	if (constrainedRect.size.width < screenRect.size.width)
	{
		CGFloat overflowRight = NSMaxX(constrainedRect) - NSMaxX(screenRect);
		if (overflowRight > 0)
            constrainedRect.origin.x -= overflowRight;
	}
	//...but ensure the left edge is always on screen.
	if (constrainedRect.origin.x < screenRect.origin.x)
        constrainedRect.origin.x = screenRect.origin.x;
	
	//Try to ensure bottom edge is above the Dock...
	if (constrainedRect.origin.y < screenRect.origin.y)
        constrainedRect.origin.y = screenRect.origin.y;
	
	//...but let NSWindow constrainRect make sure the titlebar is always visible for us.
    //IMPLEMENTATION NOTE: constrainFrameRect:toScreen: may try to resize the rect vertically
    //if the screen is too small to accommodate the entire rect, and in doing so it may not
    //respect our fixed aspect ratio, resulting in deformed/overlapping views.
    //So, we only take the constrained origin from the method, and leave the size as it
    //originally was.
	constrainedRect.origin = [self constrainFrameRect: constrainedRect toScreen: screen].origin;
    
    return constrainedRect;
}


- (NSRect) frameRectForContentSize: (NSSize)contentSize
                   relativeToFrame: (NSRect)windowFrame
                        anchoredAt: (NSPoint)anchor
{
    NSRect contentRect = NSMakeRect(0, 0, contentSize.width, contentSize.height);
    NSRect newFrame = [self frameRectForContentRect: contentRect];
    
    NSRect centeredFrame = resizeRectFromPoint(windowFrame, newFrame.size, anchor);
    return centeredFrame;
}

@end
