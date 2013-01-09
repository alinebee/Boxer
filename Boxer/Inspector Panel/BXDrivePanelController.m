/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDrivePanelController.h"
#import "BXBaseAppController.h"
#import "BXSession+BXFileManagement.h"
#import "BXSession+BXDragDrop.h"
#import "BXEmulator+BXDOSFileSystem.h"
#import "BXEmulatorErrors.h"
#import "BXDrive.h"
#import "BXValueTransformers.h"
#import "BXDriveImport.h"
#import "BXDriveList.h"
#import "BXDriveItem.h"
#import "NSWindow+BXWindowDimensions.h"


#pragma mark -
#pragma mark Private constants

//The segment indexes of the drive options control
enum {
	BXAddDriveSegment			= 0,
	BXRemoveDrivesSegment		= 1,
	BXToggleDrivesSegment		= 1,
	BXDriveActionsMenuSegment	= 2
};


#pragma mark -
#pragma mark Implementation

@implementation BXDrivePanelController
@synthesize driveControls = _driveControls;
@synthesize driveActionsMenu = _driveActionsMenu;
@synthesize driveList = _driveList;
@synthesize selectedDriveIndexes = _selectedDriveIndexes;

#pragma mark -
#pragma mark Initialization and teardown

+ (void) initialize
{
    if (self == [BXDrivePanelController class])
    {
        BXDisplayPathTransformer *fullDisplayPath = [[BXDisplayPathTransformer alloc] initWithJoiner: @" ▸ "
                                                                                       maxComponents: 4];
        
        BXDisplayNameTransformer *displayName = [[BXDisplayNameTransformer alloc] init];
        
        [NSValueTransformer setValueTransformer: fullDisplayPath forName: @"BXDriveDisplayPath"];
        [NSValueTransformer setValueTransformer: displayName forName: @"BXDriveDisplayName"];
        
        [fullDisplayPath release];
        [displayName release];
    }
}

- (void) awakeFromNib
{
    //Make our represented object be the drive array for the current session.
    [self bind: @"representedObject"
      toObject: [NSApp delegate]
   withKeyPath: @"currentSession.allDrives"
       options: nil];
    
    //Listen for changes to the current session's mounted drives, so we can enable/disable our action buttons
    [[NSApp delegate] addObserver: self
                       forKeyPath: @"currentSession.mountedDrives"
                          options: 0
                          context: NULL];
    
    
	//Register the entire drive panel as a drag-drop target.
	[self.view registerForDraggedTypes: [NSArray arrayWithObject: NSFilenamesPboardType]];
    
	//Assign the appropriate menu to the drive-actions button segment.
	[self.driveControls setMenu: self.driveActionsMenu forSegment: BXDriveActionsMenuSegment];
	
	//Listen for drive import notifications and drive-added notifications.
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center addObserver: self selector: @selector(operationWillStart:) name: BXOperationWillStart object: nil];
	[center addObserver: self selector: @selector(operationDidFinish:) name: BXOperationDidFinish object: nil];
	[center addObserver: self selector: @selector(operationInProgress:) name: BXOperationInProgress object: nil];
	[center addObserver: self selector: @selector(operationWasCancelled:) name: BXOperationWasCancelled object: nil];
    
	[center addObserver: self selector: @selector(emulatorDriveDidMount:) name: @"BXDriveDidMountNotification" object: nil];
}


- (void) dealloc
{
	//Clean up notifications and bindings
    [self unbind: @"currentSession.allDrives"];
    [[NSApp delegate] removeObserver: self forKeyPath: @"currentSession.mountedDrives"];
    
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center removeObserver: self];
    
    self.selectedDriveIndexes = nil;
    self.driveList = nil;
    self.driveControls = nil;
    self.driveActionsMenu = nil;
    
	[super dealloc];
}

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
    if ([keyPath isEqualToString: @"currentSession.mountedDrives"])
    {
        [self syncButtonStates];
    }
}

//Select the latest drive whenever a drive is added
- (void) emulatorDriveDidMount: (NSNotification *)notification
{
    BXDrive *drive = [notification.userInfo objectForKey: @"drive"];
    NSUInteger driveIndex = [self.drives indexOfObject: drive];
    if (driveIndex != NSNotFound)
    {
        self.selectedDriveIndexes = [NSIndexSet indexSetWithIndex: driveIndex];
    }
}

