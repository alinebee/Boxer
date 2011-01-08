/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDOSWindowController+BXRenderController.h"
#import "BXDOSWindow.h"
#import "BXEmulator.h"
#import "NSWindow+BXWindowSizing.h"
#import "BXInputController.h"
#import "BXFrameRenderingView.h"
#import "BXFrameBuffer.h"
#import "BXVideoHandler.h"
#import <Carbon/Carbon.h> //For SetSystemUIMode()

#import "BXGeometry.h"


const CGDisplayFadeInterval BXFullscreenFadeOutDuration	= 0.2f;
const CGDisplayFadeInterval BXFullscreenFadeInDuration	= 0.4f;
const NSInteger BXWindowSnapThreshold		= 64;
const CGFloat BXIdenticalAspectRatioDelta	= 0.025f;


//These constants are not available in 10.5
#ifndef NSApplicationPresentationOptions

NSString * const NSFullScreenModeApplicationPresentationOptions = @"NSFullScreenModeApplicationPresentationOptions";

enum {
	NSApplicationPresentationDefault                    = 0,
	NSApplicationPresentationAutoHideDock               = (1 << 0),
	NSApplicationPresentationHideDock                   = (1 << 1),
	NSApplicationPresentationAutoHideMenuBar            = (1 << 2),
	NSApplicationPresentationHideMenuBar                = (1 << 3),
	NSApplicationPresentationDisableAppleMenu           = (1 << 4),
	NSApplicationPresentationDisableProcessSwitching    = (1 << 5),
	NSApplicationPresentationDisableForceQuit           = (1 << 6),
	NSApplicationPresentationDisableSessionTermination  = (1 << 7),
	NSApplicationPresentationDisableHideApplication     = (1 << 8),
	NSApplicationPresentationDisableMenuBarTransparency = (1 << 9)
};
typedef NSUInteger NSApplicationPresentationOptions;
#endif


@interface BXDOSWindowController ()

//Apply the switch to fullscreen mode. Used internally by setFullScreen: and setFullScreenWithZoom:
- (void) _applyFullScreenState: (BOOL)fullScreen;

//Resize the window if needed to accomodate the specified frame.
//Returns YES if the window was actually resized, NO otherwise.
- (BOOL) _resizeToAccommodateFrame: (BXFrameBuffer *)frame;

//Returns the view size that should be used for rendering the specified frame.
- (NSSize) _renderingViewSizeForFrame: (BXFrameBuffer *)frame minSize: (NSSize)minViewSize;

@end

@implementation BXDOSWindowController (BXRenderController)

#pragma mark -
#pragma mark DOSBox frame rendering

