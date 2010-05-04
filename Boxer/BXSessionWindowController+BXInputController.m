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

@implementation BXSessionWindowController (BXInputController)

//Delegate methods
//----------------

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

- (void) windowDidBecomeKey:	(NSNotification *) notification	{ [[self emulator] captureInput]; }
- (void) windowDidBecomeMain:	(NSNotification *) notification	{ [[self emulator] activate]; }
- (void) windowDidResignKey:	(NSNotification *) notification
{
	//Don't resign key when we're in fullscreen mode
	//FIXME: work out why this is happening in the first place!
	if ([self isFullScreen]) [[self window] makeKeyWindow];
	else
	{
		[[self emulator] releaseInput];
		[self setMouseLocked: NO];
	}
}
- (void) windowDidResignMain:	(NSNotification *) notification
{
	//Don't resign main when we're in fullscreen mode
	//FIXME: work out why this is happening in the first place!
	if ([self isFullScreen]) [[self window] makeMainWindow];
	else
	{
		[[self emulator] deactivate];
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


/* Mouse cursor handling */
/* --------------------- */

- (BOOL) mouseInView
{
	if ([renderView isInFullScreenMode]) return YES;
	
	NSPoint mouseLocation = [[self window] mouseLocationOutsideOfEventStream];
	NSPoint relativePoint = [renderView convertPoint: mouseLocation fromView: nil];
	return [renderView mouse: relativePoint inRect: [renderView bounds]];
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

- (void) cursorUpdate: (NSEvent *)theEvent
{
	if ([self mouseActive] && [self mouseInView])
	{
		[[self hiddenCursor] set];
	}
}

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
	
	[self didChangeValueForKey: @"mouseLocked"];
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