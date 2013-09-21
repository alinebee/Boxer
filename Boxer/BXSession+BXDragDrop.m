/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXSessionPrivate.h"
#import "BXFileTypes.h"
#import "BXDOSWindowController.h"
#import "BXDOSWindow.h"
#import "BXEmulator+BXDOSFileSystem.h"
#import "BXEmulator+BXPaste.h"
#import "BXEmulatorErrors.h"
#import "NSURL+ADBFilesystemHelpers.h"
#import "NSWorkspace+ADBMountedVolumes.h"


//Private methods
@interface BXSession (BXDragDropPrivate)

- (NSDragOperation) _responseToDraggedURL: (NSURL *)URL;
- (BOOL) _handleDraggedURL: (NSURL *)URL
         launchImmediately: (BOOL)launch;

@end


@implementation BXSession (BXDragDrop)

//Return an array of all filetypes we will accept by drag-drop
- (NSSet *) droppableFileTypes
{
    if (!self.allowsDriveChanges)
        return [NSSet set];
    else
        return [[BXFileTypes mountableTypes] setByAddingObjectsFromSet: [BXFileTypes executableTypes]];
}

- (NSDragOperation) responseToDraggedURLs: (NSArray *)draggedURLs
{
	NSDragOperation response = NSDragOperationNone;
	for (NSURL *URL in draggedURLs)
	{
		//Decide what we'd do with this specific file
		response = [self _responseToDraggedURL: URL];
		//If any files in the pasteboard would be rejected then reject them all, as per the HIG
		if (response == NSDragOperationNone)
            return response;
	}
	//Otherwise, return whatever we'd do with the last item in the pasteboard
	return response;
}

- (NSDragOperation) responseToDraggedStrings: (NSArray *)draggedStrings
{
	NSDragOperation response = NSDragOperationNone;
    
    //Only permit string drops if we're displaying the DOS view at the moment.
    BOOL isShowingDOSView = (self.DOSWindowController.currentPanel == BXDOSWindowDOSView);
    if (isShowingDOSView)
    {
        for (NSString *draggedString in draggedStrings)
        {
            if ([self.emulator canAcceptPastedString: draggedString])
            {
                response = NSDragOperationCopy;
            }
            else
            {
                response = NSDragOperationNone;
                break;
            }
        }
    }
    return response;
}


//Called by BXDOSWindowController performDragOperation: when files have been drag-dropped onto Boxer.
- (BOOL) handleDraggedURLs: (NSArray *)draggedURLs launchImmediately: (BOOL)launch
{
	BOOL returnValue = NO;
	
	for (NSURL *URL in draggedURLs)
		returnValue = [self _handleDraggedURL: URL launchImmediately: launch] || returnValue;
	
	//If any dropped files were successfully handled, reactivate Boxer and return focus to the DOS window
    //so that the user can get on with using them.
	if (returnValue)
    {
        [self resume: self];
        
        [NSApp activateIgnoringOtherApps: YES];
        [self.DOSWindowController.window makeKeyAndOrderFront: self];
    }
	return returnValue;
}

//Called by BXDOSWindowController performDragOperation: when a string has been drag-dropped onto Boxer.
- (BOOL) handleDraggedStrings: (NSArray *)draggedStrings
{
	BOOL returnValue = NO;
    
    for (NSString *draggedString in draggedStrings)
        [self.emulator handlePastedString: draggedString asCommand: YES];
    
	//If the dragged string was successfully handled, reactivate Boxer and return focus to the DOS window.
    if (returnValue)
    {
        [self resume: self];
        
        [NSApp activateIgnoringOtherApps: YES];
        [self.DOSWindowController.window makeKeyAndOrderFront: self];
    }
    return returnValue;
}


#pragma mark -
#pragma mark Private methods

//This method indicates what we'll do with the dropped file, before we handle any actual drop.
- (NSDragOperation) _responseToDraggedURL: (NSURL *)URL
{
	BOOL isInProcess = self.emulator.isRunningProcess;
	
	//We wouldn't accept any files that aren't on our accepted formats list.
	if ([URL matchingFileType: self.droppableFileTypes] == nil)
        return NSDragOperationNone;
	
	//We wouldn't accept any executables if the emulator is running a process already.
	if (isInProcess && [URL matchingFileType: [BXFileTypes executableTypes]] != nil)
        return NSDragOperationNone;
	
	//If the path is already accessible in DOS, and doesn't deserve its own mount point...
	if (![self shouldMountNewDriveForURL: URL])
	{
		//...then we'd change the working directory to it, if we're not already busy; otherwise we'd reject it.
		return (isInProcess) ? NSDragOperationNone : NSDragOperationLink;
	}
	//If we get this far, it means we'd mount the dropped file as a new drive.
	return NSDragOperationCopy;
}


- (BOOL) _handleDraggedURL: (NSURL *)URL launchImmediately: (BOOL)launch
{	
	//First check if we ought to do anything with this URL, to be safe
	if ([self _responseToDraggedURL: URL] == NSDragOperationNone) return NO;
	
	//Keep track of whether we've done anything with the dropped URL yet
	BOOL performedAction = NO;
	
	//Make a new mount for the URL if we need
	if ([self shouldMountNewDriveForURL: URL])
	{
        NSError *mountError = nil;
		BXDrive *drive = [self mountDriveForURL: URL
                                       ifExists: BXDriveReplace
                                        options: BXDefaultDriveMountOptions
                                          error: &mountError];
        
		if (!drive)
        {
            if (mountError)
            {
                [self presentError: mountError
                    modalForWindow: self.windowForSheet
                          delegate: nil
                didPresentSelector: NULL
                       contextInfo: NULL];
            }
            return NO; //mount failed, don't continue further
        }
		performedAction = YES;
	}
	
	//Launch the URL in the emulator
	if (launch)
    {
        NSError *launchError = nil;
        BOOL launched = [self openURLInDOS: URL
                             withArguments: nil
                               clearScreen: NO
                              onCompletion: BXSessionShowDOSPromptIfDirectory
                                     error: &launchError];
        
        if (!launched && launchError)
        {
            [self presentError: launchError
                modalForWindow: self.windowForSheet
                      delegate: nil
            didPresentSelector: NULL
                   contextInfo: NULL];
        }
        
        performedAction = launched || performedAction;
	}
    
	//Report whether or not anything actually happened as a result of the drop
	return performedAction;
}

@end
