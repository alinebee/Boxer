/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDrivePanelController.h"
#import "BXAppController.h"
#import "BXSession+BXFileManager.h"
#import "BXSession+BXDragDrop.h"
#import "BXEmulator+BXDOSFileSystem.h"
#import "BXEmulatorErrors.h"
#import "BXDrive.h"
#import "BXValueTransformers.h"
#import "BXDriveImport.h"
#import "BXDriveList.h"

#pragma mark -
#pragma mark Private constants

//The segment indexes of the drive options control
enum {
	BXAddDriveSegment			= 0,
	BXRemoveDrivesSegment		= 1,
	BXDriveActionsMenuSegment	= 2
};


#pragma mark -
#pragma mark Implementation


@implementation BXDrivePanelController
@synthesize driveControls, driveActionsMenu, driveList;
@synthesize selectedDriveIndexes;

#pragma mark -
#pragma mark Initialization and teardown

+ (void) initialize
{
	BXDisplayPathTransformer *fullDisplayPath = [[BXDisplayPathTransformer alloc] initWithJoiner: @" ▸ "
																				   maxComponents: 4];
	
	BXDisplayPathTransformer *displayName = [[BXDisplayNameTransformer alloc] init];
	
	[NSValueTransformer setValueTransformer: fullDisplayPath forName: @"BXDriveDisplayPath"];
	[NSValueTransformer setValueTransformer: displayName forName: @"BXDriveDisplayName"];
	
	[fullDisplayPath release];
	[displayName release];
}

- (void) awakeFromNib
{
    //Make our represented object be the drive-list of the current session.
    [self bind: @"representedObject" toObject: [NSApp delegate] withKeyPath: @"currentSession.allDrives" options: nil];
    
	//Register the entire drive panel as a drag-drop target.
	[[self view] registerForDraggedTypes: [NSArray arrayWithObject: NSFilenamesPboardType]];	
	
	//Assign the appropriate menu to the drive-actions button segment.
	[[self driveControls] setMenu: [self driveActionsMenu] forSegment: BXDriveActionsMenuSegment];
	
	//Listen for drive import notifications.
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center addObserver: self selector: @selector(operationWillStart:) name: BXOperationWillStart object: nil];
	[center addObserver: self selector: @selector(operationDidFinish:) name: BXOperationDidFinish object: nil];
	[center addObserver: self selector: @selector(operationInProgress:) name: BXOperationInProgress object: nil];
	[center addObserver: self selector: @selector(operationWasCancelled:) name: BXOperationWasCancelled object: nil];
}

- (void) dealloc
{
	//Clean up notifications and bindings
    [self unbind: @"currentSession.allDrives"];
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center removeObserver: self];
    
	[self setSelectedDriveIndexes: nil], [selectedDriveIndexes release];
    
	[self setDriveList: nil],			[driveList release];
	[self setDriveControls: nil],		[driveControls release];
	[self setDriveActionsMenu: nil],	[driveActionsMenu release];
	[super dealloc];
}

- (void) _syncButtonStates
{
	//Disable the appropriate drive controls when there are no selected items or no session.
    BOOL hasSession		= ([[NSApp delegate] currentSession] != nil);
    BOOL hasSelection	= ([[self selectedDriveIndexes] count] > 0);
    [[self driveControls] setEnabled: hasSession	forSegment: BXAddDriveSegment];
    [[self driveControls] setEnabled: hasSelection	forSegment: BXRemoveDrivesSegment];
    [[self driveControls] setEnabled: hasSelection	forSegment: BXDriveActionsMenuSegment];
}


+ (NSSet *) keyPathsForValuesAffectingDrives
{
    return [NSSet setWithObject: @"representedObject"];
}

- (NSArray *) drives
{
    return [[self representedObject] filteredArrayUsingPredicate: [self driveFilterPredicate]];
}

- (NSPredicate *) driveFilterPredicate
{
    return [NSPredicate predicateWithFormat: @"isHidden = NO && isInternal = NO"];
}

- (void) setSelectedDriveIndexes: (NSIndexSet *)indexes
{
    if ([indexes isNotEqualTo: [self selectedDriveIndexes]])
    {
        [selectedDriveIndexes release];
        selectedDriveIndexes = [indexes retain];
        
        //Sync the action buttons whenever our selection changes
        [self _syncButtonStates];
    }
}

- (NSArray *) selectedDrives
{
    if ([selectedDriveIndexes count])
    {
        NSArray *drives = [[[NSApp delegate] currentSession] allDrives];
        return [drives objectsAtIndexes: selectedDriveIndexes];
    }
    else return [NSArray array];
}


#pragma mark -
#pragma mark Interface actions

