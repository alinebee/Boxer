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
#import "BXDOSViewController.h"
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
		[DOSViewController setMouseLocked: NO];
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
		[DOSViewController setMouseLocked: NO];
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
	[[self emulator] didResume];
}

//Pass windowed mouse events on to the DOS view controller so that it can sync the emulated
//cursor state wherever the mouse is
- (void) mouseMoved: (NSEvent *)theEvent
{
	[DOSViewController mouseMoved: theEvent];
}

@end