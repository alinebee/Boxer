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
#import "BXInputController.h"
#import "BXFrameRenderingView.h"
#import "BXFrameBuffer.h"
#import "BXVideoHandler.h"

#import "BXGeometry.h"


const CGFloat BXFullscreenFadeOutDuration	= 0.2;
const CGFloat BXFullscreenFadeInDuration	= 0.4;
const NSInteger BXWindowSnapThreshold		= 64;
const CGFloat BXIdenticalAspectRatioDelta	= 0.025;

@implementation BXSessionWindowController (BXRenderController)

#pragma mark -
#pragma mark DOSBox frame rendering

- (void) updateWithFrame: (BXFrameBuffer *)frame
{
	//Update the renderer with the new frame.
	[renderingView updateWithFrame: frame];

	//Resize the window to accomodate the frame.
	//IMPLEMENTATION NOTE: We do this after only updating the view, because the frame
	//immediately *before* a resize is usually (always?) video-buffer garbage.
	//This way, we have the brand-new frame visible in the view while we stretch
	//it to the intended size, instead of leaving the garbage frame in the view.
	BOOL didResize = [self _resizeToAccommodateFrame: frame];
}

- (NSSize) viewportSize
{
	return [renderingView viewportSize];
}

- (NSSize) maxFrameSize
{
	return [renderingView maxFrameSize];
}

#pragma mark -
#pragma mark Window resizing and fullscreen

- (BOOL) isResizing
{
	return [self resizingProgrammatically] || [inputView inLiveResize];
}

//Returns the current size that the render view would be if it were in windowed mode.
//This will differ from the actual render view size when in fullscreen mode.
- (NSSize) windowedRenderingViewSize	{ return [[self viewContainer] bounds].size; }


- (NSScreen *) fullScreenTarget
{
	//TODO: should we switch this to the screen that the our window is on?
	return [NSScreen mainScreen];
}

- (BOOL) isFullScreen
{
	return [inputView isInFullScreenMode];
}

//Switch the DOS window in or out of fullscreen with a brief fade
- (void) setFullScreen: (BOOL)fullScreen
{
	//Don't bother if we're already in the desired fullscreen state
	if ([self isFullScreen] == fullScreen) return;
	
	//Set up a screen fade in and out of the fullscreen mode
	CGError acquiredToken, fadedOut, fadedIn;
	CGDisplayFadeReservationToken fadeToken;
	
	acquiredToken = CGAcquireDisplayFadeReservation(kCGMaxDisplayReservationInterval, &fadeToken);
	
	//First fade out to black synchronously
	if (acquiredToken == kCGErrorSuccess)
	{
		CGError fadedOut = CGDisplayFade(fadeToken,
										 BXFullscreenFadeOutDuration,	//Fade duration
										 kCGDisplayBlendNormal,			//Start transparent
										 kCGDisplayBlendSolidColor,		//Fade to opaque
										 0.0, 0.0, 0.0,					//Pure black (R, G, B)
										 true							//Synchronous
										 );
	}
	
	//Now actually switch to fullscreen mode
	[self _applyFullScreenState: fullScreen];
	
	//And now fade back in from black asynchronously
	if (acquiredToken == kCGErrorSuccess)
	{
		CGError fadedIn = CGDisplayFade(fadeToken,
										BXFullscreenFadeInDuration,	//Fade duration
										kCGDisplayBlendSolidColor,	//Start opaque
										kCGDisplayBlendNormal,		//Fade to transparent
										0.0, 0.0, 0.0,				//Pure black (R, G, B)
										false						//Asynchronous
										);
	}
	CGReleaseDisplayFadeReservation(fadeToken);
}