- (IBAction) interactWithDriveOptions: (NSSegmentedControl *)sender
{
	SEL action = [sender action];
	switch ([sender selectedSegment])
	{
		case BXAddDriveSegment:
			[self showMountPanel: sender];
			break;
			
		case BXRemoveDrivesSegment:
			[self unmountSelectedDrives: sender];
			break;
			
		case BXDriveActionsMenuSegment:
			//An infuriating workaround for an NSSegmentedControl bug,
			//whereby menus won't be shown if the control has an action set.
			[sender setAction: NULL];
			[sender mouseDown: [NSApp currentEvent]];
			[sender setAction: action];
			break;
	}
}

- (IBAction) revealSelectedDrivesInFinder: (id)sender
{
	NSArray *selection = [self selectedDrives];
	for (BXDrive *drive in selection) [NSApp sendAction: @selector(revealInFinder:) to: nil from: drive];
}

- (IBAction) openSelectedDrivesInDOS: (id)sender
{
	//Only bother grabbing the last drive selected
	BXDrive *drive = [[self selectedDrives] lastObject];
	if (drive) [NSApp sendAction: @selector(openInDOS:) to: nil from: drive];
}

- (IBAction) unmountSelectedDrives: (id)sender
{
	NSArray *selection = [self selectedDrives];
	BXSession *session = [[NSApp delegate] currentSession];
	if ([session shouldUnmountDrives: selection sender: self])
    {
        NSError *unmountError = nil;
		[session unmountDrives: selection
                       options: BXDefaultDriveUnmountOptions
                         error: &unmountError];
        if (unmountError)
        {
            NSWindow *targetWindow = [[[NSApp delegate] currentSession] windowForSheet];
            [targetWindow presentError: unmountError
                        modalForWindow: targetWindow
                              delegate: nil
                    didPresentSelector: NULL
                           contextInfo: NULL];
        }
    }
}

- (IBAction) importSelectedDrives: (id)sender
{
	NSArray *selection = [self selectedDrives];
	BXSession *session = [[NSApp delegate] currentSession];

	for (BXDrive *drive in selection) [session importOperationForDrive: drive startImmediately: YES];
}

- (IBAction) cancelImportForDrive: (id)sender
{
	BXDrive *drive = [[(BXDriveItemView *)[sender superview] delegate] representedObject];
	BXSession *session = [[NSApp delegate] currentSession];
	if (drive) [session cancelImportForDrive: drive];
}

- (IBAction) cancelImportsForSelectedDrives: (id)sender
{
	NSArray *selection = [self selectedDrives];
	BXSession *session = [[NSApp delegate] currentSession];
	
	for (BXDrive *drive in selection) [session cancelImportForDrive: drive];
}

- (IBAction) showMountPanel: (id)sender
{
	//Make sure the application is active; since we support clickthrough,
	//Boxer may be in the background when this action is sent.
	[NSApp activateIgnoringOtherApps: YES];
	
	//Pass mount panel action upstream - this works around the fiddly separation of responder chains
	//between the inspector panel and main DOS window.
	BXSession *session = [[NSApp delegate] currentSession];
	[NSApp sendAction: @selector(showMountPanel:) to: session from: self];
}

