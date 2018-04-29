/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXCollectionItemView.h"

@class BXDrive;
/// BXDriveItem represents each drive in the list and acts
/// as a view controller for its corresponding BXDriveItemView.
@interface BXDriveItem : BXCollectionItem

#pragma mark - Outlet properties
@property (strong, nonatomic) IBOutlet NSProgressIndicator *progressMeter;
@property (strong, nonatomic) IBOutlet NSTextField *progressMeterLabel;
@property (strong, nonatomic) IBOutlet NSImageView *icon;
@property (strong, nonatomic) IBOutlet NSTextField *letterLabel;
@property (strong, nonatomic) IBOutlet NSTextField *titleLabel;
@property (strong, nonatomic) IBOutlet NSTextField *typeLabel;
@property (strong, nonatomic) IBOutlet NSButton *toggleButton;
@property (strong, nonatomic) IBOutlet NSButton *revealButton;
@property (strong, nonatomic) IBOutlet NSButton *importButton;
@property (strong, nonatomic) IBOutlet NSButton *cancelButton;

#pragma mark - Description properties

/// The drive to which this item corresponds. Derived automatically from representedObject.
@property (strong, readonly, nonatomic) BXDrive *drive;

/// The icon to display for the drive we represent.
@property (strong, readonly, nonatomic) NSImage *driveImage;

/// The type description to display for our drive.
@property (copy, readonly, nonatomic) NSString *typeDescription;

/// The icon and tooltip to display on the insert/eject toggle.
@property (strong, readonly, nonatomic) NSImage *iconForToggle;
@property (copy, readonly, nonatomic) NSString *tooltipForToggle;

#pragma mark - Status properties

/// Whether this drive is currently mounted.
@property (readonly, nonatomic, getter=isMounted) BOOL mounted;

/// Whether this drive is part of the current gamebox.
@property (readonly, nonatomic, getter=isBundled) BOOL bundled;

/// Whether this drive is currently being imported into the gamebox.
/// Used to toggle the visibility of import progress fields in the drive item view.
@property (assign, nonatomic, getter=isImporting) BOOL importing;


#pragma mark - Actions

- (IBAction) revealInFinder: (id)sender;
- (IBAction) toggle: (id)sender;
- (IBAction) import: (id)sender;
- (IBAction) cancelImport: (id)sender;


#pragma mark - Notifications

/// Import notifications dispatched by BXDrivePanelController,
/// to the drive item for the drive being imported.
- (void) driveImportWillStart: (NSNotification *)notification;
- (void) driveImportInProgress: (NSNotification *)notification;
- (void) driveImportWasCancelled: (NSNotification *)notification;
- (void) driveImportDidFinish: (NSNotification *)notification;

@end
