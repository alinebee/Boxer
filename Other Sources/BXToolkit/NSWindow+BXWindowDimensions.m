#import "NSWindow+BXWindowDimensions.h"
#import "BXGeometry.h"

@implementation NSWindow (BXWindowDimensions)

+ (NSWindow *) windowAtPoint: (NSPoint)screenPoint
{
    //TODO: this is not particularly clever and may give false positives/negatives.
    //For instance, it may return a window that is at that point but underneath
    //another app's window.
	for (NSWindow *window in [NSApp windows])
	{
		if ([window isVisible] && NSPointInRect(screenPoint, window.frame)) return window;
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

- (NSRect) fullyConstrainFrameRect: (NSRect)theRect
                          toScreen: (NSScreen *)theScreen
{
	NSRect screenRect = [theScreen visibleFrame];
	
	//We're already constrained, don't bother with further checks
	if (NSContainsRect(screenRect, theRect)) return theRect;
	
	//Try to keep the right edge from flowing off screen...
	if (theRect.size.width < screenRect.size.width)
	{
		CGFloat overflowRight = NSMaxX(theRect) - NSMaxX(screenRect);
		if (overflowRight > 0)	theRect.origin.x -= overflowRight;
	}
	//...but ensure left edge is always on screen
	if (theRect.origin.x < screenRect.origin.x)	theRect.origin.x = screenRect.origin.x;
	
	//Try to ensure bottom edge is above the Dock...
	if (theRect.origin.y < screenRect.origin.y)	theRect.origin.y = screenRect.origin.y;
	
	//...but let NSWindow constrainRect make sure the titlebar is always visible for us
	return [self constrainFrameRect: theRect toScreen: theScreen];
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