- (void) syncButtonStates
{
	//Disable the appropriate drive controls when there are no selected items or no session.
    BXSession *session      = [[NSApp delegate] currentSession];
    BOOL hasSelection       = self.selectedDrives.count > 0;
    
    [self.driveControls setEnabled: (session != nil)  forSegment: BXAddDriveSegment];
    [self.driveControls setEnabled: hasSelection      forSegment: BXRemoveDrivesSegment];
    [self.driveControls setEnabled: hasSelection      forSegment: BXDriveActionsMenuSegment];
}


+ (NSSet *) keyPathsForValuesAffectingDrives
{
    return [NSSet setWithObject: @"representedObject"];
}

- (NSArray *) drives
{
    return [self.representedObject filteredArrayUsingPredicate: self.driveFilterPredicate];
}

- (NSPredicate *) driveFilterPredicate
{
    return [NSPredicate predicateWithFormat: @"isHidden = NO && isInternal = NO"];
}

- (void) setSelectedDriveIndexes: (NSIndexSet *)indexes
{
    if (![indexes isEqualToIndexSet: self.selectedDriveIndexes])
    {
        [_selectedDriveIndexes release];
        _selectedDriveIndexes = [indexes retain];
        
        //Sync the action buttons whenever our selection changes
        [self syncButtonStates];
    }
}

- (NSArray *) selectedDrives
{
    if (self.selectedDriveIndexes.count)
    {
        NSArray *drives = [[NSApp delegate] currentSession].allDrives;
        return [drives objectsAtIndexes: self.selectedDriveIndexes];
    }
    else return [NSArray array];
}


#pragma mark -
#pragma mark Interface actions

- (IBAction) interactWithDriveOptions: (NSSegmentedControl *)sender
{
	switch (sender.selectedSegment)
	{
		case BXAddDriveSegment:
			[self showMountPanel: sender];
			break;
			
		case BXRemoveDrivesSegment:
			[self removeSelectedDrives: sender];
			break;
			
		case BXDriveActionsMenuSegment:
			break;
	}
}

- (IBAction) revealSelectedDrivesInFinder: (id)sender
{
	for (BXDrive *drive in self.selectedDrives)
    {
        [[NSApp delegate] revealPath: drive.path];
        //Also reveal the drive's shadow directory, if it has one.
        if (drive.shadowPath)
            [[NSApp delegate] revealPath: drive.shadowPath];
    }
}


- (IBAction) openSelectedDrivesInDOS: (id)sender
{
	//Only bother grabbing the last drive selected
	BXDrive *drive = self.selectedDrives.lastObject;
	if (drive)
        [NSApp sendAction: @selector(openInDOS:) to: nil from: drive];
}

- (IBAction) toggleSelectedDrives: (id)sender
{
	BXSession *session = [[NSApp delegate] currentSession];
    
    //If any of the drives are mounted, this will act as an unmount operation.
    //Otherwise, it will act as a mount operation.
    //(A moot point, since we only allow one item to be selected at the moment.)
    BOOL selectionContainsMountedDrives = NO;
    for (BXDrive *drive in self.selectedDrives)
    {
        if ([session driveIsMounted: drive])
        {
            selectionContainsMountedDrives = YES;
            break;
        }
    }
    if (selectionContainsMountedDrives)
        [self unmountSelectedDrives: sender];
    else
        [self mountSelectedDrives: sender];
}

- (IBAction) mountSelectedDrives: (id)sender
{
	BXSession *session = [[NSApp delegate] currentSession];
    
    for (BXDrive *drive in self.selectedDrives)
    {
        NSError *unmountError;
        [session mountDrive: drive
                   ifExists: BXDriveReplace
                    options: BXDefaultDriveMountOptions
                      error: &unmountError];
        
        if (unmountError)
        {
            NSWindow *targetWindow = [[NSApp delegate] currentSession].windowForSheet;
            [targetWindow.attachedSheet orderOut: self];
            [targetWindow presentError: unmountError
                        modalForWindow: targetWindow
                              delegate: nil
                    didPresentSelector: NULL
                           contextInfo: NULL];
            break;
        }
    }
}

