/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXGrowlController is Boxer's delegate to the Growl framework, and defines methods for
//registering and producing Boxer's various Growl notifications.

#import <Cocoa/Cocoa.h>
#import <Growl/GrowlApplicationBridge.h>

@class BXDrive;
@class BXPackage;

@interface BXGrowlController : NSObject <GrowlApplicationBridgeDelegate>

//Returns the shared singleton growl controller for Boxer classes to use.
+ (BXGrowlController *)controller;

//Called by Growl: returns the official application name under which Growl
//should file our notifications.
- (NSString *) applicationNameForGrowl;

//Called by Growl: Registers each of Boxer's notifications.
- (NSDictionary *) registrationDictionaryForGrowl;

//Display the inspector panel when drive-related notifications are clicked.
- (void) growlNotificationWasClicked: (id)clickContext;

//Notify that a new Boxer drive has been added to DOS.
- (void) notifyDriveMounted: (BXDrive *)drive;

//Notify that a DOS drive was removed.
- (void) notifyDriveUnmounted: (BXDrive *)drive;

//Notify that a DOS drive was imported into the specified gamebox.
- (void) notifyDriveImported: (BXDrive *)drive toPackage: (BXPackage *)package;
@end
