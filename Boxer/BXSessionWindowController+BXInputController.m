/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXSessionWindowController+BXInputController.h"
#import "BXSessionWindowController+BXRenderController.h"
#import "BXRenderView.h"
#import "BXEmulator.h"
#import "BXEmulatorEventResponder.h"

@implementation BXSessionWindowController (BXInputController)

#pragma mark -
#pragma mark Monitoring application state

//Warn the emulator to prepare for emulation cutout when the resize starts
- (void) windowWillLiveResize: (NSNotification *) notification
{
	[[self emulator] willPause];
}

//Catch the end of a live resize event and pass it to our normal resize handler
//While we're at it, let the emulator know it can unpause now
- (void) windowDidLiveResize: (NSNotification *) notification
{
	[self windowDidResize: notification];
	[[self emulator] didResume];
}

- (void) windowDidResignKey:	(NSNotification *) notification
{
	//Don't resign key when we're in fullscreen mode
	//FIXME: work out why this is happening in the first place!
	if ([self isFullScreen]) {
		[[self window] makeKeyWindow];
	}
	else
	{
		[self setMouseLocked: NO];
	}
}
- (void) windowDidResignMain:	(NSNotification *) notification
{
	//Don't resign main when we're in fullscreen mode
	//FIXME: work out why this is happening in the first place!
	if ([self isFullScreen]) {
		[[self window] makeMainWindow];	
	}
	else
	{
		[self setMouseLocked: NO];
	}
}

//Drop out of fullscreen and warn the emulator to prepare for emulation cutout when a menu opens
- (void) menuDidOpen:	(NSNotification *) notification
{
	[self setFullScreen: NO];
	[[self emulator] willPause];
}

//Resync input capturing (fixes duplicate cursor) and let the emulator know the coast is clear
- (void) menuDidClose:	(NSNotification *) notification
{
	if ([[self window] isKeyWindow]) [[self emulator] captureInput];
	[[self emulator] didResume];
}


#pragma mark -
#pragma mark Cursor handling

- (BOOL) mouseInView
{
	if ([renderView isInFullScreenMode] || [self mouseLocked]) return YES;
	
	NSPoint mouseLocation = [[self window] mouseLocationOutsideOfEventStream];
	NSPoint pointInView = [renderView convertPoint: mouseLocation fromView: nil];
	return [renderView mouse: pointInView inRect: [renderView bounds]];
}

- (void) setMouseActive: (BOOL)active
{
	[self willChangeValueForKey: @"mouseActive"];
	mouseActive = active;
	[self cursorUpdate: nil];
	[self didChangeValueForKey: @"mouseActive"];
}

- (NSCursor *)hiddenCursor
{
	//If we don't have a hidden cursor yet, generate it now
	if (!hiddenCursor)
	{
		NSCursor *arrowCursor	= [NSCursor arrowCursor];
		NSImage *arrowImage		= [arrowCursor image];
		NSImage *blankImage		= [[NSImage alloc] initWithSize: [arrowImage size]];
		
		//Use a faded cursor instead of an entirely blank one.
		//This is disabled for now because it looks quite distracting.
		/*
		 [blankImage lockFocus];
		 [arrowImage drawAtPoint: NSZeroPoint fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 0.25];
		 [blankImage unlockFocus];
		 */
		
		NSCursor *blankCursor = [[NSCursor alloc] initWithImage: blankImage hotSpot: [arrowCursor hotSpot]];
		[self setHiddenCursor: blankCursor];
		[blankImage release];
		[blankCursor release];
	}
	return hiddenCursor;
}


#pragma mark -
#pragma mark Event responding

- (void) cursorUpdate: (NSEvent *)theEvent
{
	//TODO: figure out why cursor is getting reset when view changes dimensions
	if ([self mouseActive] && [self mouseInView])
	{
		[[self hiddenCursor] set];
	}
}

