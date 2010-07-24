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
	[center addObserver: self selector: @selector(fileTransferDidFinish:) name: BXFileTransferDidFinish object: nil];
	[center addObserver: self selector: @selector(fileTransferInProgress:) name: BXFileTransferInProgress object: nil];
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

//Observe the drive list to respond when its content or selections change
- (void) setDriveList: (BXDriveList *)theList
{
	if (theList != driveList)
	{
		if (driveList)
		{
			[driveList removeObserver: self forKeyPath: @"selectionIndexes"];
			[driveList removeObserver: self forKeyPath: @"content"];
		}
		
		[driveList release];
		driveList = [theList retain];
		
		if (driveList)
		{
			[driveList addObserver: self
						forKeyPath: @"selectionIndexes"
						   options: NSKeyValueObservingOptionInitial
						   context: nil];
			
			[driveList addObserver: self
						forKeyPath: @"content"
						   options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
						   context: nil];
		}
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
		BOOL hasSelection = ([[object selectionIndexes] count] > 0);
		[[self driveControls] setEnabled: hasSelection forSegment: BXRemoveDrivesSegment];
		[[self driveControls] setEnabled: hasSelection forSegment: BXDriveActionsMenuSegment];
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
	
	//Show progress meters for drives that are being imported.
	else if ([keyPath isEqualToString: @"currentSession.driveImportOperations"])
	{
		
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

- (BOOL) validateUserInterfaceItem: (id)theItem
{
	BOOL hasSelection = ([[[self drives] selectedObjects] count] > 0);
	BXSession *session = [[NSApp delegate] currentSession];
	BXEmulator *theEmulator = [session emulator];
	
	SEL action = [theItem action];
	if (action == @selector(showMountPanel:))				return (session != nil);
	if (action == @selector(revealSelectedDrivesInFinder:)) return hasSelection;
	if (action == @selector(unmountSelectedDrives:))
	{
		if (!hasSelection || ![session isEmulating]) return NO;
		
		//Check if any of the selected drives are locked
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
		
		BOOL isGamebox = [session isGamePackage];
		//Hide these menu items if we're not running a session
		[theItem setHidden: !isGamebox];
		if (!isGamebox || !hasSelection) return NO;
		
		 
		//Check if any of the selected drives are internal or already imported
		for (BXDrive *drive in [[self drives] selectedObjects])
		{
			//Change the menu item title to reflect that the selected drive
			//is already in the gamebox
			if ([session driveIsBundled: drive])
			{
				[theItem setTitle: NSLocalizedString(@"Part of gamebox", @"Drive import menu item title, when selected drive(s) are already in the gamebox.")];
				return NO;
			}
			if ([drive isInternal] || [drive isHidden]) return NO;
		}
		return YES;
	}
	return YES;
}


#pragma mark -
#pragma mark Drive import progressbar handling

- (void) fileTransferInProgress: (NSNotification *)notification
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
		
		BOOL indeterminate = [transfer numFiles] == 1;
		//Use an indeterminate progress meter for single-file transfers,
		//since we can't measure the progress properly
		[progressMeter setIndeterminate: indeterminate];
		[progressMeter startAnimation: self];
		[progressMeter setDoubleValue: [transfer currentProgress]];
		
		//Unhide the progress indicator and hide the type label it covers
		[typeLabel setHidden: YES];
		[progressMeter setHidden: NO];
		[progressMeterLabel setHidden: NO];
		
		//[driveView setNeedsDisplay: YES];
	}
}

- (void) fileTransferDidFinish: (NSNotification *)notification
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
		
		//Re-hide the various bits of the animation
		[progressMeter stopAnimation: self];
		[progressMeter setHidden: YES];
		[progressMeterLabel setHidden: YES];
		[typeLabel setHidden: NO];
		
		//[driveView setNeedsDisplay: YES];
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
