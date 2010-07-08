/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXMountPanelController displays the mount-a-new-drive open panel and manages its accessory view.
//It is responsible for synchronising the drive-settings fields with the current file selection, 
//and for calling the relevant mount commands once a file is chosen.

#import <Cocoa/Cocoa.h>
#import "BXSession.h"

@class BXSession;

@interface BXMountPanelController : NSViewController
{
	IBOutlet NSPopUpButton *driveType;
	IBOutlet NSPopUpButton *driveLetter;
	IBOutlet NSButton *readOnlyToggle;
	
	NSCellStateValue previousReadOnlyState;
	NSMenuItem *previousDriveTypeSelection;
}
@property (retain) NSPopUpButton *driveType;	//The drive type selector in the accessory view.
@property (retain) NSPopUpButton *driveLetter;	//The drive letter selector in the accessory view.
@property (retain) NSButton *readOnlyToggle;	//The read-only checkbox toggle in the accessory view.

//Returns a singleton instance, which loads the view from the NIB file the first time.
+ (BXMountPanelController *) controller;

//Displays the mount panel in the main window for the specified session.
- (void) showMountPanelForSession: (BXSession *)theSession;

//Used internally to populate the drive letter popup button with the specified session's current drives.
- (void) populateDrivesFromSession: (BXSession *)theSession;

//Called by the drive-type popup button to update the drive letter popup button with options appropriate
//to the current drive type.
- (IBAction) updateLettersForDriveType: (NSPopUpButton *)sender;

//Used internally to synchronise the drive options to the currently selected file or folder.
- (void) syncMountOptionsForPanel: (NSOpenPanel *)openPanel;

//Mounts the currently selected file or folder in the specified open panel.
- (void) mountChosenItem: (NSOpenPanel *)openPanel returnCode: (int)returnCode contextInfo: (void *)contextInfo;

@end
