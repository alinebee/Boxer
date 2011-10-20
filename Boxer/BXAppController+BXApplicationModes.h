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
#pragma mark Synchronizing application state

//Set the application UI to the appropriate mode for the current session's
//fullscreen and mouse-locked status.
- (void) syncApplicationPresentationMode;


#pragma mark -
#pragma mark Notification observers

//Add necessary notification observers for monitoring Boxer's window state.
//Exposed here so that BXAppController can call it during initialization.
- (void) addApplicationModeObservers;

- (void) sessionDidUnlockMouse: (NSNotification *)notification;
- (void) sessionDidLockMouse: (NSNotification *)notification;

- (void) sessionWillEnterFullScreenMode: (NSNotification *)notification;
- (void) sessionDidEnterFullScreenMode: (NSNotification *)notification;
- (void) sessionWillExitFullScreenMode: (NSNotification *)notification;
- (void) sessionDidExitFullScreenMode: (NSNotification *)notification;

@end
