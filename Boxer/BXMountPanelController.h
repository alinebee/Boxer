/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Cocoa/Cocoa.h>
#import "BXSession.h"

@class BXSession;

/// \c BXMountPanelController displays the mount-a-new-drive open panel and manages its accessory view.
/// It is responsible for synchronising the drive-settings fields with the current file selection, 
/// and for calling the relevant mount commands once a file is chosen.
@interface BXMountPanelController : NSViewController <NSOpenSavePanelDelegate>
{
	NSPopUpButton *_driveType;
	NSPopUpButton *_driveLetter;
	NSButton *_readOnlyToggle;
	
	NSCellStateValue _previousReadOnlyState;
	NSMenuItem *_previousDriveTypeSelection;
}
/// The drive type selector in the accessory view.
@property (strong) IBOutlet NSPopUpButton *driveType;
/// The drive letter selector in the accessory view.
@property (strong) IBOutlet NSPopUpButton *driveLetter;
/// The read-only checkbox toggle in the accessory view.
@property (strong) IBOutlet NSButton *readOnlyToggle;	

/// Returns a singleton instance, which loads the view from the NIB file the first time.
@property (class, readonly, strong) id controller;

/// Displays the mount panel in the main window for the specified session.
- (void) showMountPanelForSession: (BXSession *)theSession;

/// Used internally to populate the drive letter popup button with the specified session's current drives.
- (void) populateDrivesFromSession: (BXSession *)theSession;

/// Called by the drive-type popup button to update the drive letter popup button with options appropriate
/// to the current drive type.
- (IBAction) updateLettersForDriveType: (NSPopUpButton *)sender;

/// Used internally to synchronise the drive options to the currently selected file or folder.
- (void) syncMountOptionsForPanel: (NSOpenPanel *)openPanel;

/// Mounts the specified selected file or folder, chosen from the open panel.
/// Returns \c YES if successfully, or NO and populates outError if the drive could not be mounted.
- (BOOL) mountChosenURL: (NSURL *)URL error: (NSError **)outError;

@end
