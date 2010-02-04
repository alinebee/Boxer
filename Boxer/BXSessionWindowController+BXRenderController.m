/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXSessionWindowController+BXRenderController.h"
#import "BXSessionWindow.h"
#import "BXEmulator+BXRendering.h"
#import "BXGeometry.h"
#import "BXSession.h"
#import "NSWindow+BXWindowSizing.h"


@implementation BXSessionWindowController (BXRenderController)

//Delegate methods
//----------------

//Drop out of fullscreen mode before showing any sheets
- (void) windowWillBeginSheet: (NSNotification *) notification
{
	[[self emulator] setFullScreen: NO];
}


//Reset the DOS renderer if its draw surface no longer matches the size of the window
- (void) windowDidResize: (NSNotification *) notification
{
	BXSessionWindow	*theWindow	= [self window];
	NSView			*SDLView	= [self SDLView];

	if (![self resizingProgrammatically] && ![renderView inLiveResize])
	{
		[[self emulator] resetRenderer];
	}
}

//Warn the emulator to prepare for emulation cutout when the resize starts
//Release input capturing also, just to be on the safe side
- (void) windowWillLiveResize:	(NSNotification *) notification
{
	[[self emulator] releaseInput];
	[[self emulator] willPause];
}

//Catch the end of a live resize event and pass it to our normal resize handler
//While we're at it, restore the input capturing (fixes duplicate cursor) and let the emulator know it can unpause now
- (void) windowDidLiveResize:	(NSNotification *) notification
{
	[self windowDidResize: notification];
	
	if ([[self window] isKeyWindow])
	{
		[[self emulator] releaseInput];
		[[self emulator] captureInput];
	}
	[[self emulator] didResume];
}

- (void) windowDidBecomeKey:	(NSNotification *) notification	{ [[self emulator] captureInput]; }
- (void) windowDidBecomeMain:	(NSNotification *) notification	{ [[self emulator] activate]; }
- (void) windowDidResignKey:	(NSNotification *) notification	{ [[self emulator] releaseInput]; }
- (void) windowDidResignMain:	(NSNotification *) notification	{ [[self emulator] deactivate]; }

//Drop out of fullscreen and warn the emulator to prepare for emulation cutout when a menu opens
- (void) menuDidOpen:	(NSNotification *) notification
{
	[[self emulator] setFullScreen: NO];
	[[self emulator] willPause];
}

//Resync input capturing (fixes duplicate cursor) and let the emulator know the coast is clear
- (void) menuDidClose:	(NSNotification *) notification
{
	if ([[self window] isKeyWindow]) [[self emulator] captureInput];
	[[self emulator] didResume];
}


//Window size calculations
//------------------------

//Return the current size of the render portal.
- (NSSize) renderViewSize	{ return [[self renderView] frame].size; }

//Returns the most appropriate view size for the intended DOSBox render size, given the size of the current window.
//This is calculated as the current view size with the aspect ratio compensated for that of the new render size: favouring the width or the height as appropriate.
//This method is called by BXEmulator+BXRendering's surfaceSizeForRenderedSize function, which in turn is called by DOSBox's internals to advise it what surface size to request from SDL.
//It's also doing too much work and needs to be refactored so that BXEmulator is making decisions about minimum size and height preservation instead of us here.
- (NSSize) viewSizeForRenderedSize: (NSSize)renderedSize minSize: (NSSize)minViewSize
{
	BXSessionWindow *theWindow = [self window];
	
	//Quick hack: if we're in the middle of a resize animation, just return the current size without constraints
	if ([self resizingProgrammatically]) return [self renderViewSize];

	
	//Work out the aspect ratio of the target render size, and how we should apply that ratio
	CGFloat aspectRatio = aspectRatioOfSize(renderedSize);
	
	//We preserve height during the aspect ratio adjustment if the new render height is equivalent to the old AND the width is not equivalent to the old; otherwise, we preserve width. (Height-locking fixes crazy-ass resolution transitions in Pinball Fantasies and The Humans, while width-locking fixes occasional rounding errors during live resizes.)
	BOOL preserveHeight = !((NSInteger)currentRenderedSize.height % (NSInteger)renderedSize.height)
						&& ((NSInteger)currentRenderedSize.width % (NSInteger)renderedSize.width);

	//We set the minimum size to be the base resolution of the DOS output,
	//and the maximum size as that which will fit on the current screen
	NSRect screenFrame	= [[theWindow screen] visibleFrame];
	NSSize maxViewSize	= [theWindow contentRectForFrameRect: screenFrame].size;


	//We start off with our current view size: we want to deviate from this as little as possible.
	NSSize viewSize = [self renderViewSize];

	//Now, adjust the view size to fit the aspect ratio of our new rendered size.
	//At the same time we clamp it to the minimum size, preserving the same dimension.
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

	//Now clamp the size to the maximum size that will fit on screen, just in case we still overflow
	viewSize = constrainToFitSize(viewSize, maxViewSize);
	
	return viewSize;
}

