/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXAppController.h"
#import "BXSession+BXDragDrop.h"
#import "BXSession+BXFileManager.h"
#import "BXEmulator+BXDOSFileSystem.h"
#import "BXEmulator+BXInput.h"
#import "NSWorkspace+BXFileTypes.h"
#import "NSWorkspace+BXMountedVolumes.h"


@implementation BXSession (BXDragDrop)

//Return an array of all filetypes we will accept by drag-drop
+ (NSArray *) droppableFileTypes
{
	return [[BXAppController mountableTypes] arrayByAddingObjectsFromArray: [BXAppController executableTypes]];
}


//Called by BXSessionWindowController draggingEntered: to figure out what we'd do with dropped files.
- (NSDragOperation) responseToDroppedFiles: (NSArray *)filePaths
{
	NSDragOperation response = NSDragOperationNone;
	for (NSString *filePath in filePaths)
	{
		//Decide what we'd do with this specific file
		response = [self _responseToDroppedFile: filePath];
		//If any files in the pasteboard would be rejected then reject them all, as per the HIG
		if (response == NSDragOperationNone) return response;
	}
	//Otherwise, return whatever we'd do with the last item in the pasteboard
	return response;
}

//Called by BXSessionWindowController draggingEntered: to figure out what we'd do with a dropped string.
- (NSDragOperation) responseToDroppedString: (NSString *)droppedString
{
	if ([[self emulator] canAcceptPastedString: droppedString]) return NSDragOperationCopy;
	else return NSDragOperationNone;
}


//Called by BXSessionWindowController performDragOperation: when files have been drag-dropped onto Boxer.
- (BOOL) handleDroppedFiles: (NSArray *)filePaths withLaunching: (BOOL)launch
{
	BXEmulator *theEmulator = [self emulator];
	BOOL returnValue = NO;
	
	for (NSString *filePath in filePaths)
		returnValue = [self _handleDroppedFile: filePath withLaunching: launch] || returnValue;
	
	//If any dropped files were successfully handled, return focus to the window so that the user can get on with using them.
	
	if (returnValue) [[[self mainWindowController] window] makeKeyAndOrderFront: self];
	return returnValue;
}

//Called by BXSessionWindowController performDragOperation: when a string has been drag-dropped onto Boxer.
- (BOOL) handleDroppedString: (NSString *)droppedString
{
	return [[self emulator] handlePastedString: droppedString];
}

@end


@implementation BXSession (BXDragDropInternals)


//This method indicates what we'll do with the dropped file, before we handle any actual drop.
- (NSDragOperation) _responseToDroppedFile: (NSString *)filePath
{
	BXEmulator *theEmulator = [self emulator];
	NSWorkspace *workspace	= [NSWorkspace sharedWorkspace];
	
	BOOL isInProcess = [theEmulator isRunningProcess];
	
	//We wouldn't accept any files that aren't on our accepted formats list.
	if (![workspace file: filePath matchesTypes: [[self class] droppableFileTypes]]) return NSDragOperationNone;
	
	//We wouldn't accept any executables if the emulator is running a process already.
	if (isInProcess && [[self class] isExecutable: filePath]) return NSDragOperationNone;
	
	//If the path is already accessible in DOS, and doesn't deserve its own mount point...
	if (![self shouldMountDriveForPath: filePath])
	{
		//...then we'd change the working directory to it, if we're not already busy; otherwise we'd reject it.
		return (isInProcess) ? NSDragOperationNone : NSDragOperationLink;
	}
	
	//If we get this far, it means we'd mount the dropped file as a new drive.
	return NSDragOperationCopy;
}


- (BOOL) _handleDroppedFile: (NSString *)filePath withLaunching: (BOOL)launch
{
	BXEmulator *theEmulator = [self emulator];
	
	//First check if we ought to do anything with this file, to be safe
	if ([self _responseToDroppedFile: filePath] == NSDragOperationNone) return NO;
	
	//Keep track of whether we've done anything with the dropped file yet
	BOOL performedAction = NO;
	
	//Make a new mount for the path if we need
	if ([self shouldMountDriveForPath: filePath])
	{
		BXDrive *drive = [self mountDriveForPath: filePath];
		if (!drive) return NO; //mount failed, don't continue further
		performedAction = YES;
	}
	
	//Launch the path in the emulator
	if (launch) performedAction = [self openFileAtPath: filePath] || performedAction;
	
	//Report whether or not anything actually happened as a result of the drop
	return performedAction;
}

@end