- (BOOL) _unmountDrives: (NSArray *)drives options: (BXDriveMountOptions)options
{
    BXSession *session = [[NSApp delegate] currentSession];
	if ([session shouldUnmountDrives: drives
                        usingOptions: options
                              sender: self])
    {
        NSError *unmountError = nil;
		[session unmountDrives: drives
                       options: options
                         error: &unmountError];
        
        if (unmountError)
        {
            NSWindow *targetWindow = [[NSApp delegate] currentSession].windowForSheet;
            [targetWindow.attachedSheet orderOut: self];
            [targetWindow presentError: unmountError
                        modalForWindow: targetWindow
                              delegate: nil
                    didPresentSelector: NULL
                           contextInfo: NULL];
            return NO;
        }
        else return YES;
    }
    else return NO;
}

- (IBAction) unmountSelectedDrives: (id)sender
{
    [self _unmountDrives: self.selectedDrives
                 options: BXDefaultDriveUnmountOptions];
}

- (IBAction) removeSelectedDrives: (id)sender
{
    [self _unmountDrives: self.selectedDrives
                 options: BXDefaultDriveUnmountOptions | BXDriveRemoveExistingFromQueue];
}

- (IBAction) importSelectedDrives: (id)sender
{
	BXSession *session = [[NSApp delegate] currentSession];

	for (BXDrive *drive in self.selectedDrives)
        [session importOperationForDrive: drive startImmediately: YES];
}

- (IBAction) cancelImportsForSelectedDrives: (id)sender
{
	BXSession *session = [[NSApp delegate] currentSession];
    
	for (BXDrive *drive in self.selectedDrives)
        [session cancelImportForDrive: drive];
}

- (IBAction) showMountPanel: (id)sender
{
	//Make sure the application is active; since we support clickthrough,
	//Boxer may be in the background when this action is sent.
	[NSApp activateIgnoringOtherApps: YES];
	
	//Pass mount panel action upstream - this works around the fiddly separation of responder chains
	//between the inspector panel and main DOS window.
	[NSApp sendAction: @selector(showMountPanel:) to: nil from: self];
}

- (BOOL) validateMenuItem: (NSMenuItem *)theItem
{
	BXSession *session = [[NSApp delegate] currentSession];
	//If there's currently no active session, we can't do anything
	if (!session) return NO;
	
	NSArray *selectedDrives = self.selectedDrives;
	BOOL hasGamebox = session.hasGamebox;
    BOOL hasSelection = selectedDrives.count > 0;
	BXEmulator *theEmulator = session.emulator;

	SEL action = theItem.action;
	
	if (action == @selector(revealSelectedDrivesInFinder:))
    {
        return hasSelection;
    }
    
	if (action == @selector(removeSelectedDrives:))
	{
        if (!hasSelection) return NO;
        
        BOOL selectionContainsMountedDrives = NO;
		//Check if any of the selected drives are locked or internal
		for (BXDrive *drive in selectedDrives)
		{
			if (drive.isLocked || drive.isInternal) return NO;
            if (!selectionContainsMountedDrives && [session driveIsMounted: drive])
                selectionContainsMountedDrives = YES;
		}
        
        if (selectionContainsMountedDrives)
            theItem.title = NSLocalizedString(@"Eject and Remove from List",
                                              @"Label for drive panel menu item to remove selected drives entirely from the drive list. Shown when one or more selected drives is currently mounted.");
        else
            theItem.title = NSLocalizedString(@"Remove from List",
                                              @"Label for drive panel menu item to remove selected drives entirely from the drive list. Shown when all selected drives are inactive.");
        
		return YES;
	}
    
	if (action == @selector(openSelectedDrivesInDOS:))
	{
        if (!hasSelection) return NO;
        
		BOOL isCurrent = [selectedDrives.lastObject isEqual: theEmulator.currentDrive];
		
		if (isCurrent)
		{
			theItem.title = NSLocalizedString(@"Current Drive",
                                              @"Menu item title for when selected drive is already the current DOS drive.");
		}
		else
        {
            theItem.title = NSLocalizedString(@"Make Current Drive",
                                              @"Menu item title for switching to the selected drive in DOS.");
        }
        
		//Deep breath now: only enable option if...
		//- only one drive is selected
		//- the drive isn't already the current drive
		//- the session is at the DOS prompt and thus able to safely switch drives
		return !isCurrent && selectedDrives.count == 1 && theEmulator.isAtPrompt;
	}
	
	if (action == @selector(importSelectedDrives:))
	{
    	//Initial label for drive import items (may be modified below)
        theItem.title = NSLocalizedString(@"Import into Gamebox",
                                          @"Menu item title/tooltip for importing drive into gamebox.");
		
		//Hide this item altogether if we're not running a session
		theItem.hidden = !hasGamebox;
        
		if (!hasGamebox || !hasSelection) return NO;
		 
		//Check if any of the selected drives are being imported, already imported, or otherwise cannot be imported
		for (BXDrive *drive in selectedDrives)
		{
			if ([session activeImportOperationForDrive: drive])
			{
                theItem.title = NSLocalizedString(@"Importing into Gamebox…",
                                                  @"Drive import menu item title, when selected drive(s) are already in the gamebox.");
				return NO;
			}
			else if ([session driveIsBundled: drive] || [session equivalentDriveIsBundled: drive])
			{
                theItem.title = NSLocalizedString(@"Included in Gamebox",
                                                  @"Drive import menu item title, when selected drive(s) are already in the gamebox.");
				return NO;
			}
			else if (![session canImportDrive: drive])
                return NO;
		}
		//If we get this far then yes, it's ok
		return YES;
	}
	
	if (action == @selector(cancelImportsForSelectedDrives:))
	{
        if (!hasSelection) return NO;
        
		if (hasGamebox) for (BXDrive *drive in selectedDrives)
		{	
			//If any of the selected drives are being imported, then enable and unhide the item
			if ([session activeImportOperationForDrive: drive])
			{
                theItem.hidden = NO;
				return YES;
			}
		}
		//Otherwise, hide the item
        theItem.hidden = YES;
		return NO;
	}
    
    if (action == @selector(toggleSelectedDrives:))
    {
        if (!hasSelection) return NO;
        
        //Update the title to reflect whether this will add or remove drives
        BOOL selectionContainsMountedDrives = NO;
        for (BXDrive *drive in selectedDrives)
        {
            if ([session driveIsMounted: drive])
            {
                selectionContainsMountedDrives = YES;
                break;
            }
        }
        
        if (selectionContainsMountedDrives)
            theItem.title = NSLocalizedString(@"Eject drive", @"Label/tooltip for ejecting mounted drives.");
        else
            theItem.title = NSLocalizedString(@"Mount drive", @"Label/tooltip for mounting unmounted drives.");
        
        return YES;
    }
	
	return YES;
}