- (void) mouseDown: (NSEvent *)theEvent
{
	//Cmd-left-click toggles mouse-locking
	if ([self mouseActive] && [self mouseInView] && [theEvent modifierFlags] & NSCommandKeyMask)
		[self toggleMouseLocked: self];
	//Otherwise, pass the click on
	else [super mouseDown: theEvent];
}

- (void) mouseMoved: (NSEvent *)theEvent
{
	//Work out mouse motion relative to the DOS viewport canvas,
	//and pass that on as a relative point to the emulator's event handler
	
	NSPoint relativePosition;
	NSPoint relativeDelta;
	NSRect canvas;

	if ([self mouseLocked])
	{
		//While we're mouselocked and the cursor is disassociated,
		//we can't get an absolute mouse position - so we have
		//to calculate it from the last known position. We store this
		//as a 0-1 ratio of the canvas rather than as a fixed unit position,
		//so that it doesn't get muddled up by changes to the view size.
		
		canvas = [[[self window] screen] frame];
		relativeDelta = NSMakePoint([theEvent deltaX] / canvas.size.width,
									-[theEvent deltaY] / canvas.size.height);
		//Update the last known position with the new mouse delta
		lastMousePosition.x += relativeDelta.x;
		lastMousePosition.y += relativeDelta.y;
		//Clamp the axes to 0.0 and 1.0
		lastMousePosition.x = fmaxf(fminf(lastMousePosition.x, 1.0), 0.0);
		lastMousePosition.y = fmaxf(fminf(lastMousePosition.y, 1.0), 0.0);
		
		relativePosition = lastMousePosition;
	}
	else
	{
		canvas = [renderView bounds];
		NSPoint pointInView	= [renderView convertPoint: [theEvent locationInWindow] fromView: nil];
		
		relativeDelta		= NSMakePoint([theEvent deltaX] / canvas.size.width,
										  -[theEvent deltaY] / canvas.size.height);
		relativePosition	= NSMakePoint(pointInView.x / canvas.size.width,
										  pointInView.y / canvas.size.height);
		
		//Record the location so that we can use it next time
		lastMousePosition = relativePosition;
	}
	
	[[[self emulator] eventHandler] mouseMovedToPoint: relativePosition
											 byAmount: relativeDelta
											 onCanvas: canvas
										  whileLocked: [self mouseLocked]];
}

- (void) mouseDragged: (NSEvent *)theEvent
{
	//Only pass on mouse drag events when they're inside the window
	//This way, we don't catch dragging the window itself around
	if ([self mouseInView]) [self mouseMoved: theEvent];
}
- (void) rightMouseDragged: (NSEvent *)theEvent	{ return [self mouseDragged: theEvent]; }
- (void) otherMouseDragged: (NSEvent *)theEvent	{ return [self mouseDragged: theEvent]; }


- (void) mouseExited: (NSEvent *)theEvent
{
	[self willChangeValueForKey: @"mouseInView"];
	[super mouseExited: theEvent];
	[self didChangeValueForKey: @"mouseInView"];
}

- (void) mouseEntered: (NSEvent *)theEvent
{
	[self willChangeValueForKey: @"mouseInView"];
	[super mouseEntered: theEvent];
	[self didChangeValueForKey: @"mouseInView"];
}

- (void) cancelOperation: (id)sender
{
	//Exit fullscreen when ESC is pressed and we are at the DOS prompt.
	if ([self isFullScreen] && ![[self emulator] isRunningProcess])
	{
		[self exitFullScreen: self];
	}
	//Otherwise, send the event that triggered this cancellation over to the emulator.
	else [[[self emulator] eventHandler] keyDown: [NSApp currentEvent]];
}

