/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXApplicationModes category extends BXAppController with functions controlling how
//Boxer interacts with the rest of the OS X system UI.

#import "BXAppController.h"

@interface BXAppController (BXApplicationModes)

#pragma mark -
#pragma mark Class helpers

//Returns a non-conflicting set of keyboard modifiers based on the specified keyboard modifiers.
//Expects an array of NSNumber instances corresponding to SystemEventsEpmd constants.
//Used by syncSpacesKeyboardShortcuts.
+ (NSArray *) safeKeyModifiersFromModifiers: (NSArray *)modifiers;


#pragma mark -
#pragma mark Synchronizing application state

//Set the application UI to the appropriate mode for the current session's
//fullscreen and mouse-locked status.
- (void) syncApplicationPresentationMode;

//Delicately suppress Spaces shortcuts that can interfere with keyboard control
//in Boxer.
- (void) syncSpacesKeyboardShortcuts;


#pragma mark -
#pragma mark Notification observers

//Add necessary notification observers for monitoring Boxer's window state.
//Exposed here so that BXAppController can call it during initialization.
- (void) addApplicationModeObservers;

- (void) sessionDidUnlockMouse: (NSNotification *)notification;
- (void) sessionDidLockMouse: (NSNotification *)notification;

@end