- (void) updateWithFrame: (BXFrameBuffer *)frame
{
	//Update the renderer with the new frame.
	[renderingView updateWithFrame: frame];

	if (frame != nil)
	{		
		//Resize the window to accomodate the frame.
		//IMPLEMENTATION NOTE: We do this after only updating the view, because the frame
		//immediately *before* a resize is usually (always?) video-buffer garbage.
		//This way, we have the brand-new frame visible in the view while we stretch
		//it to the intended size, instead of leaving the garbage frame in the view.
		
		//TODO: let BXRenderingView handle this by changing its bounds, and listen for
		//bounds-change notifications so we can resize the window to match
		[self _resizeToAccommodateFrame: frame];
	}
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
- (NSSize) windowedRenderingViewSize { return [[self viewContainer] bounds].size; }

- (void) setFrameAutosaveName: (NSString *)savedName
{
	NSSize initialSize = [self windowedRenderingViewSize];
	CGFloat initialAspectRatio = aspectRatioOfSize(initialSize);
	
	//This will resize the window to the frame size saved with the specified name
	if ([[self window] setFrameAutosaveName: savedName])
	{
		NSSize loadedSize = [self windowedRenderingViewSize];
		CGFloat loadedAspectRatio = aspectRatioOfSize(loadedSize);
		
		//If the loaded size had a different aspect ratio to the size we had before,
		//adjust the loaded size accordingly
		if (ABS(loadedAspectRatio - initialAspectRatio) > BXIdenticalAspectRatioDelta)
		{
			NSSize adjustedSize = loadedSize;
			adjustedSize.height = adjustedSize.width / initialAspectRatio;
			[self resizeWindowToRenderingViewSize: adjustedSize animate: NO];
		}		
	}
}

- (NSScreen *) fullScreenTarget
{
	//TODO: should we switch this to the screen that the our window is on?
	return [NSScreen mainScreen];
}

- (NSWindow *) fullScreenWindow
{
	if ([self isFullScreen]) return [inputView window];
	else return nil;
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
	CGError acquiredToken;
	CGDisplayFadeReservationToken fadeToken;
	
	acquiredToken = CGAcquireDisplayFadeReservation(BXFullscreenFadeOutDuration + BXFullscreenFadeInDuration, &fadeToken);
	
	//First fade out to black synchronously
	if (acquiredToken == kCGErrorSuccess)
	{
		CGDisplayFade(fadeToken,
					  BXFullscreenFadeOutDuration,	//Fade duration
					  (CGDisplayBlendFraction)kCGDisplayBlendNormal,		//Start transparent
					  (CGDisplayBlendFraction)kCGDisplayBlendSolidColor,	//Fade to opaque
					  0.0f, 0.0f, 0.0f,				//Pure black (R, G, B)
					  true							//Synchronous
					  );
	}
	
	//Now actually switch to fullscreen mode
	[self _applyFullScreenState: fullScreen];
	
	//And now fade back in from black asynchronously
	if (acquiredToken == kCGErrorSuccess)
	{
		CGDisplayFade(fadeToken,
					  BXFullscreenFadeInDuration,	//Fade duration
					  (CGDisplayBlendFraction)kCGDisplayBlendSolidColor,	//Start opaque
					  (CGDisplayBlendFraction)kCGDisplayBlendNormal,		//Fade to transparent
					  0.0f, 0.0f, 0.0f,				//Pure black (R, G, B)
					  false							//Asynchronous
					  );
	}
	CGReleaseDisplayFadeReservation(fadeToken);
}

//Zoom the DOS window in or out of fullscreen with a smooth animation
- (void) setFullScreenWithZoom: (BOOL) fullScreen
{	
	//Don't bother if we're already in the correct fullscreen state
	if ([self isFullScreen] == fullScreen) return;
	
	//Let the emulator know it'll be blocked from emulating for a while
	[[[self document] emulator] willPause];
	
	NSWindow *theWindow			= [self window];
	NSRect originalFrame		= [theWindow frame];
	NSRect fullscreenFrame		= [[self fullScreenTarget] frame];
	NSRect zoomedWindowFrame	= [theWindow frameRectForContentRect: fullscreenFrame];
	
	//Set up the chromeless window we'll use for the fade effect
	NSPanel *blankingWindow = [[NSPanel alloc] initWithContentRect: NSZeroRect
														 styleMask: NSBorderlessWindowMask
														   backing: NSBackingStoreBuffered
															 defer: YES];
	
	[blankingWindow setOneShot: YES];
	[blankingWindow setReleasedWhenClosed: YES];
	[blankingWindow setFrame: fullscreenFrame display: NO];
	[blankingWindow setBackgroundColor: [NSColor blackColor]];
	
	
	//Prepare the zoom-and-fade animation effects
	NSRect endFrame			= (fullScreen) ? zoomedWindowFrame : originalFrame;
	NSString *fadeDirection	= (fullScreen) ? NSViewAnimationFadeInEffect : NSViewAnimationFadeOutEffect;
	
	NSDictionary *fadeEffect	= [[NSDictionary alloc] initWithObjectsAndKeys:
								   blankingWindow, NSViewAnimationTargetKey,
								   fadeDirection, NSViewAnimationEffectKey,
								   nil];
	
	NSDictionary *resizeEffect	= [[NSDictionary alloc] initWithObjectsAndKeys:
								   theWindow, NSViewAnimationTargetKey,
								   [NSValue valueWithRect: endFrame], NSViewAnimationEndFrameKey,
								   nil];
	
	NSArray *effects = [[NSArray alloc] initWithObjects: fadeEffect, resizeEffect, nil];
	NSViewAnimation *animation = [[NSViewAnimation alloc] initWithViewAnimations: effects];
	[animation setAnimationBlockingMode: NSAnimationBlocking];
	
	[fadeEffect release];
	[resizeEffect release];
	[effects release];
	
	[self setResizingProgrammatically: YES];
	if (fullScreen)
	{
		SetSystemUIMode(kUIModeAllHidden, kUIOptionAutoShowMenuBar);
		
		//Tell the rendering view to start managing aspect ratio correction early,
		//so that the aspect ratio appears correct while resizing to fill the window
		[[self renderingView] setManagesAspectRatio: YES];
		
		//Bring the blanking window in behind the DOS window, hidden
		[blankingWindow setAlphaValue: 0.0f];
		[blankingWindow orderWindow: NSWindowBelow relativeTo: [theWindow windowNumber]];
		
		//Run the zoome-and-fade animation
		[animation setDuration: [theWindow animationResizeTime: endFrame]];
		[animation startAnimation];
				
		//Hide the blanking window, and flip the view into fullscreen mode
		[blankingWindow orderOut: self];
		[self _applyFullScreenState: fullScreen];
		
		//Revert the window back to its original size, while it's hidden by the fullscreen view
		//We do this so that the window's autosaved frame doesn't get messed up, and so that we
		//don't have to track the window's former size independently while we're in fullscreen mode.
		[theWindow setFrame: originalFrame display: NO];
	}
	else
	{
		//Resize the DOS window to fill the screen behind the fullscreen window;
		//Otherwise, the empty normal-sized window may be visible for a single frame
		//after switching out of fullscreen mode
		[theWindow orderBack: self];
		[theWindow setFrame: zoomedWindowFrame display: NO];
		
		//Flip the view out of fullscreen, which will return it to the zoomed window
		[self _applyFullScreenState: fullScreen];
		
		//Bring the blanking window in behind the DOS window, ready for animating
		[blankingWindow orderWindow: NSWindowBelow relativeTo: [theWindow windowNumber]];
		
		//Tell the view to continue managing aspect ratio while we resize,
		//overriding setFullScreen's original behaviour
		[[self renderingView] setManagesAspectRatio: YES];
		
		//Run the zoom-and-fade animation
		//(we calculate duration now since we've only just resized the window to its full extent)
		[animation setDuration: [theWindow animationResizeTime: endFrame]];
		[animation startAnimation];
		
		//Finally tell the view to stop managing aspect ratio again
		[[self renderingView] setManagesAspectRatio: NO];
		
		SetSystemUIMode(kUIModeNormal, 0);
	}
	[self setResizingProgrammatically: NO];
	
	[[[self document] emulator] didResume];
	
	[blankingWindow close];
	[animation release];
	
}

//Snap to multiples of the base render size as we scale
- (NSSize) windowWillResize: (BXDOSWindow *)theWindow toSize: (NSSize) proposedFrameSize
{
	//Used to be: [[NSUserDefaults standardUserDefaults] integerForKey: @"windowSnapDistance"];
	//But is now constant while developing to find the ideal default value
	NSInteger snapThreshold	= BXWindowSnapThreshold;
	
	NSSize snapIncrement	= [[renderingView currentFrame] scaledResolution];
	CGFloat aspectRatio		= aspectRatioOfSize([theWindow contentAspectRatio]);
	
	NSRect proposedFrame	= NSMakeRect(0, 0, proposedFrameSize.width, proposedFrameSize.height);
	NSRect renderFrame		= [theWindow contentRectForFrameRect:proposedFrame];
	
	CGFloat snappedWidth	= roundf(renderFrame.size.width / snapIncrement.width) * snapIncrement.width;
	CGFloat widthDiff		= abs(snappedWidth - renderFrame.size.width);
	if (widthDiff > 0 && widthDiff <= snapThreshold)
	{
		renderFrame.size.width = snappedWidth;
		if (aspectRatio > 0) renderFrame.size.height = roundf(snappedWidth / aspectRatio);
	}
	
	NSSize newProposedSize = [theWindow frameRectForContentRect:renderFrame].size;
	
	return newProposedSize;
}


//Return an appropriate "standard" (zoomed) frame for the window given the currently available screen space.
//We define the standard frame to be the largest multiple of the game resolution, maintaining aspect ratio.
- (NSRect) windowWillUseStandardFrame: (BXDOSWindow *)theWindow defaultFrame: (NSRect)defaultFrame
{
	if (![[[self document] emulator] isExecuting]) return defaultFrame;
	
	NSRect standardFrame;
	NSRect currentWindowFrame		= [theWindow frame];
	NSRect defaultViewFrame			= [theWindow contentRectForFrameRect: defaultFrame];
	NSRect largestCleanViewFrame	= defaultViewFrame;
	
	//Constrain the proposed view frame to the largest even multiple of the base resolution
	
	//Disabled for now: our scaling is good enough now that we can afford to scale to uneven
	//multiples, and this way we avoid returning a size that's the same as the current size
	//(which makes the zoom button to appear to do nothing.)
	
	/*
	CGFloat aspectRatio				= aspectRatioOfSize([theWindow contentAspectRatio]);
	NSSize scaledResolution			= [[renderingView currentFrame] scaledResolution];
	 
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


#pragma mark -
#pragma mark Private methods

- (void) _applyFullScreenState: (BOOL)fullScreen
{
	[self willChangeValueForKey: @"fullScreen"];
	
	NSView *theView					= (NSView *)[self inputView];
	NSView *theContainer			= [self viewContainer]; 
	NSWindow *theWindow				= [self window];
	NSResponder *currentResponder	= [theView nextResponder];
	
	if (fullScreen)
	{
		NSScreen *targetScreen	= [self fullScreenTarget];
		
		//Flip the view into fullscreen mode
		NSApplicationPresentationOptions presentationOptions = NSApplicationPresentationHideDock | NSApplicationPresentationAutoHideMenuBar;
		NSDictionary *fullscreenOptions = [NSDictionary dictionaryWithObjectsAndKeys:
										   [NSNumber numberWithBool: NO], NSFullScreenModeAllScreens,
										   [NSNumber numberWithUnsignedInteger: presentationOptions], NSFullScreenModeApplicationPresentationOptions,
										   nil];
		
		//Remove ourselves as the old window delegate so that we don't receive
		//loss-of-focus notifications when switching to fullscreen
		[theWindow setDelegate: nil];
		
		[theView enterFullScreenMode: targetScreen withOptions: fullscreenOptions];
		
		NSWindow *fullscreenWindow = [self fullScreenWindow];
		
		//Hide the old window altogether
		[theWindow orderOut: self];
		
		//Adopt the fullscreen window, and reset the view's responder back to what it was
		//before the fullscreen window took it.
		[theWindow setDelegate: self];
		
		[fullscreenWindow setDelegate: self];
		[fullscreenWindow setWindowController: self];
		[theView setNextResponder: currentResponder];
		
		//Ensure that the mouse is locked for fullscreen mode
		[inputController setMouseLocked: YES];
		
		//Let the rendering view manage aspect ratio correction while in fullscreen mode
		[[self renderingView] setManagesAspectRatio: YES];
	}
	else
	{
		NSWindow *fullscreenWindow = [self fullScreenWindow];
		
		[fullscreenWindow setDelegate: nil];
		[fullscreenWindow setWindowController: nil];
		
		[theWindow orderWindow: NSWindowBelow relativeTo: [fullscreenWindow windowNumber]];
		
		[theView exitFullScreenModeWithOptions: nil];
		
		[theWindow makeKeyAndOrderFront: self];
		
		//Reset the view's frame to match its loyal container, as otherwise it retains its fullscreen frame size
		[theView setFrame: [theContainer bounds]];
		[theView setNeedsDisplay: YES];
		
		//Reset the responders to what they should be, since exitFullScreenModeWithOptions: screws with them
		[theWindow setDelegate: self];
		[theWindow makeFirstResponder: theView];
		[theView setNextResponder: currentResponder];
		
		//Unlock the mouse after leaving fullscreen
		[inputController setMouseLocked: NO];
		
		//Tell the rendering view to stop managing aspect ratio correction
		[[self renderingView] setManagesAspectRatio: NO];
	}
	//Kick the emulator's renderer to adjust to the new viewport size
	[[[[self document] emulator] videoHandler] reset];
	
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
		[self resizeWindowToRenderingViewSize: viewSize animate: YES];
		[[self window] setContentAspectRatio: viewSize];
	}
	
	currentScaledSize = scaledSize;
	currentScaledResolution = scaledResolution;
	
	return needsResize;
}

//Resize the window frame to the requested render size.
- (void) resizeWindowToRenderingViewSize: (NSSize)newSize animate: (BOOL)performAnimation
{
	NSWindow *theWindow	= [self window];
	NSSize currentSize	= [self windowedRenderingViewSize];
	
	if (!NSEqualSizes(currentSize, newSize))
	{
		NSSize windowSize	= [theWindow frame].size;
		windowSize.width	+= newSize.width	- currentSize.width;
		windowSize.height	+= newSize.height	- currentSize.height;
		
		//Resize relative to center of titlebar
		NSRect newFrame		= resizeRectFromPoint([theWindow frame], windowSize, NSMakePoint(0.5f, 1.0f));
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
		//We preserve height during the aspect ratio adjustment if the new height is equal to the old,
		//and if we're not setting the size for the first time.
		BOOL preserveHeight =	!NSEqualSizes(currentScaledSize, NSZeroSize) &&
								!((NSInteger)currentScaledSize.height % (NSInteger)scaledSize.height);
		
		//Now, adjust the view size to fit the aspect ratio of our new rendered size.
		//At the same time we clamp it to the minimum size, preserving the preferred dimension.
		if (preserveHeight)
		{
			if (minViewSize.height > viewSize.height) viewSize = minViewSize;
			viewSize.width = roundf(viewSize.height * aspectRatio);
		}
		else
		{
			if (minViewSize.width > viewSize.width) viewSize = minViewSize;
			viewSize.height = roundf(viewSize.width / aspectRatio);
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
