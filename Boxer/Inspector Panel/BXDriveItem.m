/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXDriveItem.h"
#import "BXDrive.h"
#import "BXBaseAppController.h"
#import "BXSession+BXFileManagement.h"
#import "BXDriveImport.h"
#import "BXThemes.h"
#import "BXDrivePanelController.h"

@interface BXDriveItem ()

//Shows/hides the drive controls and progress indicators, based on the current
//state of the drive item.
- (void) _syncControlsShownWithAnimation: (BOOL)animate;
- (void) _syncProgressShownWithAnimation: (BOOL)animate;
- (void) _syncSelection;

@end

@implementation BXDriveItem
@synthesize importing = _importing;
@synthesize titleLabel = _titleLabel;
@synthesize typeLabel = _typeLabel;
@synthesize progressMeter = _progressMeter;
@synthesize progressMeterLabel = _progressMeterLabel;
@synthesize toggleButton = _toggleButton;
@synthesize revealButton = _revealButton;
@synthesize importButton = _importButton;
@synthesize cancelButton = _cancelButton;
@synthesize icon = _icon;
@synthesize letterLabel = _letterLabel;

- (void) viewDidLoad
{
    [self _syncControlsShownWithAnimation: NO];
    [self _syncProgressShownWithAnimation: NO];
    [self _syncSelection];
}

- (void) _syncControlsShownWithAnimation: (BOOL)animate
{
    BOOL showControls = (self.isSelected && !self.isImporting);
    BOOL showImportControl = showControls && [[(BXBaseAppController *)[NSApp delegate] currentSession] canImportDrive: self.representedObject];
    
    [NSAnimationContext beginGrouping];
        [NSAnimationContext currentContext].duration = animate ? 0.25 : 0.0;
        [self.toggleButton.animator setHidden: !showControls];
        [self.revealButton.animator setHidden: !showControls];
        [self.importButton.animator setHidden: !showImportControl];
    [NSAnimationContext endGrouping];
}

- (void) _syncProgressShownWithAnimation: (BOOL)animate
{
    BOOL showProgress = self.isImporting;
    
    [NSAnimationContext beginGrouping];
        [NSAnimationContext currentContext].duration = animate ? 0.25 : 0.0;
        [self.typeLabel.animator setHidden: showProgress];
        [self.progressMeter.animator setHidden: !showProgress];
        [self.progressMeterLabel.animator setHidden: !showProgress];
        [self.cancelButton.animator setHidden: !showProgress];
    [NSAnimationContext endGrouping];
}

- (void) _syncSelection
{
    if (!self.icon)
        return;
    
    NSArray *themedLabels = @[
        self.icon,
        self.titleLabel,
        self.letterLabel,
        self.typeLabel,
        self.progressMeterLabel,
    ];
    
    NSArray *themedControls = @[
        self.toggleButton.cell,
        self.revealButton.cell,
        self.importButton.cell,
        self.cancelButton.cell,
    ];
    
    NSString *labelThemeKey = self.isSelected ? @"BXInspectorListSelectionTheme" : @"BXInspectorListTheme";
    NSString *controlThemeKey = self.isSelected ? @"BXInspectorListControlSelectionTheme" : @"BXInspectorListControlTheme";
    
    for (id <BXThemable> label in themedLabels)
    {
        label.themeKey = labelThemeKey;
    }
    
    for (id <BXThemable> control in themedControls)
    {
        control.themeKey = controlThemeKey;
    }
}

- (void) setSelected: (BOOL)flag
{
    if (flag != self.isSelected)
    {
        [super setSelected: flag];
        [self _syncControlsShownWithAnimation: NO];
        [self _syncSelection];
    }
}

- (void) setImporting: (BOOL)flag
{
    if (flag != self.isImporting)
    {
        _importing = flag;
        
        [self _syncControlsShownWithAnimation: YES];
        [self _syncProgressShownWithAnimation: YES];
    }
}

- (void) dealloc
{
    self.progressMeter = nil;
    self.progressMeterLabel = nil;
    self.cancelButton = nil;
    self.typeLabel = nil;
    self.titleLabel = nil;
    self.letterLabel = nil;
    self.toggleButton = nil;
    self.revealButton = nil;
    self.importButton = nil;
    self.icon = nil;
    
    [super dealloc];
}


#pragma mark - UI bindings

- (BXDrive *) drive
{
    return (BXDrive *)self.representedObject;
}
+ (NSSet *) keyPathsForValuesAffectingDrive { return [NSSet setWithObject: @"representedObject"]; }

- (BOOL) isBundled
{
    return [[(BXBaseAppController *)[NSApp delegate] currentSession] driveIsBundled: self.drive];
}
+ (NSSet *) keyPathsForValuesAffectingBundled { return [NSSet setWithObject: @"importing"]; }

- (BOOL) isMounted
{
    return [[(BXBaseAppController *)[NSApp delegate] currentSession] driveIsMounted: self.drive];
}
+ (NSSet *) keyPathsForValuesAffectingMounted { return [NSSet setWithObject: @"drive.mounted"]; }

- (NSImage *) driveImage
{
    NSString *iconName;
    switch (self.drive.type)
    {
        case BXDriveCDROM:
            iconName = @"CDROMTemplate";
            break;
        case BXDriveFloppyDisk:
            iconName = @"DisketteTemplate";
            break;
        default:
            iconName = @"HardDiskTemplate";
    }
    
    return [NSImage imageNamed: iconName];
}
+ (NSSet *) keyPathsForValuesAffectingDriveImage { return [NSSet setWithObject: @"drive.type"]; }

