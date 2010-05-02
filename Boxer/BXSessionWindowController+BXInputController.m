/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXSessionWindowController+BXInputController.h"
#import "BXSessionWindowController+BXRenderController.h"
#import "BXEmulator.h"

@implementation BXSessionWindowController (BXInputController)

//Mouse locking
//-------------

- (void) setMouseLocked: (BOOL) lock
{
	//Don't alter the mouselock state while the window is in fullscreen mode
	if ([self isFullScreen]) return;
	
	[[self emulator] setMouseLocked: lock];
}

- (BOOL) mouseLocked { return [[self emulator] mouseLocked]; }


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
	 BOOL mouseInView = [renderView containsMouse];
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