/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXDrivePanelController manages the Drives panel of the Inspector window.

#import <Cocoa/Cocoa.h>

@class BXDriveList;

@interface BXDrivePanelController : NSViewController
{
	IBOutlet NSArrayController *drives;
	IBOutlet NSSegmentedControl *driveOptionsControl;
	IBOutlet NSMenu *driveOptionsMenu;
	IBOutlet BXDriveList *driveList;
}
@property (retain) BXDriveList *driveList;
@property (retain) NSSegmentedControl *driveOptionsControl;
@property (retain) NSMenu *driveOptionsMenu;
//The array controller representing the current session's drives.
@property (retain) NSArrayController *drives;

- (IBAction) interactWithDriveOptions: (NSSegmentedControl *)sender;

//Reveal the selected drives each in a new Finder window.
- (IBAction) revealSelectedDrivesInFinder: (id)sender;

//Change to the first selected drive in DOS. This action is disabled if a process is running.
- (IBAction) openSelectedDrivesInDOS: (id)sender; 

//Unmount the selected drives from DOS.
- (IBAction) unmountSelectedDrives: (id)sender;

//Display the mount panel.
- (IBAction) showMountPanel: (id)sender;

//Sort descriptors for the drive list.
- (NSArray *) driveSortDescriptors;
- (NSPredicate *) driveFilterPredicate;

//Handle drag-dropping of files and folders to mount as drives.
- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>)sender;
- (BOOL) performDragOperation: (id <NSDraggingInfo>)sender;

@end
