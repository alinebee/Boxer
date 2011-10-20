/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXAppController+BXApplicationModes.h"
#import "BXInspectorController.h"
#import "BXDOSWindowController.h"
#import "BXDOSWindow.h"
#import "BXInputController.h"
#import "BXSession.h"
#import "BXBezelController.h"

#import <Carbon/Carbon.h> //For SetSystemUIMode()



@implementation BXAppController (BXApplicationModes)

- (void) addApplicationModeObservers
{
	//Listen out for UI notifications so that we can coordinate window behaviour
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	
	[center addObserver: self selector: @selector(sessionWillEnterFullScreenMode:)
				   name: BXSessionWillEnterFullScreenNotification
				 object: nil];
    
	[center addObserver: self selector: @selector(sessionDidEnterFullScreenMode:)
				   name: BXSessionDidEnterFullScreenNotification
				 object: nil];
	
	[center addObserver: self selector: @selector(sessionWillExitFullScreenMode:)
				   name: BXSessionWillExitFullScreenNotification
				 object: nil];
    
	[center addObserver: self selector: @selector(sessionDidExitFullScreenMode:)
				   name: BXSessionDidExitFullScreenNotification
				 object: nil];
	
	[center addObserver: self selector: @selector(sessionDidLockMouse:)
				   name: BXSessionDidLockMouseNotification
				 object: nil];
	
	[center addObserver: self selector: @selector(sessionDidUnlockMouse:)
				   name: BXSessionDidUnlockMouseNotification
				 object: nil];
}

- (void) syncApplicationPresentationMode
{
    //Lion does the right thing with fullscreen modes anyway,
    //and the UI modes below seem to have changed in Lion such
    //that they don't Do The Right Thing.
    if ([[self class] isRunningOnLionOrAbove])
    {
        return;
    }
    
	BXDOSWindowController *currentController = [[self currentSession] DOSWindowController];
	
	if ([[currentController window] isFullScreen])
	{
		if ([[currentController inputController] mouseLocked])
		{
			//When the session is fullscreen and mouse-locked, hide all UI components
			SetSystemUIMode(kUIModeAllHidden, 0);
		}
		else
		{
			//When the session is fullscreen but the mouse is unlocked,
			//show the OS X menu but hide the Dock until it is moused over
			SetSystemUIMode(kUIModeContentSuppressed, 0);
		}
	}
	else
	{
		//When there is no fullscreen session, show all UI components normally.
		SetSystemUIMode(kUIModeNormal, 0);
	}
}

- (void) sessionDidUnlockMouse: (NSNotification *)notification
{
	[self syncApplicationPresentationMode];
	
	//If we were previously concealing the Inspector, then reveal it now
	[[BXInspectorController controller] revealIfHidden];
}

- (void) sessionDidLockMouse: (NSNotification *)notification
{
	[self syncApplicationPresentationMode];
	
	//Conceal the Inspector panel while the mouse is locked
	[[BXInspectorController controller] hideIfVisible];
}
- (void) sessionWillEnterFullScreenMode: (NSNotification *)notification
{
	[self syncApplicationPresentationMode];
}

- (void) sessionDidEnterFullScreenMode: (NSNotification *)notification
{
    [[BXBezelController controller] showFullscreenBezel];
}

- (void) sessionWillExitFullScreenMode: (NSNotification *)notification
{
    //Hide the fullscreen notification if it's still visible
    BXBezelController *bezel = [BXBezelController controller];
    if ([bezel currentBezel] == [bezel fullscreenBezel])
        [[bezel window] orderOut: self];
}

- (void) sessionDidExitFullScreenMode: (NSNotification *)notification
{
	[self syncApplicationPresentationMode];
}

@end