- (BOOL) validateMenuItem: (NSMenuItem *)theItem
{
	BXSession *session = [[NSApp delegate] currentSession];
	//If there's currently no active session, we can't do anything
	if (!session) return NO;
	
	NSArray *driveSelection = [self selectedDrives];
	BOOL hasSelection = ([driveSelection count] > 0);
	BOOL isGamebox = [session isGamePackage];
	BXEmulator *theEmulator = [session emulator];
	
	SEL action = [theItem action];
	
	if (action == @selector(revealSelectedDrivesInFinder:)) return hasSelection;
	if (action == @selector(unmountSelectedDrives:))
	{
		if (!hasSelection) return NO;
		
		//Check if any of the selected drives are locked or internal
		for (BXDrive *drive in driveSelection)
		{
			if ([drive isLocked] || [drive isInternal]) return NO;
		}
		return YES;
	}
	if (action == @selector(openSelectedDrivesInDOS:))
	{
		BOOL isCurrent = [[driveSelection lastObject] isEqual: [theEmulator currentDrive]];
		
		NSString *title;
		if (isCurrent)
		{
			title = NSLocalizedString(@"Current drive",
									  @"Menu item title for when selected drive is already the current DOS drive.");
		}
		else title = NSLocalizedString(@"Make current drive",
									   @"Menu item title for switching to the selected drive in DOS.");
		
		[theItem setTitle: title];
		
		//Deep breath now: only enable option if...
		//- only one drive is selected
		//- the drive isn't already the current drive
		//- the session is at the DOS prompt
		return !isCurrent && [driveSelection count] == 1 && [theEmulator isAtPrompt];
	}
	
	if (action == @selector(importSelectedDrives:))
	{
		//Initial label for drive import items (may be modified below)
		[theItem setTitle: NSLocalizedString(@"Import into gamebox", @"Drive import menu item title.")];
		
		//Hide this item altogether if we're not running a session
		[theItem setHidden: !isGamebox];
		if (!isGamebox || !hasSelection) return NO;
		 
		//Check if any of the selected drives are being imported, already imported, or otherwise cannot be imported
		for (BXDrive *drive in driveSelection)
		{
			if ([session driveIsImporting: drive])
			{
				[theItem setTitle: NSLocalizedString(@"Importing into gamebox…", @"Drive import menu item title, when selected drive(s) are already in the gamebox.")];
				return NO;
			}
			else if ([session driveIsBundled: drive] || [session equivalentDriveIsBundled: drive])
			{
				[theItem setTitle: NSLocalizedString(@"Included in gamebox", @"Drive import menu item title, when selected drive(s) are already in the gamebox.")];
				return NO;
			}
			else if (![session canImportDrive: drive]) return NO;
		}
		//If we get this far then yes, it's ok
		return YES;
	}
	
	if (action == @selector(cancelImportsForSelectedDrives:))
	{
		if (isGamebox) for (BXDrive *drive in driveSelection)
		{	
			//If any of the selected drives are being imported, then enable and unhide the item
			if ([session driveIsImporting: drive])
			{
				[theItem setHidden: NO];
				return YES;
			}
		}
		//Otherwise, hide the item
		[theItem setHidden: YES];
		return NO;
	}
	
	return YES;
}


#pragma mark -
#pragma mark Drive import progress handling

- (void) operationWillStart: (NSNotification *)notification
{
	BXOperation <BXDriveImport> *transfer = [notification object];
	
	//If the notification didn't come from the current session, ignore it
	if (![transfer conformsToProtocol: @protocol(BXDriveImport)] ||
		[transfer delegate] != [[NSApp delegate] currentSession]) return;
	
	BXDrive *drive = [transfer drive];
	BXDriveItemView *driveView = [[self driveList] viewForDrive: drive];
	if (driveView)
	{
		NSProgressIndicator *progressMeter	= [driveView progressMeter];
		NSTextField *progressMeterLabel		= [driveView progressMeterLabel];
		NSTextField *typeLabel				= [driveView driveTypeLabel];
		NSButton *progressMeterCancel		= [driveView progressMeterCancel];
		
		//Start off with an indeterminate progress meter before we know the size of the operation
		[progressMeter setIndeterminate: YES];
		[progressMeter setUsesThreadedAnimation: YES];
		[progressMeter startAnimation: self];
		
		//Initialise the progress value to a suitable point
		//(in case we're receiving this notification in the middle of a transfer)
		[progressMeter setDoubleValue: [transfer currentProgress]];
		
		//Enable the cancel button
		[progressMeterCancel setEnabled: YES];
		
		//Set label text appropriately
		[progressMeterLabel setStringValue: NSLocalizedString(@"Importing…", @"Initial drive import progress meter label, before transfer size is known.")];
		
		//Unhide the progress indicator and hide the type label it covers
		[typeLabel setHidden: YES];
		[progressMeter setHidden: NO];
		[progressMeterCancel setHidden: NO];
		[progressMeterLabel setHidden: NO];		
	}
}

- (void) operationInProgress: (NSNotification *)notification
{
	BXOperation <BXDriveImport> *transfer = [notification object];
	
	//If the notification didn't come from the current session, ignore it
	if (![transfer conformsToProtocol: @protocol(BXDriveImport)] ||
		[transfer delegate] != [[NSApp delegate] currentSession]) return;
		
	BXDrive *drive = [transfer drive];
	BXDriveItemView *driveView = [[self driveList] viewForDrive: drive];
	if (driveView)
	{
		NSProgressIndicator *progressMeter = [driveView progressMeter];
		NSTextField *progressMeterLabel = [driveView progressMeterLabel];
		
		if ([transfer isIndeterminate])
		{
			[progressMeter setIndeterminate: YES];
		}
		else
		{
			BXOperationProgress progress = [transfer currentProgress];
			
			//Massage the progress with an ease-out curve to make it appear quicker at the start of the transfer
			BXOperationProgress easedProgress = -progress * (progress - 2);
			
			[progressMeter setIndeterminate: NO];
			
			//If we know the progress, set the label text appropriately
			[progressMeter setDoubleValue: easedProgress];
			[progressMeter setNeedsDisplay: YES];
			NSString *progressFormat = NSLocalizedString(@"%1$i%% of %2$i MB",
														 @"Drive import progress meter label. %1 is the current progress as an unsigned integer percentage, %2 is the total size of the transfer as an unsigned integer in megabytes");
			
			NSUInteger progressPercent	= (NSUInteger)round(easedProgress * 100.0);
			NSUInteger sizeInMB			= (NSUInteger)ceil([transfer numBytes] / 1000.0 / 1000.0);
			[progressMeterLabel setStringValue: [NSString stringWithFormat: progressFormat, progressPercent, sizeInMB, nil]];			
		}
	}
}

