/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXAppController+BXApplicationModes.h"
#import "BXSession.h"
#import "BXInspectorController.h"
#import "BXDOSWindowController.h"
#import "BXInputController.h"

#import "SystemEvents.h"
#import <Carbon/Carbon.h> //For SetSystemUIMode()

#pragma mark -
#pragma mark Private method declarations
@interface BXAppController ()

//Whether the specified keyboard modifiers will cause conflicts with DOS games.
//Expects an array of NSNumber instances corresponding to SystemEventsEpmd constants.
//Used by _syncSpacesKeyboardShortcuts.
+ (BOOL) _keyModifiersWillConflict: (NSArray *)modifiers;

//Set the application UI to the appropriate mode for the current session's
//fullscreen and mouse-locked status.
- (void) _syncApplicationPresentationMode;

//Delicately suppress Spaces shortcuts that can interfere with keyboard control
//in Boxer.
- (void) _syncSpacesKeyboardShortcuts;
@end


@implementation BXAppController (BXApplicationModes)

+ (BOOL) _keyModifiersWillConflict: (NSArray *)modifiers
{
	//If there's more than one modifier key required, then it's fine.
	if ([modifiers count] != 1) return NO;
	
	SystemEventsEpmd modifier = [[modifiers lastObject] unsignedIntegerValue];
	
	//If the sole modifier is the Ctrl, Opt or Shift key, then it'll likely conflict.
	return (modifier == SystemEventsEpmdControl || modifier == SystemEventsEpmdOption || modifier == SystemEventsEpmdShift);
}

- (void) _addApplicationModeObservers
{
	//Listen out for UI notifications so that we can coordinate window behaviour
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	
	[center addObserver: self selector: @selector(windowDidBecomeKey:)
				   name: NSWindowDidBecomeKeyNotification
				 object: nil];
	
	[center addObserver: self selector: @selector(windowDidResignKey:)
				   name: NSWindowDidResignKeyNotification
				 object: nil];
	
	[center addObserver: self selector: @selector(_syncApplicationPresentationMode)
				   name: BXSessionWillEnterFullScreenNotification
				 object: nil];
	
	[center addObserver: self selector: @selector(_syncApplicationPresentationMode)
				   name: BXSessionDidExitFullScreenNotification
				 object: nil];
	
	[center addObserver: self selector: @selector(sessionDidLockMouse:)
				   name: BXSessionDidLockMouseNotification
				 object: nil];
	
	[center addObserver: self selector: @selector(sessionDidUnlockMouse:)
				   name: BXSessionDidUnlockMouseNotification
				 object: nil];
}

- (void) _syncApplicationPresentationMode
{
	BXDOSWindowController *currentController = [[self currentSession] DOSWindowController];
	
	if ([currentController isFullScreen])
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

- (void) _syncSpacesKeyboardShortcuts
{
	SystemEventsApplication *systemEvents = [SBApplication applicationWithBundleIdentifier: @"com.apple.systemevents"];
	SystemEventsSpacesShortcut *arrowKeyPrefs = systemEvents.exposePreferences.spacesPreferences.arrowKeyModifiers;
	
	//IMPLEMENTATION NOTE: in an ideal world we'd access the keyModifiers property of arrowKeyPrefs.
	//However, this has been defined in the System Events header as a single OSType constant, when in
	//fact the real property returns an array of constants. In order to set and get this array,
	//we need to use a direct reference to the property as seen below.
	SBObject *keyMods = [arrowKeyPrefs propertyWithCode: 'spky'];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSArray *oldModifiers = [defaults arrayForKey: @"overriddenSpacesArrowKeyModifiers"];

	BOOL sessionIsKey = [[[[NSApp keyWindow] windowController] document] isKindOfClass: [BXSession class]];
	
	//A Boxer session has the keyboard focus, but we haven't yet suppressed the Spaces shortcuts:
	//if we need to, apply the suppression now, and keep a record of the old values
	if (sessionIsKey && !oldModifiers)
	{
		[systemEvents setSendMode: kAEWaitReply];
		[systemEvents setTimeout: 0.05f];
		NSArray *currentModifiers = [(SBElementArray *)[keyMods get] valueForKey: @"enumCodeValue"];
		
		if ([[self class] _keyModifiersWillConflict: currentModifiers])
		{
			[systemEvents setSendMode: kAENoReply];
			
			//We can make the modifier 'safe' by combining it with the Command key
			NSArray *safeModifiers = [currentModifiers arrayByAddingObject: [NSNumber numberWithUnsignedInteger: SystemEventsEpmdCommand]];
			
			[keyMods setTo: safeModifiers];
			[defaults setObject: currentModifiers forKey: @"overriddenSpacesArrowKeyModifiers"];
			
			//IMPLEMENTATION NOTE: we commit the user defaults to disk immediately, in case
			//we crash while we still have keyboard focus. This way, when the user next starts
			//up Boxer, it will see that there's an overridden modifier and restore it below.
			[defaults synchronize];
		}
	}
	
	//A Boxer session has lost keyboard focus, but we're still suppressing Spaces shortcuts:
	//remove the suppression, and revert the shortcuts to what they were.
	else if (!sessionIsKey && oldModifiers)
	{
		[systemEvents setSendMode: kAENoReply];
		[keyMods setTo: oldModifiers];
		[defaults removeObjectForKey: @"overriddenSpacesArrowKeyModifiers"];
		[defaults synchronize];
	}
}

- (void) windowDidBecomeKey: (NSNotification *)notification
{
	//Fire this with a small delay to allow time for the window that triggered
	//the notification to actually appear as NSApp's keyWindow.
	[self performSelector: @selector(_syncSpacesKeyboardShortcuts) withObject: nil afterDelay: 0.01];
}

- (void) windowDidResignKey: (NSNotification *)notification
{
	[self _syncSpacesKeyboardShortcuts];
}

- (void) sessionDidUnlockMouse: (NSNotification *)notification
{
	[self _syncApplicationPresentationMode];
	
	//If we were previously concealing the Inspector, then reveal it now
	[[BXInspectorController controller] revealIfHidden];
}

- (void) sessionDidLockMouse: (NSNotification *)notification
{
	[self _syncApplicationPresentationMode];
	
	//Conceal the Inspector panel while the mouse is locked
	[[BXInspectorController controller] hideIfVisible];
}

@end
