/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXSessionWindowController+BXRenderController.h"
#import "BXSessionWindow.h"
#import "BXEmulator.h"
#import "NSWindow+BXWindowSizing.h"
#import "BXDOSViewController.h"
#import "BXDOSView.h"
#import "BXFrameBuffer.h"

#import "BXGeometry.h"


@implementation BXSessionWindowController (BXRenderController)

//DOSBox frame rendering
//----------------------

- (void) updateWithFrame: (BXFrameBuffer *)frame
{
	//Resize the window to accomodate the frame
	[self resizeToAccommodateFrameSize: [frame scaledResolution]];
	
	//Tell the render view to draw the frame
	[DOSView updateWithFrame: frame];
}


//Window size calculations
//------------------------

- (BOOL) isResizing
{
	return [self resizingProgrammatically] || [[self DOSView] inLiveResize];
}

//Returns the current size that the render view *would be if it were in windowed mode.
//This will differ from the actual render view size when in fullscreen mode.
- (NSSize) windowedDOSViewSize	{ return [[self DOSViewContainer] frame].size; }

- (void) resizeToAccommodateFrameSize: (NSSize)scaledSize
{
	//Don't resize if we're already matched to this size
	if (NSEqualSizes(currentScaledSize, scaledSize)) return;

	NSSize viewSize	= [self _DOSViewSizeForScaledOutputSize: scaledSize minSize: scaledSize];
	
	//Use the base resolution as our minimum content size, to prevent higher resolutions being rendered
	//smaller than their effective size
	//Tweak: ...unless the base resolution is actually larger than our view size, which can happen 
	//if the base resolution is too large to fit on screen and hence the view is shrunk.
	//In that case we use the target view size as the minimum instead.
	NSSize minSize;
	if (viewSize.width < scaledSize.width || viewSize.height < scaledSize.height)
		minSize = viewSize;
	else
		minSize = scaledSize;

	//Fix the window's aspect ratio to the new size - this will affect our live resizing behaviour
	[[self window] setContentMinSize: minSize];
	[[self window] setContentAspectRatio: viewSize];
	
	//Now resize the window to fit the new size
	//Tell the renderer not to maintain aspect ratio when doing so,
	//since this change in size is driven by the DOS context
	[self _resizeWindowToDOSViewSize: viewSize animate: YES];
	
	//Finally, record our current scaled size for future resizing calculations
	currentScaledSize = scaledSize;
}


//Try to resize the window to accomodate the specified minimum size
//If we can't manage that size, do nothing and return NO; otherwise resize and return YES
- (BOOL) resizeToAtLeastSize: (NSSize) minViewSize
{
	//Don't resize if we're in the middle of resizing already
	if ([self isResizing]) return NO;
	
	BXSessionWindow *theWindow = [self window];

	NSSize currentSize		= [self windowedDOSViewSize];
	//We're already that size or larger, don't resize further
	if (sizeFitsWithinSize(minViewSize, currentSize)) return YES;
	
	//Otherwise check if the desired size will still fit on screen
	NSRect screenFrame		= [[theWindow screen] visibleFrame];
	NSSize maxViewSize		= [theWindow contentRectForFrameRect: screenFrame].size;
	
	//If the minimum requested size won't fit on screen, bail out
	if (!sizeFitsWithinSize(minViewSize, maxViewSize)) return NO;
	
	//Otherwise carry on and resize
	[self _resizeWindowToDOSViewSize: minViewSize animate: YES];
	return YES;
}

//Switch the DOS window in or out of fullscreen instantly
- (void) setFullScreen: (BOOL)fullScreen
{
	//Don't bother if we're already in the correct fullscreen state
	if ([self isFullScreen] == fullScreen) return;
	
	[self willChangeValueForKey: @"fullScreen"];
	
	NSView *theView			= [self DOSView];
	NSView *theContainer	= [self DOSViewContainer]; 
	NSWindow *theWindow		= [self window];
	NSResponder *currentResponder = [theView nextResponder];
	
	if (fullScreen)
	{
		NSScreen *targetScreen	= [self fullScreenTarget];
		
		//Flip the view into fullscreen mode
		[theView enterFullScreenMode: targetScreen withOptions: nil];
		
		//Reset the responders to what they should be, since enterFullScreenMode: screws with them
		[theWindow makeFirstResponder: theView];
		[theView setNextResponder: currentResponder];
		
		//Ensure that the mouse is locked for fullscreen mode
		[DOSViewController setMouseLocked: YES];
	}
	else
	{
		[theView exitFullScreenModeWithOptions: nil];
		
		//Reset the responders to what they should be, since exitFullScreenModeWithOptions: screws with them
		[theWindow makeFirstResponder: theView];
		[theView setNextResponder: currentResponder];
		
		//Reset the view's frame to match its loyal container, as otherwise it retains its fullscreen frame size
		[theView setFrame: [theContainer bounds]];
		[theView setNeedsDisplay: YES];
		
		//Cocoa 10.6 bugfix: for some reason this gets forgotten upon the return to windowed mode,
		//until the window loses and regains focus. Setting it manually fixes it.
		[theWindow setAcceptsMouseMovedEvents: YES];
		
		//Unlock the mouse after leaving fullscreen
		[DOSViewController setMouseLocked: NO];
	}
	
	[self didChangeValueForKey: @"fullScreen"];
}

