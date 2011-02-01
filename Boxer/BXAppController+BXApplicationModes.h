/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXApplicationModes category extends BXAppController with functions controlling how
//Boxer interacts with the rest of the OS X system UI.

#import "BXAppController.h"

@interface BXAppController (BXApplicationModes)

//Add necessary notification observers for monitoring Boxer's window state.
//Exposed here only so that BXAppController can call it during initialization.
- (void) _addApplicationModeObservers;

- (void) sessionDidUnlockMouse: (NSNotification *)notification;
- (void) sessionDidLockMouse: (NSNotification *)notification;

@end