#pragma mark -
#pragma mark Mouse focus and locking 
- (void) setMouseLocked: (BOOL)lock
{
	//Don't continue if we're already in the right lock state
	if (lock == [self mouseLocked]) return;
	
	//Don't allow the mouse to be unlocked while in fullscreen mode
	if ([self isFullScreen] && !lock) return;
	
	//Don't allow the mouse to be locked if the game hasn't requested mouse locking
	if (![self mouseActive] && lock) return;
	
	
	//If we got this far, go ahead!
	[self willChangeValueForKey: @"mouseLocked"];
	
	mouseLocked = lock;
	
	//Ensure we don't "over-hide" the cursor if it's already hidden
	//(since [NSCursor hide] stacks)
	BOOL cursorVisible = CGCursorIsVisible();
	
	if		(cursorVisible && lock)		[NSCursor hide];
	else if (!cursorVisible && !lock)	[NSCursor unhide];
	
	//Lock/unlock the mouse and the OS X cursor
	CGAssociateMouseAndMouseCursorPosition(!lock);
	
	//When unlocking, warp the cursor to the equivalent screen position it would have moved to while locked.
	if (!lock)
	{
		NSRect canvas = [renderView bounds];
		NSPoint pointInView = NSMakePoint(lastMousePosition.x * canvas.size.width,
										  lastMousePosition.y * canvas.size.height);
		
		NSPoint pointOnScreen	= [[self window] convertBaseToScreen: [renderView convertPointToBase: pointInView]];
		CGPoint cgPointOnScreen	= NSPointToCGPoint(pointOnScreen);
		
		//Correct for CG's top-left origin
		NSRect screenFrame = [[[self window] screen] frame];
		cgPointOnScreen.y = screenFrame.size.height - screenFrame.origin.y - cgPointOnScreen.y;
		CGWarpMouseCursorPosition(cgPointOnScreen);
	}
	
	[self didChangeValueForKey: @"mouseLocked"];
}

- (BOOL) mouseActive
{
	return YES;
}


//Responding to SDL's entreaties
//------------------------------

- (NSWindow *) SDLWindow	{ return (NSWindow *)[self window]; }
- (NSOpenGLView *) SDLView	{ return (NSOpenGLView *)[self renderView]; }

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

- (BOOL) handleSDLMouseMovement: (NSEvent *)event
{
	return NO;
	/*
	 BOOL mouseLocked = [[self emulator] mouseLocked];
	 BOOL mouseInView = [[self renderViewController] mouseInView];
	 NSRect viewRect = [renderView bounds];
	 
	 if (grab_state == QZ_INVISIBLE_GRAB )
	 {
	 CGMouseDelta dx, dy;
	 CGGetLastMouseDelta (&dx, &dy);
	 if (dx != 0 || dy != 0) SDL_PrivateMouseMotion(0, 1, dx, dy);
	 }
	 else
	 {
	 NSPoint p;
	 QZ_GetMouseLocation (this, &p);
	 SDL_PrivateMouseMotion (0, 0, p.x, p.y);
	 }
	 
	 if (!mouseInView)
	 {
	 if (SDL_GetAppState() & SDL_APPMOUSEFOCUS)
	 {
	 SDL_PrivateAppActive (0, SDL_APPMOUSEFOCUS);
	 
	 if (grab_state == QZ_INVISIBLE_GRAB) CGAssociateMouseAndMouseCursorPosition (1);
	 
	 QZ_UpdateCursor(this);
	 }
	 }
	 else
	 {
	 if ((SDL_GetAppState() & (SDL_APPMOUSEFOCUS | SDL_APPINPUTFOCUS)) == SDL_APPINPUTFOCUS)
	 {
	 SDL_PrivateAppActive (1, SDL_APPMOUSEFOCUS);
	 
	 QZ_UpdateCursor(this);
	 
	 if (grab_state == QZ_INVISIBLE_GRAB) {
	 //--Disabled 2010-03-16 by Alun Bestor: we no longer populate SDL_VideoSurface
	 //QZ_PrivateWarpCursor (this, SDL_VideoSurface->w / 2, SDL_VideoSurface->h / 2);
	 //--End of modifications
	 CGAssociateMouseAndMouseCursorPosition (0);
	 }
	 }
	 }
	 */
}

@end