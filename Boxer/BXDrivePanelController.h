/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXDrivePanelController manages the Drives panel of the Inspector window.

#import <Cocoa/Cocoa.h>
#import "BXOperationDelegate.h"

@class BXDriveList;

@interface BXDrivePanelController : NSViewController <BXOperationDelegate>
{
	IBOutlet NSArrayController *drives;
	IBOutlet NSSegmentedControl *driveControls;
	IBOutlet NSMenu *driveActionsMenu;
	IBOutlet BXDriveList *driveList;
	
	NSMutableArray *driveDetails;
}

#pragma mark -
#pragma mark Properties

@property (retain, nonatomic) BXDriveList *driveList;
@property (retain, nonatomic) NSSegmentedControl *driveControls;
@property (retain, nonatomic) NSMenu *driveActionsMenu;
//The array controller representing the current session's drives.
@property (retain, nonatomic) NSArrayController *drives;

//The current session's drives and drive import progress, grouped as an NSDictionary.
@property (readonly, nonatomic) NSArray *driveDetails;

//Sort descriptors and filters for our drive list.
@property (readonly, nonatomic) NSArray *driveSortDescriptors;
@property (readonly, nonatomic) NSPredicate *driveFilterPredicate;


#pragma mark -
#pragma mark Interface Actions

- (IBAction) interactWithDriveOptions: (NSSegmentedControl *)sender;

//Reveal the selected drives each in a new Finder window.
- (IBAction) revealSelectedDrivesInFinder: (id)sender;

//Change to the first selected drive in DOS. This action is disabled if a process is running.
- (IBAction) openSelectedDrivesInDOS: (id)sender; 

//Unmount the selected drives from DOS.
- (IBAction) unmountSelectedDrives: (id)sender;

//Import the selected drives into the gamebox.
- (IBAction) importSelectedDrives: (id)sender;

//Cancel the import operation for the drive represented by the sender.
- (IBAction) cancelImportForDrive: (id)sender;

//Cancel the import operations for all currently selected drives.
- (IBAction) cancelImportsForSelectedDrives: (id)sender;

//Display the mount panel.
- (IBAction) showMountPanel: (id)sender;


#pragma mark -
#pragma mark Drag-dropping

//Handle drag-dropping of files and folders to mount as drives.
- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>)sender;
- (BOOL) performDragOperation: (id <NSDraggingInfo>)sender;

@end