//Try to resize the window to accomodate the specified minimum size
//If we can't manage that size, do nothing and return NO; otherwise resize and return YES
- (BOOL) resizeToAccommodateViewSize: (NSSize) minViewSize
{
	BXSessionWindow *theWindow	= [self window];

	NSSize currentSize		= [self renderViewSize];
	//We're already that size or larger, go us!
	if (sizeFitsWithinSize(minViewSize, currentSize)) return YES;
	
	//Otherwise check if the specified size will still fit on screen
	NSRect screenFrame		= [[theWindow screen] visibleFrame];
	NSSize maxViewSize		= [theWindow contentRectForFrameRect: screenFrame].size;
	
	//If the minimum requested size won't fit on screen, bail out
	if (!sizeFitsWithinSize(minViewSize, maxViewSize)) return NO;
	
	//Otherwise carry on and resize
	[self _resizeWindowForRenderViewSize: minViewSize animate: YES];
	return YES;
}

//Zoom the DOS window in or out of fullscreen with a smooth animation
//Returns YES if the window is zooming, NO if no zoom occurs (i.e. the window is already in the correct state)
- (void) setFullScreenWithZoom: (BOOL) fullScreen
{
	BXEmulator *emulator	= [self emulator];

	//Don't bother if the emulator is already in the correct state
	if ([emulator isFullScreen] == fullScreen) return;
	 
	BXSessionWindow *theWindow	= [self window];
	
	NSInteger originalLevel		= [theWindow level];
	
	NSRect originalFrame		= [theWindow frame];
	NSRect fullscreenFrame		= [[emulator targetForFullScreen] frame];
	NSRect zoomedWindowFrame	= [theWindow frameRectForContentRect: fullscreenFrame];
	
	[emulator willPause];
	[theWindow setLevel: NSScreenSaverWindowLevel];

	//Make sure we're the key window first before any shenanigans
	[theWindow makeKeyAndOrderFront: self];
	
	if (fullScreen)
	{
		//First zoom smoothly in to fill the screen...
		[self setResizingProgrammatically: YES];
		[theWindow setFrame: zoomedWindowFrame display: YES animate: YES];
		
		//...then flip SDL into the real fullscreen mode...
		[emulator setFullScreen: YES];
		
		//...then revert our changes to the window frame, while we're hidden by the fullscreen context
		[theWindow setFrame: originalFrame display: NO];
		[self setResizingProgrammatically: NO];
	}
	else
	{
		//First quietly resize the window to fill the screen, while we're still hidden by the fullscreen context...
		[self setResizingProgrammatically: YES];
		[theWindow setFrame: zoomedWindowFrame display: NO];
		[[self SDLView] setHidden: NO];
		
		//...then flip us out of fullscreen, which will render to the zoomed window...
		[emulator setFullScreen: NO];
		
		//...then resize the window back to the original size, after permitting redraw
		[self setResizingProgrammatically: NO];
		[theWindow setFrame: originalFrame display: YES animate: YES];
	}
	
	[theWindow setLevel: originalLevel];
	[emulator didResume];
}

//Snap to multiples of the base render size as we scale
- (NSSize) windowWillResize: (BXSessionWindow *)theWindow toSize: (NSSize) proposedFrameSize
{
	//If emulation is not active, don't bother calculating constraints
	if (![[self emulator] isExecuting]) return proposedFrameSize;
	
	NSInteger snapThreshold	= [[NSUserDefaults standardUserDefaults] integerForKey: @"windowSnapDistance"];
	NSSize snapIncrement	= [[self emulator] scaledResolution];
	CGFloat aspectRatio		= aspectRatioOfSize([theWindow contentAspectRatio]);
	
	NSRect proposedFrame	= NSMakeRect(0, 0, proposedFrameSize.width, proposedFrameSize.height);
	NSRect renderFrame		= [theWindow contentRectForFrameRect:proposedFrame];
	
	CGFloat snappedWidth	= round(renderFrame.size.width / snapIncrement.width) * snapIncrement.width;
	CGFloat widthDiff		= abs(snappedWidth - renderFrame.size.width);
	if (widthDiff > 0 && widthDiff <= snapThreshold)
	{
		renderFrame.size.width = snappedWidth;
		if (aspectRatio > 0)	renderFrame.size.height = round(snappedWidth / aspectRatio);
	}
	
	NSSize newProposedSize = [theWindow frameRectForContentRect:renderFrame].size;
	
	return newProposedSize;
}