//Zoom the DOS window in or out of fullscreen with a smooth animation
- (void) setFullScreenWithZoom: (BOOL) fullScreen
{	
	//Don't bother if we're already in the correct fullscreen state
	if ([self isFullScreen] == fullScreen) return;
	
	NSWindow *theWindow			= [self window];
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
		//Tell the rendering view to start managing aspect ratio correction early,
		//so that the aspect ratio appears correct while resizing to fill the window
		[[self renderingView] setManagesAspectRatio: YES];
		
		//First zoom smoothly in to fill the screen...
		[theWindow setFrame: zoomedWindowFrame display: YES animate: YES];
				
		//Then flip the view into fullscreen mode...
		[self _applyFullScreenState: fullScreen];
		
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
		[self _applyFullScreenState: fullScreen];
		
		//Tell the view to continue managing aspect ratio while we resize,
		//overriding setFullScreen's original behaviour
		[[self renderingView] setManagesAspectRatio: YES];
		
		//...then resize the window back to its original size
		[theWindow setFrame: originalFrame display: YES animate: YES];
		
		//Finally tell the view to stop managing aspect ratio again
		[[self renderingView] setManagesAspectRatio: NO];
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

	//Used to be: [[NSUserDefaults standardUserDefaults] integerForKey: @"windowSnapDistance"];
	//But is now constant while developing to find the ideal default value
	NSInteger snapThreshold	= BXWindowSnapThreshold;
	
	NSSize snapIncrement	= [[renderingView currentFrame] scaledResolution];
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
//We define the standard frame to be the largest multiple of the game resolution, maintaining aspect ratio.
- (NSRect) windowWillUseStandardFrame: (BXSessionWindow *)theWindow defaultFrame: (NSRect)defaultFrame
{
	if (![[self emulator] isExecuting]) return defaultFrame;
	
	NSSize scaledResolution			= [[renderingView currentFrame] scaledResolution];
	CGFloat aspectRatio				= aspectRatioOfSize([theWindow contentAspectRatio]);
	
	NSRect standardFrame;
	NSRect currentWindowFrame		= [theWindow frame];
	NSRect defaultViewFrame			= [theWindow contentRectForFrameRect: defaultFrame];
	NSRect largestCleanViewFrame	= defaultViewFrame;
	
	//Constrain the proposed view frame to the largest even multiple of the base resolution
	
	//Disabled for now: our scaling is good enough now that we can afford to scale to uneven
	//multiples, and this way we avoid returning a size that's the same as the current size
	//(which makes the zoom button to appear to do nothing.)
	
	/*
	largestCleanViewFrame.size.width -= ((NSInteger)defaultViewFrame.size.width % (NSInteger)scaledResolution.width);
	if (aspectRatio > 0)
		largestCleanViewFrame.size.height = round(largestCleanViewFrame.size.width / aspectRatio);
	*/
	
	//Turn our new constrained view frame back into a suitably positioned window frame
	standardFrame = [theWindow frameRectForContentRect: largestCleanViewFrame];	
	
	//Carry over the top-left corner position from the original window
	standardFrame.origin	= currentWindowFrame.origin;
	standardFrame.origin.y += (currentWindowFrame.size.height - standardFrame.size.height);
	
	return standardFrame;
}
@end


@implementation BXSessionWindowController (BXRenderControllerInternals)

- (void) _applyFullScreenState: (BOOL)fullScreen
{
	[self willChangeValueForKey: @"fullScreen"];
	
	NSView *theView					= [self inputView];
	NSView *theContainer			= [self viewContainer]; 
	NSWindow *theWindow				= [self window];
	NSResponder *currentResponder	= [theView nextResponder];
	
	if (fullScreen)
	{
		NSScreen *targetScreen	= [self fullScreenTarget];
		
		//Flip the view into fullscreen mode
		[theView enterFullScreenMode: targetScreen withOptions: nil];
		
		//Reset the responders to what they should be, since enterFullScreenMode: screws with them
		[theWindow makeFirstResponder: theView];
		[theView setNextResponder: currentResponder];
		
		//Ensure that the mouse is locked for fullscreen mode
		[inputController setMouseLocked: YES];
		
		//Tell the rendering view to manage aspect ratio correction in fullscreen mode
		[[self renderingView] setManagesAspectRatio: YES];
	}
	else
	{
		[theView exitFullScreenModeWithOptions: nil];
		
		//Tell the rendering view to stop managing aspect ratio correction
		[[self renderingView] setManagesAspectRatio: NO];
		
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
		[inputController setMouseLocked: NO];
	}
	//Kick the emulator's renderer to adjust to the new viewport size
	[[[self emulator] videoHandler] reset];
	
	[self didChangeValueForKey: @"fullScreen"];
}

- (BOOL) _resizeToAccommodateFrame: (BXFrameBuffer *)frame
{
	NSSize scaledSize		= [frame scaledSize];
	NSSize scaledResolution	= [frame scaledResolution];
	
	NSSize viewSize			= [self windowedRenderingViewSize];
	BOOL needsResize		= NO;
	BOOL needsNewMinSize	= NO;
	
	//Only resize the window if the frame size is different from its previous size
	if (!NSEqualSizes(currentScaledSize, scaledSize))
	{
		viewSize = [self _renderingViewSizeForFrame: frame minSize: scaledResolution];
		needsResize = YES;
		needsNewMinSize = YES;
	}
	else if (!NSEqualSizes(currentScaledResolution, scaledResolution))
	{
		needsNewMinSize = YES;
	}
		
	if (needsNewMinSize)
	{
		//Use the base resolution as our minimum content size, to prevent higher resolutions
		//being rendered smaller than their effective size
		NSSize minSize = scaledResolution;
	
		//Tweak: ...unless the base resolution is actually larger than our view size, which can happen 
		//if the base resolution is too large to fit on screen and hence the view is shrunk.
		//In that case we use the target view size as the minimum instead.
		if (!sizeFitsWithinSize(scaledResolution, viewSize)) minSize = viewSize;

		[[self window] setContentMinSize: minSize];
	}
	
	//Now resize the window to fit the new size and lock its aspect ratio
	if (needsResize)
	{
		[self _resizeWindowToRenderingViewSize: viewSize animate: YES];
		[[self window] setContentAspectRatio: viewSize];
	}
	
	currentScaledSize = scaledSize;
	currentScaledResolution = scaledResolution;
	
	return needsResize;
}


//Performs the slide animation used to toggle the status bar and program panel on or off
- (void) _slideView: (NSView *)view shown: (BOOL)show
{
	NSRect newFrame	= [[self window] frame];
	
	CGFloat height	= [view frame].size.height;
	if (!show) height = -height;
	
	newFrame.size.height	+= height;
	newFrame.origin.y		-= height;
	
	if (show) [view setHidden: NO];	//Unhide before sliding out
	if ([self isFullScreen])
	{
		[[self window] setFrame: newFrame display: NO];
	}
	else
	{
		[[self window] setFrame: newFrame display: YES animate: YES];
	}

	if (!show) [view setHidden: YES]; //Hide after sliding in 
}

//Resize the window frame to the requested render size.
- (void) _resizeWindowToRenderingViewSize: (NSSize)newSize animate: (BOOL)performAnimation
{
	NSWindow *theWindow	= [self window];
	NSSize currentSize	= [self windowedRenderingViewSize];
	
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
- (NSSize) _renderingViewSizeForFrame: (BXFrameBuffer *)frame minSize: (NSSize)minViewSize
{	
	//Start off with our current view size: we want to deviate from this as little as possible.
	NSSize viewSize = [self windowedRenderingViewSize];
	
	NSSize scaledSize = [frame scaledSize];
	
	//Work out the aspect ratio of the scaled size, and how we should apply that ratio
	CGFloat aspectRatio = aspectRatioOfSize(scaledSize);
	CGFloat currentAspectRatio = aspectRatioOfSize(viewSize);
	
	//If there's only a negligible difference in aspect ratio, then just use the current
	//or minimum view size (whichever is larger) to eliminate rounding errors.
	if (ABS(aspectRatio - currentAspectRatio) < BXIdenticalAspectRatioDelta)
	{
		viewSize = sizeFitsWithinSize(minViewSize, viewSize) ? viewSize : minViewSize;
	}
	//Otherwise, try to work out the most appropriate window shape to resize to
	else
	{
		//We preserve height during the aspect ratio adjustment if the new height is equivalent to the old.
		//Height-locking fixes crazy-ass resolution transitions in Pinball Fantasies and The Humans.
		BOOL preserveHeight = !((NSInteger)currentScaledSize.height	% (NSInteger)scaledSize.height);
		
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
	}
	
	//We set the maximum size as that which will fit on the current screen
	NSRect screenFrame	= [[[self window] screen] visibleFrame];
	NSSize maxViewSize	= [[self window] contentRectForFrameRect: screenFrame].size;
	//Now clamp the size to the maximum size that will fit on screen, just in case we still overflow
	viewSize = constrainToFitSize(viewSize, maxViewSize);
	
	return viewSize;
}
@end