- (BOOL) isFullScreen
{
	return [[self DOSView] isInFullScreenMode];
}

- (NSScreen *) fullScreenTarget
{
	return [NSScreen mainScreen];
}

//Zoom the DOS window in or out of fullscreen with a smooth animation
//Returns YES if the window is zooming, NO if no zoom occurs (i.e. the window is already in the correct state)
- (void) setFullScreenWithZoom: (BOOL) fullScreen
{	
	//Don't bother if we're already in the correct fullscreen state
	if ([self isFullScreen] == fullScreen) return;
	 
	NSWindow *theWindow		= [self window];
	
	NSInteger originalLevel		= [theWindow level];
	NSRect originalFrame		= [theWindow frame];
	NSScreen *targetScreen		= [self fullScreenTarget];
	NSRect fullscreenFrame		= [targetScreen frame];
	NSRect zoomedWindowFrame	= [theWindow frameRectForContentRect: fullscreenFrame];
	
	[[self emulator] willPause];
	[theWindow setLevel: NSScreenSaverWindowLevel];

	//Make sure we're the key window first before any shenanigans
	[theWindow makeKeyAndOrderFront: self];
	
	[self setResizingProgrammatically: YES];
	if (fullScreen)
	{
		//First zoom smoothly in to fill the screen...
		[theWindow setFrame: zoomedWindowFrame display: YES animate: YES];
				
		//Then flip the view into fullscreen mode...
		[self setFullScreen: YES];
		
		//...then revert the window back to its original size, while it's hidden by the fullscreen view
		//We do this so that the window's autosaved frame doesn't get messed up, and so that we don't have
		//to track the window's former size indepedently while we're in fullscreen mode.
		[theWindow setFrame: originalFrame display: NO];
	}
	else
	{
		//First quietly resize the window to fill the screen, while we're still hidden by the fullscreen view...
		[theWindow setFrame: zoomedWindowFrame display: YES];
		
		//...then flip the view out of fullscreen, which will return it to the zoomed window...
		[self setFullScreen: NO];
		
		//...then resize the window back to its original size
		[theWindow setFrame: originalFrame display: YES animate: YES];
	}
	[self setResizingProgrammatically: NO];
	[theWindow setLevel: originalLevel];
	[[self emulator] didResume];
}

//Snap to multiples of the base render size as we scale
- (NSSize) windowWillResize: (BXSessionWindow *)theWindow toSize: (NSSize) proposedFrameSize
{
	//If emulation is not active, don't bother calculating constraints
	if (![[self emulator] isExecuting]) return proposedFrameSize;
	
	NSInteger snapThreshold	= [[NSUserDefaults standardUserDefaults] integerForKey: @"windowSnapDistance"];
	NSSize snapIncrement	= currentScaledSize;
	CGFloat aspectRatio		= aspectRatioOfSize([theWindow contentAspectRatio]);
	
	NSRect proposedFrame	= NSMakeRect(0, 0, proposedFrameSize.width, proposedFrameSize.height);
	NSRect renderFrame		= [theWindow contentRectForFrameRect:proposedFrame];
	
	CGFloat snappedWidth	= round(renderFrame.size.width / snapIncrement.width) * snapIncrement.width;
	CGFloat widthDiff		= abs(snappedWidth - renderFrame.size.width);
	if (widthDiff > 0 && widthDiff <= snapThreshold)
	{
		renderFrame.size.width = snappedWidth;
		if (aspectRatio > 0) renderFrame.size.height = round(snappedWidth / aspectRatio);
	}
	
	NSSize newProposedSize = [theWindow frameRectForContentRect:renderFrame].size;
	
	return newProposedSize;
}


//Return an appropriate "standard" (zoomed) frame for the window given the currently available screen space.
//We define the standard frame to be the largest even multiple of the game resolution.
//Note that in some cases this will be equal to the standard window size, so that nothing happens when zoomed
//(unfortunately the cures for this are worse than the disease, so we leave it be for now.)