#pragma mark -
#pragma mark Drive import progress handling

- (void) operationWillStart: (NSNotification *)notification
{
	BXOperation <BXDriveImport> *transfer = notification.object;
	
	if ([transfer conformsToProtocol: @protocol(BXDriveImport)])
    {
        BXDrive *drive = transfer.drive;
        BXDriveItem *item = [self.driveList itemForDrive: drive];
        
        if (item)
            [item driveImportWillStart: notification];
    }
}

- (void) operationInProgress: (NSNotification *)notification
{
	BXOperation <BXDriveImport> *transfer = notification.object;
	
	if ([transfer conformsToProtocol: @protocol(BXDriveImport)])
    {
        BXDrive *drive = transfer.drive;
        BXDriveItem *item = [self.driveList itemForDrive: drive];
        
        if (item)
            [item driveImportInProgress: notification];
    }
}

- (void) operationWasCancelled: (NSNotification *)notification
{
	BXOperation <BXDriveImport> *transfer = notification.object;
	
	if ([transfer conformsToProtocol: @protocol(BXDriveImport)])
    {
        BXDrive *drive = transfer.drive;
        BXDriveItem *item = [self.driveList itemForDrive: drive];
        
        if (item)
            [item driveImportWasCancelled: notification];
    }
}

- (void) operationDidFinish: (NSNotification *)notification
{
	BXOperation <BXDriveImport> *transfer = notification.object;
	
	if ([transfer conformsToProtocol: @protocol(BXDriveImport)])
    {
        BXDrive *drive = transfer.drive;
        BXDriveItem *item = [self.driveList itemForDrive: drive];
        
        if (item)
            [item driveImportDidFinish: notification];
    }
}


#pragma mark -
#pragma mark Drag-drop

- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>)sender
{	
	//Ignore drags that originated from the drive list itself
	id source = sender.draggingSource;
	if ([[source window] isEqual: self.view.window])
        return NSDragOperationNone;
	
	//Otherwise, ask the current session what it would like to do with the files
	NSPasteboard *pboard = sender.draggingPasteboard;
	if ([pboard.types containsObject: NSFilenamesPboardType])
	{
		NSArray *filePaths = [pboard propertyListForType: NSFilenamesPboardType];
		BXSession *session = [[NSApp delegate] currentSession];
		return [session responseToDroppedFiles: filePaths];
	}
	else return NSDragOperationNone;
}