//Return an appropriate "standard" (zoomed) frame for the window given the currently available screen space.
//We define the standard frame to be the largest even multiple of the game resolution. Note that in some cases this will be equal to the standard window size, so that nothing happens when zoomed - unfortunately the cures for this are worse than the disease, so we leave it be for now.
- (NSRect) windowWillUseStandardFrame: (BXSessionWindow *)theWindow defaultFrame: (NSRect)defaultFrame
{
	if (![[self emulator] isExecuting]) return defaultFrame;
	
	NSSize scaledResolution			= [[self emulator] scaledResolution];
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
	[[self window] setFrame: newFrame display: YES animate: YES];
	if (!show)	[view setHidden: YES];	//Hide after sliding in 
}

//Resize the window frame to fit the new render size.
- (void) _resizeWindowForRenderViewSize: (NSSize)newSize animate: (BOOL)performAnimation
{
	NSSize currentSize	= [self renderViewSize];
	NSWindow *theWindow	= [self window];
	
	if (!NSEqualSizes(currentSize, newSize))
	{
		NSSize windowSize	= [theWindow frame].size;
		windowSize.width	+= newSize.width	- currentSize.width;
		windowSize.height	+= newSize.height	- currentSize.height;
		
		//Resize relative to center of titlebar
		NSRect newFrame		= resizeRectFromPoint([theWindow frame], windowSize, NSMakePoint(0.5, 1));
		//Constrain the result to fit tidily on screen
		newFrame			= [theWindow fullyConstrainFrameRect: newFrame toScreen: [theWindow screen]];
		
		[self setResizingProgrammatically: YES];
		[theWindow setFrame: NSIntegralRect(newFrame) display: YES animate: performAnimation];
		[self setResizingProgrammatically: NO];
	}
}


//Responding to SDL's entreaties
//------------------------------

- (NSWindow *) SDLWindow	{ return [self window]; }
- (NSOpenGLView *) SDLView	{ return [[[self renderView] subviews] lastObject]; }
- (NSOpenGLContext *) SDLOpenGLContext { return [[self SDLView] openGLContext]; }

- (void) prepareSDLViewForFrame: (NSRect)frame
{
	NSOpenGLView *view = [self SDLView];
	BXSessionWindow *theWindow = [self window];
	
	NSSize viewSize		= frame.size;
	NSSize originalSize	= [[self emulator] scaledResolution];	//The size the DOS game is producing
	currentRenderedSize	= [[self emulator] renderedSize];		//Record DOSBox's new rendering size, for later use in viewSizeForRenderedSize
	
	//Use the base resolution as our minimum content size, to prevent higher resolutions being rendered smaller than their effective size
	//Tweak: ...unless the base resolution is actually larger than our view size, which can happen if the base resolution is too large to fit on screen and hence the view is shrunk. In that case we use the view size as a minimum instead.
	if (viewSize.width < originalSize.width || viewSize.height < originalSize.height)
		[theWindow setContentMinSize: viewSize];
	else
		[theWindow setContentMinSize: originalSize];
	
	//Fix the window's aspect ratio to the new size - this will affect our live resizing behaviour
	[theWindow setContentAspectRatio: viewSize];
	
	//Now resize the window to fit the new size
	[self _resizeWindowForRenderViewSize: viewSize animate: YES];
	
	[view setHidden: NO];
	[view setNeedsDisplay: YES];
	
	[[view openGLContext] makeCurrentContext];
}

- (void) prepareSDLOpenGLContextWithFormat: (NSOpenGLPixelFormat *)format
{
	[[self SDLView] clearGLContext];
	[[self SDLView] setPixelFormat: format];
}

- (void) prepareSDLViewForFullscreen
{
	//Prevents contention for draw context, for some reason.
	[[self SDLView] setHidden: YES];
}

- (void) prepareSDLOpenGLContextForTeardown
{
	[NSOpenGLContext clearCurrentContext];
}

- (BOOL) handleSDLKeyboardEvent: (NSEvent *)event
{
	//If the window we are deigning to let SDL use is not the key window, then handle the event through the
	//normal NSApplication channels instead
	if (![[self window] isKeyWindow])
	{
		[NSApp sendEvent: event];
		return YES;
	}
	//If the key was a keyboard equivalent, dont let SDL process it further
	if ([[NSApp mainMenu] performKeyEquivalent: event]	|| 
		[[self window] performKeyEquivalent: event]		|| 
		[self performKeyEquivalent: event])
	{	
		return YES;
	}
	//Otherwise, let SDL do what it must with the event
	else return NO;
}

@end