- (NSRect) windowWillUseStandardFrame: (BXSessionWindow *)theWindow defaultFrame: (NSRect)defaultFrame
{
	if (![[self emulator] isExecuting]) return defaultFrame;
	
	NSSize scaledResolution			= currentScaledSize;
	CGFloat aspectRatio				= aspectRatioOfSize([theWindow contentAspectRatio]);
	
	NSRect standardFrame;
	NSRect currentFrame				= [theWindow frame];
	NSRect defaultViewFrame			= [theWindow contentRectForFrameRect: defaultFrame];
	NSRect largestCleanViewFrame	= defaultViewFrame;
	
	//Constrain the proposed view frame to the largest even multiple of the base resolution
	largestCleanViewFrame.size.width -= ((NSInteger)defaultViewFrame.size.width % (NSInteger)scaledResolution.width);
	if (aspectRatio > 0)
		largestCleanViewFrame.size.height = round(largestCleanViewFrame.size.width / aspectRatio);
	
	//Turn our new constrained view frame back into a suitably positioned window frame
	standardFrame = [theWindow frameRectForContentRect: largestCleanViewFrame];
	
	//Carry over the top-left corner position from the original window
	standardFrame.origin	= currentFrame.origin;
	standardFrame.origin.y += (currentFrame.size.height - standardFrame.size.height);
	
	//Constrain our newly frame to fit the screen real-estate (which it should already do, but just in case)
	standardFrame.size		= constrainToFitSize(standardFrame.size, defaultFrame.size);
	
	return standardFrame;
}

@end


@implementation BXSessionWindowController (BXRenderControllerInternals)

//Performs the slide animation used to toggle the status bar and program panel on or off
- (void) _slideView: (NSView *)view shown: (BOOL)show
{
	NSRect newFrame	= [[self window] frame];
	
	CGFloat height	= [view frame].size.height;
	if (!show) height = -height;
	
	newFrame.size.height	+= height;
	newFrame.origin.y		-= height;
	
	if (show) [view setHidden: NO];	//Unhide before sliding out
	if (![self isFullScreen])
	{
		[[self window] setFrame: newFrame display: YES animate: YES];
	}
	else
	{
		[[self window] setFrame: newFrame display: NO];
	}

	if (!show)	[view setHidden: YES];	//Hide after sliding in 
}

//Resize the window frame to the requested render size.
- (void) _resizeWindowToDOSViewSize: (NSSize)newSize animate: (BOOL)performAnimation
{
	NSWindow *theWindow	= [self window];
	NSSize currentSize	= [self windowedDOSViewSize];
	
	if (!NSEqualSizes(currentSize, newSize))
	{
		NSSize windowSize	= [theWindow frame].size;
		windowSize.width	+= newSize.width	- currentSize.width;
		windowSize.height	+= newSize.height	- currentSize.height;
		
		//Resize relative to center of titlebar
		NSRect newFrame		= resizeRectFromPoint([theWindow frame], windowSize, NSMakePoint(0.5, 1));
		//Constrain the result to fit tidily on screen
		newFrame			= [theWindow fullyConstrainFrameRect: newFrame toScreen: [theWindow screen]];
		
		newFrame = NSIntegralRect(newFrame);
		
		[self setResizingProgrammatically: YES];
		if (![self isFullScreen])
		{
			[theWindow setFrame: newFrame display: YES animate: performAnimation];
		}
		else
		{
			[theWindow setFrame: newFrame display: NO];
		}
		[self setResizingProgrammatically: NO];
	}
}

//Returns the most appropriate view size for the intended output size, given the size of the current window.
//This is calculated as the current view size with the aspect ratio compensated for that of the new output size:
//favouring the width or the height as appropriate.
- (NSSize) _DOSViewSizeForScaledOutputSize: (NSSize)scaledSize minSize: (NSSize)minViewSize
{	
	//Start off with our current view size: we want to deviate from this as little as possible.
	NSSize viewSize = [self windowedDOSViewSize];
	
	//Work out the aspect ratio of the scaled size, and how we should apply that ratio
	CGFloat aspectRatio = aspectRatioOfSize(scaledSize);
	
	//We preserve height during the aspect ratio adjustment if:
	// 1. the new height is equivalent to the old, and
	// 2. the width is not equivalent to the old.
	//Otherwise, we preserve width.
	//Height-locking fixes crazy-ass resolution transitions in Pinball Fantasies and The Humans,
	//while width-locking allows for rounding errors from live resizes.
	BOOL preserveHeight = !((NSInteger)currentScaledSize.height	% (NSInteger)scaledSize.height)
	&& ((NSInteger)currentScaledSize.width	% (NSInteger)scaledSize.width);
	
	//Now, adjust the view size to fit the aspect ratio of our new rendered size.
	//At the same time we clamp it to the minimum size, preserving the preferred dimension.
	if (preserveHeight)
	{
		if (minViewSize.height > viewSize.height) viewSize = minViewSize;
		viewSize.width = round(viewSize.height * aspectRatio);
	}
	else
	{
		if (minViewSize.width > viewSize.width) viewSize = minViewSize;
		viewSize.height = round(viewSize.width / aspectRatio);
	}
	
	//TODO: this screen constraint should not exist here!
	//We set the maximum size as that which will fit on the current screen
	BXSessionWindow *theWindow = [self window];
	NSRect screenFrame	= [[theWindow screen] visibleFrame];
	NSSize maxViewSize	= [theWindow contentRectForFrameRect: screenFrame].size;
	
	//Now clamp the size to the maximum size that will fit on screen, just in case we still overflow
	viewSize = constrainToFitSize(viewSize, maxViewSize);
	
	return viewSize;
}
@end