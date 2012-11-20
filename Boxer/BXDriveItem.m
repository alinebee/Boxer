/*
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXDriveItem.h"
#import "BXDrive.h"
#import "BXBaseAppController.h"
#import "BXSession+BXFileManager.h"
#import "BXDriveImport.h"

@interface BXDriveItem ()

//Shows/hides the drive controls and progress indicators, based on the current
//state of the drive item.
- (void) _syncControlsShownWithAnimation: (BOOL)animate;
- (void) _syncProgressShownWithAnimation: (BOOL)animate;
@end

@implementation BXDriveItem
@synthesize importing = _importing;
@synthesize progressMeter = _progressMeter;
@synthesize progressMeterLabel = _progressMeterLabel;
@synthesize progressMeterCancel = _progressMeterCancel;
@synthesize driveTypeLabel = _driveTypeLabel;
@synthesize driveToggleButton = _driveToggleButton;
@synthesize driveRevealButton = _driveRevealButton;
@synthesize driveImportButton = _driveImportButton;

- (void) viewDidLoad
{
    [self _syncControlsShownWithAnimation: NO];
    [self _syncProgressShownWithAnimation: NO];
}

- (void) _syncControlsShownWithAnimation: (BOOL)animate
{
    BOOL showControls = (self.isSelected && !self.isImporting);
    BOOL showImportControl = showControls && [[[NSApp delegate] currentSession] canImportDrive: self.representedObject];
    
    [NSAnimationContext beginGrouping];
    [NSAnimationContext currentContext].duration = animate ? 0.25 : 0.0;
    [self.driveToggleButton.animator setHidden: !showControls];
    [self.driveRevealButton.animator setHidden: !showControls];
    [self.driveImportButton.animator setHidden: !showImportControl];
    [NSAnimationContext endGrouping];
}

- (void) _syncProgressShownWithAnimation: (BOOL)animate
{
    BOOL showProgress = self.isImporting;
    
    [NSAnimationContext beginGrouping];
    [NSAnimationContext currentContext].duration = animate ? 0.25 : 0.0;
    [self.driveTypeLabel.animator setHidden: showProgress];
    [self.progressMeter.animator setHidden: !showProgress];
    [self.progressMeterLabel.animator setHidden: !showProgress];
    [self.progressMeterCancel.animator setHidden: !showProgress];
    [NSAnimationContext endGrouping];
}

- (void) setSelected: (BOOL)flag
{
    [super setSelected: flag];
    [self _syncControlsShownWithAnimation: NO];
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
    self.progressMeterCancel = nil;
    self.driveTypeLabel = nil;
    self.driveToggleButton = nil;
    self.driveRevealButton = nil;
    self.driveImportButton = nil;
    
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
    return [[[NSApp delegate] currentSession] driveIsBundled: self.drive];
}
+ (NSSet *) keyPathsForValuesAffectingBundled { return [NSSet setWithObject: @"importing"]; }

- (BOOL) isMounted
{
    return [[[NSApp delegate] currentSession] driveIsMounted: self.drive];
}
+ (NSSet *) keyPathsForValuesAffectingMounted { return [NSSet setWithObject: @"drive.mounted"]; }

- (NSImage *) icon
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
+ (NSSet *) keyPathsForValuesAffectingIcon { return [NSSet setWithObject: @"drive.type"]; }

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


- (NSString *) tooltipForReveal
{
    return NSLocalizedString(@"Show in Finder", @"Label/tooltip for opening drives in a Finder window.");
}


- (NSString *) tooltipForCancel
{
    return NSLocalizedString(@"Cancel Import", @"Label/tooltip for cancelling in-progress drive import.");
}


- (NSString *) tooltipForBundle
{
    return NSLocalizedString(@"Import into Gamebox", @"Menu item title/tooltip for importing drive into gamebox.");
}


- (NSString *) typeDescription
{
    NSString *description = self.drive.typeDescription;
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


#pragma mark - Drive import notifications

- (void) driveImportWillStart: (NSNotification *)notification
{
    BXOperation <BXDriveImport> *transfer = notification.object;
    
    //Start off with an indeterminate progress meter before we know the size of the operation
    self.progressMeter.indeterminate = YES;
    [self.progressMeter startAnimation: self];
    
    //Initialise the progress value to a suitable point
    //(in case we're receiving this notification in the middle of a transfer)
    self.progressMeter.doubleValue = transfer.currentProgress;
    
    //Enable the cancel button
    self.progressMeterCancel.enabled = YES;
    
    //Set label text appropriately
    self.progressMeterLabel.stringValue = NSLocalizedString(@"Importing…", @"Initial drive import progress meter label, before transfer size is known.");
    
    self.importing = YES;
}

- (void) driveImportInProgress: (NSNotification *)notification
{
    BXOperation <BXDriveImport> *transfer = notification.object;
    
    if (transfer.isIndeterminate)
    {
        self.progressMeter.indeterminate = YES;
    }
    else
    {
        BXOperationProgress progress = transfer.currentProgress;
        
        //Massage the progress with a gentle ease-out curve to make it appear quicker at the start of the transfer
        BXOperationProgress easedProgress = -progress * (progress - 2);
        
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
    self.progressMeterCancel.enabled = NO;
    
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