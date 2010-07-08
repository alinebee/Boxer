/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXDrivesInUseAlert is shown when a user tries to unmount one or more drives that are currently
//being accessed by the DOS process. It displays a warning and confirmation.

#import <Cocoa/Cocoa.h>

@class BXSession;

@interface BXDrivesInUseAlert : NSAlert

//Initialise and return a new alert, whose text refers to the drives and session provided.
- (id) initWithDrives: (NSArray *)drivesInUse forSession: (BXSession *)theSession;

@end
