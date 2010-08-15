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
@class BXImport;

@interface BXCloseAlert : BXAlert

//Shown after exiting a DOS game and returning to the DOS prompt. Asks the user if they
//want to close the window or return to DOS.
//(Not currently used.)
+ (BXCloseAlert *) closeAlertAfterSessionExited:	(BXSession *)theSession;

//Shown when closing the window while a DOSBox process is running. Warns the user that
//any unsaved data will be lost if they continue.
+ (BXCloseAlert *) closeAlertWhileSessionIsEmulating:	(BXSession *)theSession;

//Shown when closing the window while one or more drive import operations are in progress.
+ (BXCloseAlert *) closeAlertWhileImportingDrives: (BXSession *)theSession;

//Shown when closing the window while a game import is in progress
+ (BXCloseAlert *) closeAlertWhileImportingGame: (BXImport *)theSession;

@end