- (void) operationWasCancelled: (NSNotification *)notification
{
	BXOperation <BXDriveImport> *transfer = [notification object];
	
	//If the notification didn't come from the current session, ignore it
	if (![transfer conformsToProtocol: @protocol(BXDriveImport)] ||
		[transfer delegate] != [[NSApp delegate] currentSession]) return;
	
	BXDrive *drive = [transfer drive];
	BXDriveItemView *driveView = [[self driveList] viewForDrive: drive];
	if (driveView)
	{
		NSProgressIndicator *progressMeter	= [driveView progressMeter];
		NSTextField *progressMeterLabel		= [driveView progressMeterLabel];
		NSButton *progressMeterCancel		= [driveView progressMeterCancel];
		
		//Switch the progress meter to indeterminate when operation is cancelled
		[progressMeter setIndeterminate: YES];
		[progressMeter startAnimation: self];
		
		//Disable the cancel button
		[progressMeterCancel setEnabled: NO];
		
		//Change label text appropriately
		[progressMeterLabel setStringValue: NSLocalizedString(@"Cancelling…", @"Drive import progress meter label when import operation is cancelled.")];
	}
}

- (void) operationDidFinish: (NSNotification *)notification
{
	BXOperation <BXDriveImport> *transfer = [notification object];
	
	//If the notification didn't come from the current session, ignore it
	if (![transfer conformsToProtocol: @protocol(BXDriveImport)] ||
		[transfer delegate] != [[NSApp delegate] currentSession]) return;
	
	BXDrive *drive = [transfer drive];
	BXDriveItemView *driveView = [[self driveList] viewForDrive: drive];
	if (driveView)
	{
		NSProgressIndicator *progressMeter	= [driveView progressMeter];
		NSTextField *progressMeterLabel		= [driveView progressMeterLabel];
		NSButton *progressMeterCancel		= [driveView progressMeterCancel];
		NSTextField *typeLabel				= [driveView driveTypeLabel];
		
		//Re-hide the various bits of the animation
		[progressMeter stopAnimation: self];
		[progressMeter setHidden: YES];
		[progressMeterLabel setHidden: YES];
		[progressMeterCancel setHidden: YES];
		[typeLabel setHidden: NO];
	}
}


#pragma mark -
#pragma mark Drag-drop

- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>)sender
{	
	//Ignore drags that originated from the drive list itself
	id source = [sender draggingSource];
	if ([[source window] isEqual: [[self view] window]]) return NSDragOperationNone;
	
	//Otherwise, ask the current session what it would like to do with the files
	NSPasteboard *pboard = [sender draggingPasteboard];
	if ([[pboard types] containsObject: NSFilenamesPboardType])
	{
		NSArray *filePaths = [pboard propertyListForType: NSFilenamesPboardType];
		BXSession *session = [[NSApp delegate] currentSession];
		return [session responseToDroppedFiles: filePaths];
	}
	else return NSDragOperationNone;
}

- (BOOL) performDragOperation: (id <NSDraggingInfo>)sender
{	
	NSPasteboard *pboard = [sender draggingPasteboard];
	if ([[pboard types] containsObject: NSFilenamesPboardType])
	{
		BXSession *session = [[NSApp delegate] currentSession];
		NSArray *filePaths = [pboard propertyListForType: NSFilenamesPboardType];
		
		return [session handleDroppedFiles: filePaths withLaunching: NO];
	}		
	return NO;
}


- (BOOL) collectionView: (NSCollectionView *)collectionView
    writeItemsAtIndexes: (NSIndexSet *)indexes
           toPasteboard: (NSPasteboard *)pasteboard
{
    //Get a list of all file paths of the selected drives
    NSArray *chosenDrives = [[self drives] objectsAtIndexes: indexes];
    NSArray *filePaths = [chosenDrives valueForKeyPath: @"path"];
    
    [pasteboard declareTypes: [NSArray arrayWithObject: NSFilenamesPboardType] owner: self];	
    [pasteboard setPropertyList: filePaths forType: NSFilenamesPboardType];
    
    return YES;
}

@end
