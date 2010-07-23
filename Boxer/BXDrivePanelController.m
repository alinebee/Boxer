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

//The segments of the drive options control
enum {
	BXAddDriveSegment			= 0,
	BXRemoveDrivesSegment		= 1,
	BXDriveActionsMenuSegment	= 2
};

@implementation BXDrivePanelController
@synthesize driveControls, driveActionsMenu, drives, driveList;

#pragma mark -
#pragma mark Initialization and teardown

- (void) awakeFromNib
{
	//Register the entire drive panel as a drag-drop target.
	[[self view] registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, NSStringPboardType, nil]];	
	
	//Assign the appropriate menu to the drive menu segment.
	[[self driveControls] setMenu: [self driveActionsMenu] forSegment: BXDriveActionsMenuSegment];
}

- (void) setDrives: (NSArrayController *)theDrives
{
	[self willChangeValueForKey: @"drives"];
	if (theDrives != drives)
	{
		if (drives) [drives removeObserver: self forKeyPath: @"selectionIndexes"];

		[drives release];
		drives = [theDrives retain];

		if (drives) [drives addObserver: self
							 forKeyPath: @"selectionIndexes"
								options: NSKeyValueObservingOptionInitial
								context: nil];
	}
	[self didChangeValueForKey: @"drives"];
}

- (void) dealloc
{	 
	[self setDriveList: nil],			[driveList release];
	[self setDrives: nil],				[drives release];
	[self setDriveControls: nil],		[driveControls release];
	[self setDriveActionsMenu: nil],	[driveActionsMenu release];
	[super dealloc];
}

//Disable the drive menu button when there are no selected items
- (void) observeValueForKeyPath: (NSString *)keyPath
					   ofObject: (id)object
						 change: (NSDictionary *)change
						context: (void *)context
{	
	if ([keyPath isEqualToString: @"selectionIndexes"])
	{
		BOOL hasSelection = ([[object selectionIndexes] count] > 0);
		[[self driveControls] setEnabled: hasSelection forSegment: BXRemoveDrivesSegment];
		[[self driveControls] setEnabled: hasSelection forSegment: BXDriveActionsMenuSegment];
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

- (IBAction) showMountPanel: (id)sender
{
	//Make sure the application is active, as we support clickthrough
	//so we may be in the background when this happens.
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
	return YES;
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
		
		NSArray *oldDrives = [[self drives] content];
		BOOL addedDrives = [session handleDroppedFiles: filePaths withLaunching: NO];
		
		if (addedDrives)
		{
			//Compare the drive list before and after, and select the first new drive
			NSArray *newDrives = [[self drives] content];
			for (BXDrive *drive in newDrives)
			{
				if (![oldDrives containsObject: drive])
				{
					[[self drives] setSelectedObjects: [NSArray arrayWithObject: drive]];
					break;
				}
			}
		}
		return addedDrives;
	}		
	return NO;
}

@end