- (NSImage *) iconForToggle
{
    NSString *imageName = self.isMounted ? @"EjectFreestandingTemplate": @"InsertFreestandingTemplate";
    return [NSImage imageNamed: imageName];
}
+ (NSSet *) keyPathsForValuesAffectingIconForToggle { return [NSSet setWithObject: @"mounted"]; }


- (NSString *) tooltipForToggle
{
    if (self.isMounted)
        return NSLocalizedString(@"Eject drive", @"Label/tooltip for ejecting mounted drives.");
    else
        return NSLocalizedString(@"Mount drive", @"Label/tooltip for mounting unmounted drives.");
}

+ (NSSet *) keyPathsForValuesAffectingTooltipForToggle  { return [NSSet setWithObject: @"mounted"]; }



- (NSString *) typeDescription
{
    NSString *description = self.drive.localizedTypeDescription;
    if (self.isBundled)
    {
        NSString *bundledDescriptionFormat = NSLocalizedString(@"gamebox %@", @"Description format for bundled drives. %@ is the original description of the drive (e.g. 'CD-ROM', 'hard disk' etc.)");
        description = [NSString stringWithFormat: bundledDescriptionFormat, description];
    }
    if (!self.isMounted)
    {
        NSString *inactiveDescriptionFormat = NSLocalizedString(@"%@ (ejected)", @"Description format for inactive drives. %@ is the original description of the drive (e.g. 'CD-ROM', 'hard disk' etc.)");
        description = [NSString stringWithFormat: inactiveDescriptionFormat, description];
    }
    return description;
}

+ (NSSet *) keyPathsForValuesAffectingTypeDescription
{
    return [NSSet setWithObjects: @"representedObject.typeDescription", @"mounted", @"bundled", nil];
}


#pragma mark - Actions

//These are passthroughs to the relevant methods on
//BXDrivePanelController. This is only necessary because
//cloned drive items don't seem to restore target-action
//connections correctly to the first responder; otherwise,
//we'd do it that way instead.

- (IBAction) revealInFinder: (id)sender     { self.selected = YES; [NSApp sendAction: @selector(revealSelectedDrivesInFinder:) to: self.collectionView.delegate from: sender]; }
- (IBAction) toggle: (id)sender             { self.selected = YES; [NSApp sendAction: @selector(toggleSelectedDrives:) to: self.collectionView.delegate from: sender]; }
- (IBAction) import: (id)sender             { self.selected = YES; [NSApp sendAction: @selector(importSelectedDrives:) to: self.collectionView.delegate from: sender]; }
- (IBAction) cancelImport: (id)sender       { self.selected = YES; [NSApp sendAction: @selector(cancelImportsForSelectedDrives:) to: self.collectionView.delegate from: sender]; }


#pragma mark - Drive import notifications

- (void) driveImportWillStart: (NSNotification *)notification
{
    ADBOperation <BXDriveImport> *transfer = notification.object;
    
    //Start off with an indeterminate progress meter before we know the size of the operation
    self.progressMeter.indeterminate = YES;
    [self.progressMeter startAnimation: self];
    
    //Initialise the progress value to a suitable point
    //(in case we're receiving this notification in the middle of a transfer)
    self.progressMeter.doubleValue = transfer.currentProgress;
    
    //Enable the cancel button
    self.cancelButton.enabled = YES;
    
    //Set label text appropriately
    self.progressMeterLabel.stringValue = NSLocalizedString(@"Importing…", @"Initial drive import progress meter label, before transfer size is known.");
    
    self.importing = YES;
}

- (void) driveImportInProgress: (NSNotification *)notification
{
    ADBOperation <BXDriveImport> *transfer = notification.object;
    
    if (transfer.isIndeterminate)
    {
        self.progressMeter.indeterminate = YES;
    }
    else
    {
        ADBOperationProgress progress = transfer.currentProgress;
        
        //Massage the progress with a gentle ease-out curve to make it appear quicker at the start of the transfer
        ADBOperationProgress easedProgress = -progress * (progress - 2);
        
        self.progressMeter.indeterminate = NO;
        self.progressMeter.doubleValue = easedProgress;
        
        //Now that we know the progress, set the label text appropriately
        NSString *progressFormat = NSLocalizedString(@"%1$i%% of %2$i MB",
                                                     @"Drive import progress meter label. %1 is the current progress as an unsigned integer percentage, %2 is the total size of the transfer as an unsigned integer in megabytes");
        
        NSUInteger progressPercent	= (NSUInteger)round(easedProgress * 100.0);
        NSUInteger sizeInMB			= (NSUInteger)ceil(transfer.numBytes / 1000.0 / 1000.0);
        self.progressMeterLabel.stringValue = [NSString stringWithFormat: progressFormat, progressPercent, sizeInMB];
    }
}

- (void) driveImportWasCancelled: (NSNotification *)notification
{
    //Switch the progress meter to indeterminate when operation is cancelled
    self.progressMeter.indeterminate = YES;
    [self.progressMeter startAnimation: self];
    
    //Disable the cancel button
    self.cancelButton.enabled = NO;
    
    //Change label text appropriately
    self.progressMeterLabel.stringValue = NSLocalizedString(@"Cancelling…",
                                                            @"Drive import progress meter label when import operation is cancelled.");
}

- (void) driveImportDidFinish: (NSNotification *)notification
{
    [self.progressMeter stopAnimation: self];
    self.importing = NO;
}

@end