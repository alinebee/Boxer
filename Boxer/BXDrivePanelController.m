/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDrivePanelController.h"
#import "BXAppController.h"
#import "BXSession+BXFileManager.h"
#import "BXSession+BXDragDrop.h"
#import "BXEmulator.h"
#import "BXDrive.h"
#import "BXValueTransformers.h"
#import "BXFileTransfer.h"
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
@synthesize driveControls, driveActionsMenu, drives, driveList, driveDetails;

#pragma mark -
#pragma mark Initialization and teardown

+ (void) initialize
{
	BXDisplayPathTransformer *displayPath = [[BXDisplayPathTransformer alloc] initWithJoiner: @" ▸ "
																			   maxComponents: 4];
	[NSValueTransformer setValueTransformer: displayPath forName: @"BXDriveDisplayPath"];
	[displayPath release];
}

- (void) awakeFromNib
{
	//Register the entire drive panel as a drag-drop target.
	[[self view] registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, NSStringPboardType, nil]];	
	
	//Assign the appropriate menu to the drive menu segment.
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
	//Clean up notifications
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center removeObserver: self];
	
	[self setDriveList: nil],			[driveList release];
	[self setDrives: nil],				[drives release];
	[self setDriveControls: nil],		[driveControls release];
	[self setDriveActionsMenu: nil],	[driveActionsMenu release];
	[super dealloc];
}

//To explain why we have the observers set up below the way we do:
//NSArrayController has a bug in 10.5 and 10.6 whereby it won't post correctly provide the new or old values
//in change notifications about its content. So, we have to observe the content of our NSCollectionView instead,
//which has the same data but sends proper notifications about it.
//Meanwhile, NSCollectionView has a bug in 10.5 whereby it won't post notifications on its selectionIndexes if
//the selection is changed by calling setSelected: on a collectionViewItem. So, we have to observe the selection
//indexes of our NSArrayController instead, which likewise has the same data but sends proper notifications about it.
//What a fucking shambles.
- (void) setDriveList: (BXDriveList *)theList
{
	if (theList != driveList)
	{
		[driveList removeObserver: self forKeyPath: @"content"];
		
		[driveList release];
		driveList = [theList retain];
		
		[driveList addObserver: self
					forKeyPath: @"content"
					   options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
					   context: nil];
	}
}

- (void) setDrives: (NSArrayController *)newDrives
{
	if (drives != newDrives)
	{
		[drives removeObserver: self forKeyPath: @"selectionIndexes"];
		
		[drives release];
		drives = [newDrives retain];
		
		[drives addObserver: self
				 forKeyPath: @"selectionIndexes"
					options: NSKeyValueObservingOptionInitial
					context: nil];
	}
}

- (void) observeValueForKeyPath: (NSString *)keyPath
					   ofObject: (id)object
						 change: (NSDictionary *)change
						context: (void *)context
{
	//Disable the appropriate drive controls when there are no selected items.
	if ([keyPath isEqualToString: @"selectionIndexes"])
	{
		BOOL hasSession		= ([[NSApp delegate] currentSession] != nil);
		BOOL hasSelection	= ([[object selectionIndexes] count] > 0);
		[[self driveControls] setEnabled: hasSession	forSegment: BXAddDriveSegment];
		[[self driveControls] setEnabled: hasSelection	forSegment: BXRemoveDrivesSegment];
		[[self driveControls] setEnabled: hasSelection	forSegment: BXDriveActionsMenuSegment];
	}
	
	//Select newly-added drives.
	//IMPLEMENTATION NOTE: in an ideal world we'd be able to handle this by listening for
	//NSKeyValueChangeInsertion notifications.
	//However, those are not sent correctly by NSArrayController nor by NSCollectionView,
	//so we have to do the work by hand: comparing old and new arrays to find out what was added.
	else if ([keyPath isEqualToString: @"content"])
	{
		NSArray *oldDrives = [change valueForKey: NSKeyValueChangeOldKey];
		NSArray *newDrives = [change valueForKey: NSKeyValueChangeNewKey];
		
		NSUInteger i, numDrives = [newDrives count];
		NSMutableIndexSet *selectedIndexes = [[NSMutableIndexSet alloc] init];
		
		for (i = 0; i < numDrives; i++)
		{
			if (![oldDrives containsObject: [newDrives objectAtIndex: i]])
			{
				[selectedIndexes addIndex: i];
			}
		}
		
		[[self drives] addSelectionIndexes: selectedIndexes];
		[selectedIndexes release];
	}
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
	NSArray *selection = [[self drives] selectedObjects];
	for (BXDrive *drive in selection) [NSApp sendAction: @selector(revealInFinder:) to: nil from: drive];
}