- (BOOL) performDragOperation: (id <NSDraggingInfo>)sender
{	
	NSPasteboard *pboard = sender.draggingPasteboard;
	if ([pboard.types containsObject: NSFilenamesPboardType])
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
    NSArray *chosenDrives = [self.drives objectsAtIndexes: indexes];
    NSArray *filePaths = [chosenDrives valueForKeyPath: @"path"];
    
    [pasteboard declareTypes: [NSArray arrayWithObject: NSFilenamesPboardType] owner: self];	
    [pasteboard setPropertyList: filePaths forType: NSFilenamesPboardType];
    
    return YES;
}

- (NSDragOperation) draggingSourceOperationMaskForLocal: (BOOL)isLocal
{
	return (isLocal) ? NSDragOperationPrivate : NSDragOperationNone;
}

//Required for us to work as a dragging source *rolls eyes all the way out of head*
- (NSWindow *) window
{
    return self.view.window;
}


//While dragging, this checks for valid Boxer windows under the cursor; if there aren't any, it displays
//a disappearing item cursor (poof) to indicate the action will discard the dragged drive(s).
- (void) draggedImage: (NSImage *)draggedImage
              movedTo: (NSPoint)screenPoint
{
    //Once the image is dragged away from its original location, hide the views represented by the image.
    for (BXDrive *drive in self.selectedDrives)
    {
        NSView *itemView = [self.driveList viewForDrive: drive];
        itemView.hidden = YES;
    }
    
	NSPoint mousePoint = [NSEvent mouseLocation];
	NSCursor *poof = [NSCursor disappearingItemCursor];
	
	//If there's no Boxer window under the mouse cursor,
	//change the cursor to a poof to indicate we will discard the drive
	if (![NSWindow windowAtPoint: mousePoint])
        [poof set];
	
	//otherwise, revert any poof cursor (which may already have been changed
    //by valid drag destinations anyway) 
	else if ([[NSCursor currentCursor] isEqual: poof])
        [[NSCursor arrowCursor] set];
}

//This is called when dragging completes, and discards the drive if it was not dropped onto a valid destination
//(or back onto the drive list).
- (void) draggedImage: (NSImage *)draggedImage
			  endedAt: (NSPoint)screenPoint
		    operation: (NSDragOperation)operation
{
	NSPoint mousePoint = [NSEvent mouseLocation];
	
    BOOL unhideSelection = YES;
    
    //If the user dropped these items outside the app, then remove them
    //(operation will be private if the drag landed on a window outside the app)
	if (operation == NSDragOperationNone && ![NSWindow windowAtPoint: mousePoint])
	{
        BOOL drivesRemoved = [self _unmountDrives: self.selectedDrives
                                          options: BXDefaultDriveUnmountOptions | BXDriveRemoveExistingFromQueue];
        
		//If the drives were successfully removed by the action,
        //display the poof animation
		if (drivesRemoved)
		{
            //Leave the selected drives hidden, so that their
            //disappearing animation won't be visible.
            unhideSelection = NO;
            
			//Calculate the center-point of the image for displaying the poof icon
			NSRect imageRect;
			imageRect.size = draggedImage.size;
			imageRect.origin = screenPoint;	
            
			NSPoint midPoint = NSMakePoint(NSMidX(imageRect), NSMidY(imageRect));
            
			//We make it square instead of fitting the width of the image,
            //to avoid distorting the puff of smoke
			NSSize poofSize = imageRect.size;
			poofSize.width = poofSize.height;
			
			//Play the poof animation
			NSShowAnimationEffect(NSAnimationEffectPoof, midPoint, poofSize, nil, nil, nil);
		}
	}
	
	//Once the drag has finished, clean up by unhiding the dragged items
    //(Unless all the dragged items were ejected and removed, in which case
    //leave them hidden so that they don't reappear and then vanish again.)
	if (unhideSelection)
    {
        for (BXDrive *drive in self.selectedDrives)
        {
            NSView *itemView = [self.driveList viewForDrive: drive];
            itemView.hidden = NO;
        }
    }
    
    //Reset the cursor back to normal
    [[NSCursor arrowCursor] set];
}

@end


@implementation BXDriveOptionsSegmentedCell

- (SEL) action
{
    if ([self menuForSegment: self.selectedSegment] != nil) return NULL;
    
    return [super action];
}
@end