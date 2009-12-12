/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXDriveController manages the (now defunct) Drives menu. It populates the menu with links
//for each currently-mounted drive.
//This class is partially implemented, currently unused and may be removed altogether.

#import <Cocoa/Cocoa.h>

@class BXDrive;

@interface BXDriveMenuController : NSObject
{
	IBOutlet NSMenuItem *startPoint;
	IBOutlet NSMenuItem *endPoint;
}
//The NSMenuItem separators marking the start and end points inside which to populate the menu
//with drive items. If no drives are available, endPoint will be hidden.
@property (retain) NSMenuItem *startPoint;
@property (retain) NSMenuItem *endPoint;

//Returns a nonretained menu item ready for insertion into the menu. Called internally when the
//menu is displayed to populate it.
- (NSMenuItem *) itemForDrive: (BXDrive *)drive;

@end