- (IBAction) openSelectedDrivesInDOS: (id)sender
{
	//Only bother grabbing the last drive selected
	BXDrive *drive = [[[self drives] selectedObjects] lastObject];
	if (drive) [NSApp sendAction: @selector(openInDOS:) to: nil from: drive];
}

- (IBAction) unmountSelectedDrives: (id)sender
{
	NSArray *selection = [[self drives] selectedObjects];
	BXSession *session = [[NSApp delegate] currentSession];
	if ([session shouldUnmountDrives: selection sender: self])
		[session unmountDrives: selection];
}

- (IBAction) importSelectedDrives: (id)sender
{
	NSArray *selection = [[self drives] selectedObjects];
	BXSession *session = [[NSApp delegate] currentSession];

	for (BXDrive *drive in selection) [session beginImportForDrive: drive];
}

- (IBAction) cancelImportForDrive: (id)sender
{
	BXDrive *drive = [[(BXDriveItemView *)[sender superview] delegate] representedObject];
	BXSession *session = [[NSApp delegate] currentSession];
	if (drive) [session cancelImportForDrive: drive];
}
- (IBAction) cancelImportsForSelectedDrives: (id)sender
{
	NSArray *selection = [[self drives] selectedObjects];
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
	
	NSArray *driveSelection = [[self drives] selectedObjects];
	BOOL hasSelection = ([driveSelection count] > 0);
	BOOL isGamebox = [session isGamePackage];
	BXEmulator *theEmulator = [session emulator];
	
	SEL action = [theItem action];
	
	if (action == @selector(revealSelectedDrivesInFinder:)) return hasSelection;
	if (action == @selector(unmountSelectedDrives:))
	{
		if (!hasSelection) return NO;
		
		//Check if any of the selected drives are locked or internal
		for (BXDrive *drive in [[self drives] selectedObjects])
		{
			if ([drive isLocked] || [drive isInternal]) return NO;
		}
		return YES;
	}
	if (action == @selector(openSelectedDrivesInDOS:))
	{
		return hasSelection && [session isEmulating] && ![theEmulator isRunningProcess];
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
	BXFileTransfer *transfer = [notification object];
	
	//If the notification didn't come from the current session, ignore it
	if ([transfer delegate] != [[NSApp delegate] currentSession]) return;
	
	BXDrive *drive = [transfer contextInfo];
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
	BXFileTransfer *transfer = [notification object];
	
	//If the notification didn't come from the current session, ignore it
	if ([transfer delegate] != [[NSApp delegate] currentSession]) return;
		
	BXDrive *drive = [transfer contextInfo];
	BXDriveItemView *driveView = [[self driveList] viewForDrive: drive];
	if (driveView)
	{
		NSProgressIndicator *progressMeter	= [driveView progressMeter];
		NSTextField *progressMeterLabel		= [driveView progressMeterLabel];
		BXOperationProgress progress		= [transfer currentProgress];
	
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

- (void) operationWasCancelled: (NSNotification *)notification
{
	BXFileTransfer *transfer = [notification object];
	
	//If the notification didn't come from the current session, ignore it
	if ([transfer delegate] != [[NSApp delegate] currentSession]) return;
	
	BXDrive *drive = [transfer contextInfo];
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
	BXFileTransfer *transfer = [notification object];
	
	//If the notification didn't come from the current session, ignore it
	if ([transfer delegate] != [[NSApp delegate] currentSession]) return;
	
	BXDrive *drive = [transfer contextInfo];
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
#pragma mark Drive list sorting

- (NSArray *) driveSortDescriptors
{
	NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey: @"letter" ascending: YES];
	return [NSArray arrayWithObject: [descriptor autorelease]];
}

- (NSPredicate *) driveFilterPredicate
{
	return [NSPredicate predicateWithFormat: @"isInternal == NO && isHidden == NO"];
}


#pragma mark -
#pragma mark Drag-drop

- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>)sender
{	
	//Ignore drags that originated from the drive list itself
	id source = [sender draggingSource];
	if ([[source window] isEqualTo: [[self view] window]]) return NSDragOperationNone;
	
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

@end
