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
    NSTextField *_titleLabel;
    NSTextField *_typeLabel;
    NSButton *_toggleButton;
    NSButton *_revealButton;
    NSButton *_importButton;
    NSImageView *_icon;
    NSTextField *_letterLabel;
    NSButton *_cancelButton;
}

#pragma mark - Outlet properties
@property (retain, nonatomic) IBOutlet NSProgressIndicator *progressMeter;
@property (retain, nonatomic) IBOutlet NSTextField *progressMeterLabel;
@property (retain, nonatomic) IBOutlet NSImageView *icon;
@property (retain, nonatomic) IBOutlet NSTextField *letterLabel;
@property (retain, nonatomic) IBOutlet NSTextField *titleLabel;
@property (retain, nonatomic) IBOutlet NSTextField *typeLabel;
@property (retain, nonatomic) IBOutlet NSButton *toggleButton;
@property (retain, nonatomic) IBOutlet NSButton *revealButton;
@property (retain, nonatomic) IBOutlet NSButton *importButton;
@property (retain, nonatomic) IBOutlet NSButton *cancelButton;

#pragma mark - Description properties

//The drive to which this item corresponds. Derived automatically from representedObject.
@property (readonly, nonatomic) BXDrive *drive;

//The icon to display for the drive we represent.
@property (readonly, nonatomic) NSImage *driveImage;

//The type description to display for our drive.
@property (readonly, nonatomic) NSString *typeDescription;

//The icon and tooltip to display on the insert/eject toggle.
@property (readonly, nonatomic) NSImage *iconForToggle;
@property (readonly, nonatomic) NSString *tooltipForToggle;

#pragma mark - Status properties

//Whether this drive is currently mounted.
@property (readonly, nonatomic, getter=isMounted) BOOL mounted;

//Whether this drive is part of the current gamebox.
@property (readonly, nonatomic, getter=isBundled) BOOL bundled;

//Whether this drive is currently being imported into the gamebox.
//Used to toggle the visibility of import progress fields in the drive item view.
@property (assign, nonatomic, getter=isImporting) BOOL importing;


#pragma mark - Notifications

//Import notifications dispatched by BXDrivePanelController,
//to the drive item for the drive being imported.
- (void) driveImportWillStart: (NSNotification *)notification;
- (void) driveImportInProgress: (NSNotification *)notification;
- (void) driveImportWasCancelled: (NSNotification *)notification;
- (void) driveImportDidFinish: (NSNotification *)notification;

@end
