/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXCloseAlert defines close-this-window confirmation alert sheets for various contexts.

#import <Cocoa/Cocoa.h>
#import "BXAlert.h"

@class BXSession;

@interface BXCloseAlert : BXAlert

//Boxer's ready-made alerts
//-------------------------

//Shown when starting up a new session while another is already active. Advises the user
//that the current session will be clsoed if they continue.
//(Not currently used.)
+ (BXCloseAlert *) closeAlertWhenReplacingSession:	(BXSession *)theSession;

//Shown after exiting a DOS game and returning to the DOS prompt. Asks the user if they
//want to close the window or return to DOS.
//(Not currently used.)
+ (BXCloseAlert *) closeAlertAfterSessionExited:	(BXSession *)theSession;

//Shown when closing the window while a DOSBox process is running. Warns the user that
//any unsaved data will be lost if they continue.
+ (BXCloseAlert *) closeAlertWhileSessionIsActive:	(BXSession *)theSession;


//Dispatch and callback methods
//-----------------------------

//A simplification of beginSheetModalForWindow:contextInfo:, which passes the parent
//window as the context info.
- (void) beginSheetModalForWindow: (NSWindow *)window;

//A modification of the alertDidEnd:returnCode:contextInfo method signature to make
//context info explicitly a window. This is needed to allow the close alert to close
//its parent window.
+ (void) alertDidEnd: (BXCloseAlert *)alert returnCode: (int)returnCode contextInfo: (NSWindow *)window;

@end