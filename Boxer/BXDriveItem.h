/*
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXCollectionItemView.h"

@class BXDrive;
//BXDriveItem represents each drive in the list and acts
//as a view controller for its corresponding BXDriveItemView.
@interface BXDriveItem : BXCollectionItem
{
    BOOL _importing;
    
    NSProgressIndicator *_progressMeter;
    NSTextField *_progressMeterLabel;
    NSButton *_progressMeterCancel;
    NSTextField *_driveTypeLabel;
    NSButton *_driveToggleButton;
    NSButton *_driveRevealButton;
    NSButton *_driveImportButton;
}

//Progress meter fields within the drive item view.
//These will be updated programmatically throughout the import progress.
@property (retain, nonatomic) IBOutlet NSProgressIndicator *progressMeter;
@property (retain, nonatomic) IBOutlet NSTextField *progressMeterLabel;
@property (retain, nonatomic) IBOutlet NSButton *progressMeterCancel;
@property (retain, nonatomic) IBOutlet NSTextField *driveTypeLabel;
@property (retain, nonatomic) IBOutlet NSButton *driveToggleButton;
@property (retain, nonatomic) IBOutlet NSButton *driveRevealButton;
@property (retain, nonatomic) IBOutlet NSButton *driveImportButton;

//The drive to which this item corresponds. Derived automatically from representedObject.
@property (readonly, nonatomic) BXDrive *drive;

//The icon to display for the drive we represent.
@property (readonly, nonatomic) NSImage *icon;

//The type description to display for our drive.
@property (readonly, nonatomic) NSString *typeDescription;

//The icon to display on the insert/eject toggle.
@property (readonly, nonatomic) NSImage *iconForToggle;

//Tooltips for buttons in the drive item list.
//(These have to be applied via bindings, because IB doesn't
//let you assign tooltips >:( )
@property (readonly, nonatomic) NSString *tooltipForToggle;
@property (readonly, nonatomic) NSString *tooltipForBundle;
@property (readonly, nonatomic) NSString *tooltipForReveal;
@property (readonly, nonatomic) NSString *tooltipForCancel;


//Whether this drive is currently mounted.
@property (readonly, nonatomic, getter=isMounted) BOOL mounted;

//Whether this drive is part of the current gamebox.
@property (readonly, nonatomic, getter=isBundled) BOOL bundled;

//Whether this drive is currently being imported into the gamebox.
//Used to toggle the visibility of import progress fields in the drive item view.
@property (assign, nonatomic, getter=isImporting) BOOL importing;


//Import notifications dispatched by BXDrivePanelController,
//to the drive item for the drive being imported.
- (void) driveImportWillStart: (NSNotification *)notification;
- (void) driveImportInProgress: (NSNotification *)notification;
- (void) driveImportWasCancelled: (NSNotification *)notification;
- (void) driveImportDidFinish: (NSNotification *)notification;

@end
