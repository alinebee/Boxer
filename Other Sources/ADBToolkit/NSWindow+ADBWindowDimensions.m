/*
 *  Copyright (c) 2013, Alun Bestor (alun.bestor@gmail.com)
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *		Redistributions of source code must retain the above copyright notice, this
 *	    list of conditions and the following disclaimer.
 *
 *		Redistributions in binary form must reproduce the above copyright notice,
 *	    this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 *	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 */

#import "NSWindow+ADBWindowDimensions.h"
#import "ADBGeometry.h"

@implementation NSWindow (ADBWindowDimensions)

+ (NSWindow *) windowAtPoint: (NSPoint)screenPoint
{
    NSInteger windowNumber = [NSWindow windowNumberAtPoint: screenPoint
                               belowWindowWithWindowNumber: 0];
    
    //This will return nil if the window belonged to another application.
    return [NSApp windowWithWindowNumber: windowNumber];
}

- (void) setFrameSize: (NSSize)newSize
		   anchoredOn: (NSPoint)anchor
			  display: (BOOL)displayViews
			  animate: (BOOL)performAnimation
{
	NSRect newFrame	= resizeRectFromPoint(self.frame, newSize, anchor);
	//Constrain the result to fit tidily on screen
	newFrame		= [self fullyConstrainFrameRect: newFrame toScreen: self.screen];
	
	[self setFrame: NSIntegralRect(newFrame) display: displayViews animate: performAnimation];
}

- (void) setFrameSizeKeepingWithinScreen: (NSSize)newSize
                                 display: (BOOL)displayViews
                                 animate: (BOOL)performAnimation
{
	NSRect windowFrame	= self.frame;
	NSRect screenFrame	= [NSScreen mainScreen].visibleFrame;
	
	//We determine where the window's center is relative to the screen, then feed that back in as our anchor point when resizing
	NSPoint midPoint	= NSMakePoint(NSMidX(windowFrame), NSMidY(windowFrame));
	NSPoint anchor		= pointRelativeToRect(midPoint, screenFrame);

	anchor.y = 1; //Tweak: keep the window title in the same position instead of centering vertically

	[self setFrameSize: newSize
			anchoredOn: anchor
               display: displayViews
               animate: performAnimation];
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
