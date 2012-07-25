/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXSession+BXFileManager.h"
#import "BXSessionPrivate.h"
#import "BXFileTypes.h"
#import "BXBaseAppController+BXSupportFiles.h"

#import "BXEmulator+BXDOSFileSystem.h"
#import "BXEmulatorErrors.h"
#import "BXEmulator+BXShell.h"
#import "UKFNSubscribeFileWatcher.h"
#import "BXPackage.h"
#import "BXDrive.h"
#import "BXDrivesInUseAlert.h"
#import "BXGameProfile.h"
#import "BXDriveImport.h"
#import "BXExecutableScan.h"

#import "NSWorkspace+BXMountedVolumes.h"
#import "NSWorkspace+BXFileTypes.h"
#import "NSWorkspace+BXExecutableTypes.h"
#import "NSString+BXPaths.h"
#import "NSFileManager+BXTemporaryFiles.h"
#import "BXPathEnumerator.h"
#import "RegexKitLite.h"
#import "BXBezelController.h"


//Boxer will delay its handling of volume mount notifications by this many seconds,
//to allow multipart volumes to finish mounting properly
#define BXVolumeMountDelay 1.0


//The methods in this category are not intended to be called outside BXSession.
@interface BXSession (BXFileManagerPrivate)

- (void) volumeDidMount:		(NSNotification *)theNotification;
- (void) volumeWillUnmount:		(NSNotification *)theNotification;
- (void) filesystemDidChange:	(NSNotification *)theNotification;

- (void) _handleVolumeDidMount: (NSNotification *)theNotification;

- (void) _startTrackingChangesAtPath:	(NSString *)path;
- (void) _stopTrackingChangesAtPath:	(NSString *)path;

@end


@implementation BXSession (BXFileManager)

#pragma mark -
#pragma mark Helper class methods

+ (NSSet *) hiddenFilenamePatterns
{
	static NSSet *exclusions = nil;
	if (!exclusions) exclusions = [[NSSet alloc] initWithObjects:
								   [BXConfigurationFileName stringByAppendingPathExtension: BXConfigurationFileExtension],
								   [BXGameInfoFileName stringByAppendingPathExtension: BXGameInfoFileExtension],
								   BXTargetSymlinkName,
								   @"Icon\r",
								   nil];
    
	return exclusions;
}

+ (NSString *) preferredMountPointForPath: (NSString *)filePath
{	
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	
	//If the path is a disc image, use that as the mount point.
	if ([workspace file: filePath matchesTypes: [BXFileTypes mountableImageTypes]]) return filePath;
	
	//If the path is (itself or inside) a gamebox or mountable folder, use that as the mount point.
	NSString *container = [workspace parentOfFile: filePath matchingTypes: [self.class preferredMountPointTypes]];
    if (container) return container;
	
	//Check what kind of volume the file is on
	NSString *volumePath = [workspace volumeForPath: filePath];
	NSString *volumeType = [workspace volumeTypeForPath: filePath];
    
	//If it's on a data CD volume or floppy volume, use the base folder of the volume as the mount point
	if ([volumeType isEqualToString: dataCDVolumeType] || [workspace isFloppyVolumeAtPath: volumePath])
	{
		return volumePath;
	}
	//If it's on an audio CD, hunt around for a corresponding data CD volume and use that as the mount point if found
	else if ([volumeType isEqualToString: audioCDVolumeType])
	{
		NSString *dataVolumePath = [workspace dataVolumeOfAudioCD: volumePath];
		if (dataVolumePath) return dataVolumePath;
	}
	
	//If we get this far, then treat the path as a regular file or folder.
	BOOL isFolder;
	NSFileManager *manager = [NSFileManager defaultManager];
	[manager fileExistsAtPath: filePath isDirectory: &isFolder];
	
	//If the path is a folder, use it directly as the mount point...
	if (isFolder) return filePath;
	
	//...otherwise use the path's parent folder.
	else return [filePath stringByDeletingLastPathComponent]; 
}

+ (NSString *) gameDetectionPointForPath: (NSString *)path shouldSearchSubfolders: (BOOL *)shouldRecurse
{
	if (shouldRecurse) *shouldRecurse = YES;
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	
	NSArray *typeOrder = [NSArray arrayWithObjects: BXGameboxType, BXMountableFolderType, nil];
	
	//If the file is inside a gamebox (first in preferredMountPointTypes) then search from that;
	//If the file is inside a mountable folder (second) then search from that.
	for (NSString *type in typeOrder)
	{
		NSString *parent = [workspace parentOfFile: path
                                     matchingTypes: [NSSet setWithObject: type]];
		if (parent) return parent;
	}
	
	//Failing that, check what kind of volume the file is on
	NSString *volumePath = [workspace volumeForPath: path];
	NSString *volumeType = [workspace volumeTypeForPath: path];
	
	//If it's on a data CD volume or floppy volume, scan from the base folder of the volume
	if ([volumeType isEqualToString: dataCDVolumeType] || [workspace isFloppyVolumeAtPath: volumePath])
	{
		return volumePath;
	}
	//If it's on an audio CD, hunt around for a corresponding data CD volume and use that if found
	else if ([volumeType isEqualToString: audioCDVolumeType])
	{
		NSString *dataVolumePath = [workspace dataVolumeOfAudioCD: volumePath];
		if (dataVolumePath) return dataVolumePath;
	}
	
	//If we get this far, then treat the path as a regular file or folder and recommend against
	//searching subfolders (since the file heirarchy could be potentially huge.)
	if (shouldRecurse) *shouldRecurse = NO;
	BOOL isFolder;
	NSFileManager *manager = [NSFileManager defaultManager];
	[manager fileExistsAtPath: path isDirectory: &isFolder];
	
	
	//If the path is a folder, search it directly...
	if (isFolder) return path;
	
	//...otherwise search the path's parent folder.
	else return [path stringByDeletingLastPathComponent]; 
}


#pragma mark -
#pragma mark Filetype helper methods

+ (NSSet *) preferredMountPointTypes
{
	static NSSet *types = nil;
	if (!types) types = [[NSSet alloc] initWithObjects: BXGameboxType, BXMountableFolderType, nil];
	return types;
}

+ (NSSet *) separatelyMountedTypes
{
	static NSSet *types = nil;
	if (!types)
	{
		NSSet *imageTypes	= [BXFileTypes mountableImageTypes];
		NSSet *folderTypes	= [self preferredMountPointTypes];
		types = [[imageTypes setByAddingObjectsFromSet: folderTypes] retain];
	}
	return types;
}

+ (BOOL) isExecutable: (NSString *)path
{
	return [[NSWorkspace sharedWorkspace] file: path matchesTypes: [BXFileTypes executableTypes]];
}


#pragma mark -
#pragma mark Miscellaneous file and folder methods

- (IBAction) relaunch: (id)sender
{
	if ([self targetPath]) [self openFileAtPath: [self targetPath]];
}

- (IBAction) openInDOS: (id)sender
{
	if ([sender respondsToSelector: @selector(representedObject)])
        sender = [sender representedObject];
	
	NSString *path = nil;
	
	//NSString paths
	if ([sender isKindOfClass: [NSString class]])			path = sender;
	//NSURLs and BXDrives
	else if ([sender respondsToSelector: @selector(path)])	path = [sender path];
	//NSDictionaries with paths
	else if ([sender isKindOfClass: [NSDictionary class]])	path = [sender objectForKey: @"path"];	
	
	if (path)
        [self openFileAtPath: path];
}



#pragma mark -
#pragma mark Drive queuing

- (BOOL) allowsDriveChanges
{
    return !([[NSApp delegate] isStandaloneGameBundle]);
}

- (BOOL) shouldShadowDrive: (BXDrive *)drive
{
    //if (![[NSApp delegate] isStandaloneGameBundle])
    //    return NO;
    
    //Don't shadow if we're not running a gamebox.
    if (!self.isGamePackage)
        return NO;
    
    //Don't shadow read-only drives or drives that are located outside the gamebox.
    if (drive.isReadOnly || ![self driveIsBundled: drive])
        return NO;
    
    return YES;
}

- (NSString *) pathToCurrentState
{
    if (!self.isGamePackage)
        return nil;
    
    NSString *statePath = [[NSApp delegate] statesPathForGamePackage: self.gamePackage
                                                   creatingIfMissing: NO];
    
    return [statePath stringByAppendingPathComponent: @"Current.boxerstate"];
}

- (NSString *) shadowPathForDrive: (BXDrive *)drive
{
    if ([self shouldShadowDrive: drive])
    {
        NSString *statePath = self.pathToCurrentState;
        if (statePath)
        {
            NSString *driveName;
            //If the drive is identical to the gamebox itself (old-style gameboxes)
            //then map it to a different name.
            if ([drive.path isEqualToString: self.gamePackage.bundlePath])
                driveName = @"C.harddisk";
            //Otherwise, use the original filename of the gamebox.
            else
                driveName = drive.path.lastPathComponent;
            
            NSString *shadowPath = [statePath stringByAppendingPathComponent: driveName];
            
            return shadowPath;
        }
    }
    return nil;
}

- (NSArray *) allDrives
{
    NSMutableArray *allDrives = [NSMutableArray arrayWithCapacity: 10];
    NSArray *sortedLetters = [self.drives.allKeys sortedArrayUsingSelector: @selector(compare:)];
    for (NSString *letter in sortedLetters)
    {
        NSArray *queue = [self.drives objectForKey: letter];
        [allDrives addObjectsFromArray: queue];
    }
    return allDrives;
}

- (NSArray *) mountedDrives
{
    return self.emulator.mountedDrives;
}

+ (NSSet *) keyPathsForValuesAffectingAllDrives
{
    return [NSSet setWithObject: @"drives"];
}

+ (NSSet *) keyPathsForValuesAffectingMountedDrives
{
    return [NSSet setWithObject: @"emulator.mountedDrives"];
}

- (BOOL) driveIsMounted: (BXDrive *)drive
{
    return ([self.mountedDrives containsObject: drive]);
}

- (void) enqueueDrive: (BXDrive *)drive
{
    NSString *letter = drive.letter;
    NSAssert1(letter != nil, @"Drive %@ passed to enqueueDrive had no letter assigned.", drive);
    
    [self willChangeValueForKey: @"drives"];
    NSMutableArray *queue = [self.drives objectForKey: letter];
    if (!queue)
    {
        queue = [NSMutableArray arrayWithObject: drive];
        [_drives setObject: queue forKey: letter];
    }
    else if (![queue containsObject: drive])
    {
        [queue addObject: drive];
    }
    
    [self didChangeValueForKey: @"drives"];
}

- (void) dequeueDrive: (BXDrive *)drive
{
    //If the specified drive is currently being imported, then refuse to remove
    //it from the queue: we don't want it to disappear from the UI until we're
    //good and ready.
    //TODO: expand this to prevent dequeuing drives that are currently mounted
    //or that should not be removed for other reasons.
    if ([self activeImportOperationForDrive: drive]) return;
    
    NSString *letter = drive.letter;
    NSAssert1(letter != nil, @"Drive %@ passed to dequeueDrive had no letter assigned.", drive);
    
    [self willChangeValueForKey: @"drives"];
    [[self.drives objectForKey: letter] removeObject: drive];
    [self didChangeValueForKey: @"drives"];
    
}

- (void) replaceQueuedDrive: (BXDrive *)oldDrive
                  withDrive: (BXDrive *)newDrive
{
    NSString *letter = newDrive.letter;
    NSAssert1(letter != nil, @"Drive %@ passed to replaceQueuedDrive:withDrive: had no letter assigned.", newDrive);
    
    NSMutableArray *queue = [self.drives objectForKey: letter];
    NSUInteger oldDriveIndex = [queue indexOfObject: oldDrive];
    
    //If there was no queue to start with, or the old drive wasn't queued,
    //then just queue the new drive normally.
    if (!queue || oldDriveIndex == NSNotFound) [self enqueueDrive: newDrive];
    else
    {
        [self willChangeValueForKey: @"drives"];
        [queue removeObject: newDrive];
        [queue replaceObjectAtIndex: oldDriveIndex withObject: newDrive];
        [self didChangeValueForKey: @"drives"];
    }
}

- (BXDrive *) queuedDriveForPath: (NSString *)path
{
	for (BXDrive *drive in self.allDrives)
	{
		if ([drive representsPath: path]) return drive;
	}
	return nil;
}

- (NSUInteger) indexOfQueuedDrive: (BXDrive *)drive
{
    NSString *letter = drive.letter;
    if (!letter) return NSNotFound;
    
    NSArray *queue = [self.drives objectForKey: letter];
    return [queue indexOfObject: drive];
}

- (BXDrive *) siblingOfQueuedDrive: (BXDrive *)drive
                          atOffset: (NSInteger)offset
{
    NSString *letter = drive.letter;
    if (!letter) return nil;
    
    NSArray *queue = [self.drives objectForKey: letter];
    NSUInteger queueIndex = [queue indexOfObject: drive];
    if (queueIndex == NSNotFound) return nil;
    
    NSUInteger siblingIndex = (queueIndex + offset) % queue.count;
    return [queue objectAtIndex: siblingIndex];
}


#pragma mark -
#pragma mark Drive mounting

- (void) _mountQueuedSiblingsAtOffset: (NSInteger)offset
{
    for (BXDrive *currentDrive in [self mountedDrives])
    {
        BXDrive *siblingDrive = [self siblingOfQueuedDrive: currentDrive atOffset: offset];
        if (siblingDrive && ![siblingDrive isEqual: currentDrive])
        {
            NSError *mountError;
            [self mountDrive: siblingDrive
                    ifExists: BXDriveReplace
                     options: BXDefaultDriveMountOptions
                       error: &mountError];
            
            if (mountError)
            {
                [self presentError: mountError
                    modalForWindow: [self windowForSheet]
                          delegate: nil
                didPresentSelector: NULL
                       contextInfo: NULL];
                
                //Don't continue mounting if we encounter a problem
                break;
            }
        }
    }
}

- (IBAction) mountNextDrivesInQueues: (id)sender
{
    [self _mountQueuedSiblingsAtOffset: 1];
}

- (IBAction) mountPreviousDrivesInQueues: (id)sender
{
    [self _mountQueuedSiblingsAtOffset: -1];
}

- (BOOL) shouldUnmountDrives: (NSArray *)selectedDrives 
                usingOptions: (BXDriveMountOptions)options
                      sender: (id)sender
{
	//If the Option key was held down, bypass this check altogether and allow any drive to be unmounted
	NSUInteger optionKeyDown = ([NSApp currentEvent].modifierFlags & NSAlternateKeyMask) == NSAlternateKeyMask;
	if (optionKeyDown) return YES;

	NSMutableArray *drivesInUse = [[[NSMutableArray alloc] initWithCapacity: [selectedDrives count]] autorelease];
	for (BXDrive *drive in selectedDrives)
	{
        //If the drive is importing, refuse to unmount/dequeue it altogether.
        if ([self activeImportOperationForDrive: drive]) return NO;
        
        //If the drive isn't mounted anyway, then ignore it
        //(we may receive a mix of mounted and unmounted drives)
        if (![self driveIsMounted: drive]) continue;
        
        //Prevent locked drives from being removed altogether
		if (drive.isLocked) return NO;
		
		//If a program is running and the drive is in use, then warn about it
		if (!self.emulator.isAtPrompt && [self.emulator driveInUseAtLetter: drive.letter])
			[drivesInUse addObject: drive];
	}
	
	if ([drivesInUse count] > 0)
	{
		//Note that alert stays retained - it is released by the didEndSelector
		BXDrivesInUseAlert *alert = [[BXDrivesInUseAlert alloc] initWithDrives: drivesInUse forSession: self];
		
		NSWindow *sheetWindow;
		if (sender && [sender respondsToSelector: @selector(window)])
			sheetWindow = [sender window];
		else sheetWindow = [self windowForSheet]; 
		
        NSDictionary *contextInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                     selectedDrives, @"drives",
                                     [NSNumber numberWithInteger: options], @"options",
                                     nil];
        
		[alert beginSheetModalForWindow: sheetWindow
						  modalDelegate: self
						 didEndSelector: @selector(drivesInUseAlertDidEnd:returnCode:contextInfo:)
							contextInfo: [contextInfo retain]];

        [alert release];
        
		return NO;
	}
	return YES;
}

- (void) drivesInUseAlertDidEnd: (BXDrivesInUseAlert *)alert
					 returnCode: (NSInteger)returnCode
                    contextInfo: (NSDictionary *)contextInfo
{
	if (returnCode == NSAlertFirstButtonReturn)
    {
        NSArray *selectedDrives = [contextInfo objectForKey: @"drives"];
        BXDriveMountOptions options = [[contextInfo objectForKey: @"options"] unsignedIntegerValue];
        
        //It's OK to force removal here since we've already gotten permission
        //from the user to eject in-use drives.
        NSError *unmountError = nil;
        [self unmountDrives: selectedDrives
                    options: options | BXDriveForceUnmounting
                      error: &unmountError];
        
        if (unmountError)
        {
            [alert.window orderOut: self];
            [self presentError: unmountError
                modalForWindow: self.windowForSheet
                      delegate: nil
            didPresentSelector: NULL
                   contextInfo: NULL];
        }
    }
    //Release the context dictionary that was previously retained in the beginSheetModalForWindow: call.
	[contextInfo release];
}

- (BOOL) validateDrivePath: (NSString **)ioValue
                     error: (NSError **)outError
{
    NSString *drivePath = *ioValue;
    
    //A nil path was specified for some reason, don't continue but don't populate an error.
    //FIXME: should this be an assertion?
    if (!drivePath) return NO;
    
	NSFileManager *manager = [NSFileManager defaultManager];
    
    //Fully resolve the path to eliminate any symlinks, tildes and backtracking
	NSString *resolvedPath = [drivePath stringByStandardizingPath];
    
    BOOL isDir, exists = [manager fileExistsAtPath: resolvedPath isDirectory: &isDir];
    if (!exists)
    {
        if (outError)
        {
            NSDictionary *userInfo = [NSDictionary dictionaryWithObject: resolvedPath
                                                                 forKey: NSFilePathErrorKey];
            
            *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                            code: NSFileNoSuchFileError
                                        userInfo: userInfo];
        }
        return NO;
    }
                            
    //Check if the path represents any restricted folders.
    //(Only bother to do this for folders: we can assume disc images are not system folders.)
    if (isDir)
    {
        NSString *rootPath = NSOpenStepRootDirectory();
        if ([resolvedPath isEqualToString: rootPath])
        {
            if (outError)
            {
                *outError = [BXSessionCannotMountSystemFolderError errorWithPath: drivePath
                                                                        userInfo: nil];
            }
            return NO;
        }
        
        //Restrict all system library folders, but not the user's own library folder.
        NSArray *restrictedPaths = NSSearchPathForDirectoriesInDomains(NSAllLibrariesDirectory, NSAllDomainsMask & ~NSUserDomainMask, YES);
        for (NSString *testPath in restrictedPaths) if ([resolvedPath isRootedInPath: testPath])
        {
            if (outError)
            {
                *outError = [BXSessionCannotMountSystemFolderError errorWithPath: drivePath
                                                                        userInfo: nil];
            }
            return NO;
        }
    }
    return YES;
}

- (BOOL) shouldMountNewDriveForPath: (NSString *)path
{
	//If the file isn't already accessible from DOS, we should mount it
	BXEmulator *theEmulator = self.emulator;
	if (![theEmulator pathIsDOSAccessible: path]) return YES;
	
	//If it is accessible within another drive, but the path is of a type
	//that should get its own drive, then mount it as a new drive of its own.
	NSWorkspace *workspace	= [NSWorkspace sharedWorkspace];
	if ([workspace file: path matchesTypes: [self.class separatelyMountedTypes]]
	&& ![theEmulator pathIsMountedAsDrive: path])
		return YES;
	
	return NO;
}

- (BXDrive *) mountDriveForPath: (NSString *)path
                       ifExists: (BXDriveConflictBehaviour)conflictBehaviour
                        options: (BXDriveMountOptions)options
                          error: (NSError **)outError
{
	NSAssert1(self.isEmulating, @"mountDriveForPath:ifExists:options:error: called for %@ while emulator is not running.", path);
    
	//Choose an appropriate mount point and create the new drive for it
	NSString *mountPoint = [self.class preferredMountPointForPath: path];
    
    //Make sure the mount point exists and is suitable to use
    if (![self validateDrivePath: &mountPoint error: outError]) return nil;
    
    
    //Check if there's already a drive in the queue that matches this mount point:
    //if so, mount it if necessary and return that
    BXDrive *existingDrive = [self queuedDriveForPath: mountPoint];
    if (existingDrive)
    {
        existingDrive = [self mountDrive: existingDrive
                                ifExists: conflictBehaviour
                                 options: options
                                   error: outError];
        return existingDrive;
    }
    //Otherwise, create a new drive for the mount
    else
    {
        BXDrive *drive = [BXDrive driveFromPath: mountPoint atLetter: nil];
        return [self mountDrive: drive
                       ifExists: conflictBehaviour
                        options: options
                          error: outError];
    }
}

- (BOOL) openFileAtPath: (NSString *)path
{
	if (!self.emulator.isInitialized || self.emulator.isRunningProcess) return NO;
    
	//Get the path to the file in the DOS filesystem
	NSString *dosPath = [self.emulator DOSPathForPath: path];
	if (!dosPath || ![self.emulator DOSPathExists: dosPath]) return NO;
	
	//Unpause the emulation if it's paused
	[self resume: self];
	
	if ([self.class isExecutable: path])
	{
		//If an executable was specified, execute it
        self.lastLaunchedProgramPath = path;
		[self.emulator executeProgramAtPath: dosPath changingDirectory: YES];
	}
	else
	{
		//Otherwise, just switch to the specified path
		[self.emulator changeWorkingDirectoryToPath: dosPath];
	}
	return YES;
}


//Mount drives for all CD-ROMs that are currently mounted in OS X
//(as long as they're not already mounted in DOS, that is.)
//Returns YES if any drives were mounted, NO otherwise.
- (NSArray *) mountCDVolumesWithError: (NSError **)outError
{
	BXEmulator *theEmulator = self.emulator;
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSArray *volumes = [workspace mountedVolumesOfType: dataCDVolumeType includingHidden: NO];
	
	//If there were no data CD volumes, then check for audio CD volumes and mount them instead
	//(We avoid doing this if there were data CD volumes, since the audio CDs will then be used
	//as 'shadow' audio volumes for those data CDs.)
	if (![volumes count])
		volumes = [workspace mountedVolumesOfType: audioCDVolumeType includingHidden: NO];
    
    NSMutableArray *mountedDrives = [NSMutableArray arrayWithCapacity: 10];
	for (NSString *volume in volumes)
	{
		if (![theEmulator pathIsMountedAsDrive: volume])
		{
			BXDrive *drive = [BXDrive CDROMFromPath: volume
                                           atLetter: nil];
            
            drive = [self mountDrive: drive 
                            ifExists: BXDriveQueue
                             options: BXSystemVolumeMountOptions
                               error: outError];
            
            if (drive) [mountedDrives addObject: drive];
            
            //If there was any error in mounting a drive,
            //then bail out and don't attempt to mount further drives
            //TODO: check the actual error to determine whether we can
            //continue after failure.
            else return nil;
		}
	}
	return mountedDrives;
}

//Mount drives for all floppy-sized FAT volumes that are currently mounted in OS X.
//Returns YES if any drives were mounted, NO otherwise.
- (NSArray *) mountFloppyVolumesWithError: (NSError **)outError
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSArray *volumePaths = [workspace mountedVolumesOfType: FATVolumeType includingHidden: NO];
	BXEmulator *theEmulator = self.emulator;
    
    NSMutableArray *mountedDrives = [NSMutableArray arrayWithCapacity: 10];
	for (NSString *volumePath in volumePaths)
	{
		if (![theEmulator pathIsMountedAsDrive: volumePath] && [workspace isFloppySizedVolumeAtPath: volumePath])
		{
			BXDrive *drive = [BXDrive floppyDriveFromPath: volumePath atLetter: nil];
            
            drive = [self mountDrive: drive
                            ifExists: BXDriveQueue
                             options: BXSystemVolumeMountOptions
                               error: outError];
            
            if (drive) [mountedDrives addObject: drive];
            
            //If there was any error in mounting a drive,
            //then bail out and don't attempt to mount further drives
            //TODO: check the actual error to determine whether we can
            //continue after failure.
            else return nil;
		}
	}
	return mountedDrives;
}

- (BXDrive *) mountToolkitDriveWithError: (NSError **)outError
{
	BXEmulator *theEmulator = self.emulator;

	NSString *toolkitDriveLetter	= [[NSUserDefaults standardUserDefaults] stringForKey: @"toolkitDriveLetter"];
	NSString *toolkitFiles			= [[NSBundle mainBundle] pathForResource: @"DOS Toolkit" ofType: nil];
    
	BXDrive *toolkitDrive = [BXDrive hardDriveFromPath: toolkitFiles atLetter: toolkitDriveLetter];
    toolkitDrive.title = NSLocalizedString(@"DOS Toolkit", @"The display title for Boxer’s toolkit drive.");
	
	//Hide and lock the toolkit drive so that it cannot be ejected and will not appear in the drive inspector,
    //and make it read-only with 0 bytes free so that it will not appear as a valid installation target to DOS games.
	toolkitDrive.locked = YES;
	toolkitDrive.readOnly = YES;
	toolkitDrive.hidden = YES;
	toolkitDrive.freeSpace = 0;
    
	toolkitDrive = [self mountDrive: toolkitDrive
                           ifExists: BXDriveReplace
                            options: BXBuiltinDriveMountOptions
                              error: outError];
	
	//Point DOS to the correct paths if we've mounted the toolkit drive successfully
	//TODO: we should treat this as an error if it didn't mount!
	if (toolkitDrive)
	{
		//TODO: the DOS path should include the root folder of every drive, not just Y and Z.
        //We should also have a proper API for adding to the DOS path, rather than overriding
        //it completely like this.
		NSString *dosPath	= [NSString stringWithFormat: @"%1$@:\\;%1$@:\\UTILS;Z:\\", toolkitDrive.letter];
		NSString *ultraDir	= [NSString stringWithFormat: @"%@:\\ULTRASND", toolkitDrive.letter];
		NSString *utilsDir	= [NSString stringWithFormat: @"%@:\\UTILS", toolkitDrive.letter];
		
		[theEmulator setVariable: @"path"		to: dosPath		encoding: BXDirectStringEncoding];
		[theEmulator setVariable: @"boxerutils"	to: utilsDir	encoding: BXDirectStringEncoding];
		[theEmulator setVariable: @"ultradir"	to: ultraDir	encoding: BXDirectStringEncoding];
	}
    return toolkitDrive;
}

- (BXDrive *) mountTempDriveWithError: (NSError **)outError
{
	BXEmulator *theEmulator = self.emulator;

	//Mount a temporary folder at the appropriate drive
	NSFileManager *manager		= [NSFileManager defaultManager];
	NSString *tempDriveLetter	= [[NSUserDefaults standardUserDefaults] stringForKey: @"temporaryDriveLetter"];
	NSString *tempDrivePath		= [manager createTemporaryDirectoryWithPrefix: @"Boxer" error: outError];
	
	if (tempDrivePath)
	{
		self.temporaryFolderPath = tempDrivePath;
		
		BXDrive *tempDrive = [BXDrive hardDriveFromPath: tempDrivePath atLetter: tempDriveLetter];
        tempDrive.title = NSLocalizedString(@"Temporary Files", @"The display title for Boxer’s temp drive.");
        
        //Hide and lock the temp drive so that it cannot be ejected and will not appear in the drive inspector.
		tempDrive.locked = YES;
		tempDrive.hidden = YES;
		
        //Replace any existing drive at the same letter, and don't show any notifications
		tempDrive = [self mountDrive: tempDrive
                            ifExists: BXDriveReplace
                             options: BXBuiltinDriveMountOptions
                               error: outError];
		
		if (tempDrive)
		{
			NSString *tempPath = [NSString stringWithFormat: @"%@:\\", tempDrive.letter];
			[theEmulator setVariable: @"temp"	to: tempPath	encoding: BXDirectStringEncoding];
			[theEmulator setVariable: @"tmp"	to: tempPath	encoding: BXDirectStringEncoding];
		}
        //If we couldn't mount the temporary folder for some reason, then delete it
        else
        {
            [manager removeItemAtPath: tempDrivePath error: nil];
        }
        
        return tempDrive;
	}	
    return nil;
}

- (BXDrive *) mountDummyCDROMWithError: (NSError **)outError
{
    //First, check if we already have a CD drive mounted:
    //If so, we don't need a dummy one.
    for (BXDrive *drive in self.mountedDrives)
    {
        if (drive.type == BXDriveCDROM) return drive;
    }
    
    
    NSString *dummyImage    = [[NSBundle mainBundle] pathForResource: @"DummyCD" ofType: @"iso"];
	BXDrive *dummyDrive     = [BXDrive CDROMFromPath: dummyImage atLetter: nil];
    
    dummyDrive.title = NSLocalizedString(@"Dummy CD",
                                         @"The display title for Boxer’s dummy CD-ROM drive.");
	
	dummyDrive = [self mountDrive: dummyDrive
                         ifExists: BXDriveQueue
                          options: BXDriveKeepWithSameType
                            error: outError];
	
    return dummyDrive;
}

- (NSString *) preferredLetterForDrive: (BXDrive *)drive
                               options: (BXDriveMountOptions)options
{
    //If we want to keep this drive with others of its ilk,
    //then use the letter of the first drive of that type.
    if ((options & BXDriveKeepWithSameType) && (drive.type == BXDriveCDROM || drive.type == BXDriveFloppyDisk))
    {
        for (BXDrive *knownDrive in self.allDrives)
        {
            if (knownDrive.type == drive.type)
                return knownDrive.letter;
        }
    }
    
    //Otherwise, pick the next suitable drive letter for that type
    //that isn't already queued.
    NSArray *letters;
	if      (drive.isFloppy)	letters = [BXEmulator floppyDriveLetters];
	else if (drive.isCDROM)     letters = [BXEmulator CDROMDriveLetters];
	else                        letters = [BXEmulator hardDriveLetters];
    
	for (NSString *letter in letters)
    {
        if (![[self.drives objectForKey: letter] count]) return letter;
    }
    
    //Uh-oh, looks like all suitable drive letters are taken! Bummer.
    return nil;
}

- (BXDrive *) mountDrive: (BXDrive *)drive
                ifExists: (BXDriveConflictBehaviour)conflictBehaviour
                 options: (BXDriveMountOptions)options
                   error: (NSError **)outError
{
    if (outError) *outError = nil;
    
    //If this drive is already mounted, don't bother retrying.
    if ([self driveIsMounted: drive]) return drive;
    
    //TODO: return an operation-disabled error message also
    if (!self.allowsDriveChanges && _hasConfigured)
        return nil;
    
    //Sanity check: BXDriveReplaceWithSiblingFromQueue is not applicable
    //when mounting a new drive, so ensure it is not set.
    options &= ~BXDriveReplaceWithSiblingFromQueue;
    
    //Sanity check: BXDriveReassign cannot be used along with
    //BXDriveKeepWithSameType, so clear that flag.
    if (conflictBehaviour == BXDriveReassign)
        options &= ~BXDriveKeepWithSameType;
    
    //If the drive doesn't have a specific drive letter,
    //determine one now based on the specified options.
    if (!drive.letter)
    {
        drive.letter = [self preferredLetterForDrive: drive
                                             options: options];
    }
    
    //Allow the game profile to override the drive volume label if needed.
	NSString *customLabel = [self.gameProfile volumeLabelForDrive: drive];
	if (customLabel) drive.volumeLabel = customLabel;
    
    BXDrive *driveToMount = drive;
    BXDrive *fallbackDrive = nil;
    
	if (options & BXDriveUseBackingImageIfAvailable)
    {
        //Check if the specified path has a DOSBox-compatible image backing it:
        //if so then try to mount that instead, and assign the current path as an alias.
        NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
        NSString *sourceImagePath = [workspace sourceImageForVolume: drive.path];
        
        if (sourceImagePath && [workspace file: sourceImagePath matchesTypes: [BXFileTypes mountableImageTypes]])
        {
            //Check if we already have another drive representing the source path
            //at the requested drive letter: if so, then just add the path as an
            //alias to that existing drive, and mount that drive instead
            //(assuming it isn't already.)
            //TODO: should we handle this case upstairs in mountDriveForPath:?
            BXDrive *existingDrive = [self queuedDriveForPath: sourceImagePath];
            if (![existingDrive isEqual: drive] && [existingDrive.letter isEqual: drive.letter])
            {   
                [existingDrive.pathAliases addObject: drive.path];
                if ([self driveIsMounted: existingDrive])
                {
                    return existingDrive;
                }
                else
                {
                    driveToMount = existingDrive;
                }
            }
            //Otherwise, make a new drive using the image, and mount that instead.
            else
            {
                BXDrive *imageDrive = [BXDrive driveFromPath: sourceImagePath
                                                    atLetter: drive.letter
                                                    withType: drive.type];
                
                imageDrive.readOnly = drive.readOnly;
                imageDrive.hidden = drive.isHidden;
                imageDrive.locked = drive.isLocked;
                [imageDrive.pathAliases addObject: drive.path];
                
                driveToMount = imageDrive;
                fallbackDrive = drive;
            }
        }
    }
    
    if (options & BXDriveUseShadowingIfAvailable)
    {
        //Check if we should shadow this drive.
        NSString *shadowPath = [self shadowPathForDrive: drive];
        if (shadowPath)
        {
            drive.shadowPath = shadowPath;
        }
    }
    
    BXDrive *mountedDrive = nil;
    BXDrive *replacedDrive = nil;
    BOOL replacedDriveWasCurrent = NO;
    
    do
    {
        NSError *mountError = nil;
        mountedDrive = [self.emulator mountDrive: driveToMount error: &mountError];
    
        //If mounting fails, check what the failure was and try to recover.
        if (!mountedDrive)
        {
            NSInteger errCode = mountError.code;
            BOOL isDOSFilesystemError = [mountError.domain isEqualToString: BXDOSFilesystemErrorDomain];
            
            //The drive letter was already taken: decide what to do based on our conflict behaviour.
            if (isDOSFilesystemError && errCode == BXDOSFilesystemDriveLetterOccupied)
            {
                switch (conflictBehaviour)
                {
                    //Pick a new drive letter and try again.
                    case BXDriveReassign:
                        {
                            NSString *newLetter = [self preferredLetterForDrive: driveToMount
                                                                        options: options];
                            driveToMount.letter = newLetter;
                        }
                        break;
                    
                    //Try to unmount the existing drive and try again.
                    case BXDriveReplace:
                        {
                            NSError *unmountError = nil;
                            replacedDrive           = [self.emulator driveAtLetter: driveToMount.letter];
                            replacedDriveWasCurrent = [self.emulator.currentDrive isEqual: replacedDrive];
                            
                            BOOL unmounted = [self unmountDrive: replacedDrive
                                                        options: options
                                                          error: &unmountError];
                            
                            //If we couldn't unmount the drive we're trying to replace,
                            //then queue up the desired drive anyway and then give up.
                            if (!unmounted)
                            {
                                [self enqueueDrive: driveToMount];
                                if (outError) *outError = unmountError;
                                return nil;
                            }
                        }
                        break;
                        
                    //Add the conflicting drive into a queue alongside the existing drive,
                    //and give up on mounting for now.
                    case BXDriveQueue:
                    default:
                        {
                            [self enqueueDrive: driveToMount];
                            return nil;
                        }
                }
            }
            
            //Disc image couldn't be recognised: if we have a fallback volume,
            //switch to that instead and continue mounting.
            //(If we don't, we'll continue bailing out.)
            else if (isDOSFilesystemError && errCode == BXDOSFilesystemInvalidImage && fallbackDrive)
            {
                driveToMount = fallbackDrive;
                fallbackDrive = nil;
            }
            
            //Bail out completely after any other error - once we put back
            //any drive we tried to replace.
            else
            {
                //Tweak: if we failed because we couldn't read the source file/volume,
                //check if this could be because of an import operation.
                //If so, rephrase the error with a more helpful description.
                if (isDOSFilesystemError && errCode == BXDOSFilesystemCouldNotReadDrive &&
                    [[[self activeImportOperationForDrive: driveToMount] class] driveUnavailableDuringImport])
                {
                    NSString *descriptionFormat = NSLocalizedString(@"The drive “%1$@” is unavailable while it is being imported.",
                                                                    @"Error shown when a drive cannot be mounted because it is busy being imported.");
                    
                    NSString *description = [NSString stringWithFormat: descriptionFormat, driveToMount.title];
                    NSString *suggestion = NSLocalizedString(@"You can use the drive once the import has completed or been cancelled.", @"Recovery suggestion shown when a drive cannot be mounted because it is busy being imported.");
                    
                    
                    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                              description,  NSLocalizedDescriptionKey,
                                              suggestion,   NSLocalizedRecoverySuggestionErrorKey,
                                              mountError,   NSUnderlyingErrorKey,
                                              driveToMount, BXDOSFilesystemErrorDriveKey,
                                              nil];
                    
                    mountError = [NSError errorWithDomain: mountError.domain
                                                     code: mountError.code
                                                 userInfo: userInfo];
                }
                
                if (replacedDrive)
                {
                    [self.emulator mountDrive: replacedDrive error: nil];
                    
                    if (replacedDriveWasCurrent && self.emulator.isAtPrompt)
                    {
                        [self.emulator changeToDriveLetter: replacedDrive.letter];
                    }
                }
                if (outError) *outError = mountError;
                return nil;
            }
        }
    }
    while (!mountedDrive);
    
    //If we got this far then we have successfully mounted a drive!
    //Post a notification about it if appropriate.
    if (options & BXDriveShowNotifications)
    {
        //If we replaced an existing drive then show a slightly different notification
        if (replacedDrive)
        {
            [[BXBezelController controller] showDriveSwappedBezelFromDrive: replacedDrive
                                                                   toDrive: mountedDrive];
        }
        else
        {
            [[BXBezelController controller] showDriveAddedBezelForDrive: mountedDrive];
        }
    }
    
    //If we replaced DOS's current drive in the course of ejecting, then switch
    //to the new drive.
    //TODO: make it so that we don't switch away from the drive in the first place.
    if (replacedDrive && replacedDriveWasCurrent && self.emulator.isAtPrompt)
    {
        [self.emulator changeToDriveLetter: mountedDrive.letter];
    }
    
    return mountedDrive;
}


- (BOOL) unmountDrive: (BXDrive *)drive
              options: (BXDriveMountOptions)options
                error: (NSError **)outError
{
    //TODO: populate an operation-disabled error message.
    if (!self.allowsDriveChanges && _hasConfigured)
        return NO;
    
    if ([self driveIsMounted: drive])
    {
        BOOL force = NO;
        if      (options & BXDriveForceUnmounting) force = YES;
        else if (options & BXDriveForceUnmountingIfRemovable &&
                (drive.type == BXDriveCDROM || drive.type == BXDriveFloppyDisk)) force = YES;
        
        //If requested, try to find another drive in the same queue
        //to replace the unmounted one with.
        BXDrive *replacementDrive = nil;
        BOOL driveWasCurrent = NO;
        if (options & BXDriveReplaceWithSiblingFromQueue)
        {
            replacementDrive = [self siblingOfQueuedDrive: drive atOffset: 1];
            if ([replacementDrive isEqual: drive]) replacementDrive = nil;
            driveWasCurrent = [self.emulator.currentDrive isEqual: drive];
        }
        
        
        BOOL unmounted = [self.emulator unmountDrive: drive
                                               force: force
                                               error: outError];
        
        if (unmounted)
        {
            if (replacementDrive)
            {
                replacementDrive = [self mountDrive: replacementDrive
                                           ifExists: BXDriveQueue
                                            options: BXReplaceWithSiblingDriveMountOptions
                                              error: nil];
                
                //Remember to change back to the same drive once we're done unmounting.
                if (replacementDrive && driveWasCurrent && self.emulator.isAtPrompt)
                {
                    [self.emulator changeToDriveLetter: replacementDrive.letter];
                }
            }
            
            if (options & BXDriveShowNotifications)
            {
                //Show a slightly different notification if we swapped in another drive.
                if (replacementDrive)
                {
                    [[BXBezelController controller] showDriveSwappedBezelFromDrive: drive
                                                                           toDrive: replacementDrive];
                }
                else
                {
                    [[BXBezelController controller] showDriveRemovedBezelForDrive: drive];
                }
            }
            
            if (options & BXDriveRemoveExistingFromQueue)
            {
                [self dequeueDrive: drive];
            }
            
        }
        return unmounted;
    }
    //If the drive isn't mounted, but we requested that it be removed from the queue
    //after unmounting anyway, then do that now.
    else
    {
        if (options & BXDriveRemoveExistingFromQueue)
            [self dequeueDrive: drive];
        return NO;
    }
}


- (BOOL) unmountDrives: (NSArray *)drivesToUnmount
               options: (BXDriveMountOptions)options
                 error: (NSError **)outError
{
	BOOL succeeded = NO;
	for (BXDrive *drive in drivesToUnmount)
	{
        if ([self unmountDrive: drive options: options error: outError]) succeeded = YES;
        //If any of the drive unmounts failed, don't continue further
        else return NO;
	}
	return succeeded;
}


#pragma mark -
#pragma mark Managing executables

+ (NSSet *) keyPathsForValuesAffectingPrincipalDrive
{
	return [NSSet setWithObject: @"executables"];
}

- (BXDrive *) principalDrive
{
	//Prioritise drive C, if it's available and has executables on it
	if ([[self.executables objectForKey: @"C"] count])
        return [self.emulator driveAtLetter: @"C"];
    
	//Otherwise through all the mounted drives and return the first one that we have programs for.
    NSArray *sortedLetters = [self.executables.allKeys sortedArrayUsingSelector: @selector(compare:)];
	for (NSString *letter in sortedLetters)
	{
		if ([[self.executables objectForKey: letter] count]) return [self.emulator driveAtLetter: letter];
	}
	return nil;
}

+ (NSSet *) keyPathsForValuesAffectingProgramPathsOnPrincipalDrive
{
	return [NSSet setWithObjects: @"executables", nil];
}

- (NSArray *) programPathsOnPrincipalDrive
{
	NSString *driveLetter = self.principalDrive.letter;
	if (driveLetter) return [self.executables objectForKey: driveLetter];
	else return nil;
}


#pragma mark -
#pragma mark OS X filesystem notifications

//Register ourselves as an observer for filesystem notifications
- (void) _registerForFilesystemNotifications
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSNotificationCenter *center = [workspace notificationCenter];
	
	[center addObserver: self
			   selector: @selector(volumeDidMount:)
				   name: NSWorkspaceDidMountNotification
				 object: workspace];
	
	[center addObserver: self
			   selector: @selector(volumeWillUnmount:)
				   name: NSWorkspaceWillUnmountNotification
				 object: workspace];

	[center addObserver: self
			   selector: @selector(volumeWillUnmount:)
				   name: NSWorkspaceDidUnmountNotification
				 object: workspace];
	
	[center addObserver: self
			   selector: @selector(filesystemDidChange:)
				   name: UKFileWatcherWriteNotification
				 object: self.watcher];
	
	[center addObserver: self
			   selector: @selector(filesystemDidChange:)
				   name: UKFileWatcherDeleteNotification
				 object: self.watcher];
	
	[center addObserver: self
			   selector: @selector(filesystemDidChange:)
				   name: UKFileWatcherRenameNotification
				 object: self.watcher];
	
	[center addObserver: self
			   selector: @selector(filesystemDidChange:)
				   name: UKFileWatcherAccessRevocationNotification
				 object: self.watcher];
}

- (void) _deregisterForFilesystemNotifications
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSNotificationCenter *center = [workspace notificationCenter];

	[center removeObserver: self name: NSWorkspaceDidMountNotification		object: workspace];
	[center removeObserver: self name: NSWorkspaceDidUnmountNotification	object: workspace];
	[center removeObserver: self name: NSWorkspaceWillUnmountNotification	object: workspace];
	[center removeObserver: self name: UKFileWatcherWriteNotification		object: self.watcher];
	[center removeObserver: self name: UKFileWatcherDeleteNotification		object: self.watcher];
	[center removeObserver: self name: UKFileWatcherRenameNotification		object: self.watcher];
	[center removeObserver: self name: UKFileWatcherAccessRevocationNotification object: self.watcher];
}

- (void) volumeDidMount: (NSNotification *)theNotification
{
	//We decide what to do with audio CD volumes based on whether they have a corresponding
	//data volume. Unfortunately, the volumes are reported as soon as they are mounted, so
	//often the audio volume will send a mount notification before its data volume exists.
	
	//To work around this, we add a slight delay before we process the volume mount notification,
    //to allow other volumes time to finish mounting.
    
    [self performSelector: @selector(_handleVolumeDidMount:)
               withObject: theNotification
               afterDelay: BXVolumeMountDelay];
}

- (void) _handleVolumeDidMount: (NSNotification *)theNotification
{
	//Don't respond to mounts if the emulator isn't actually running
	if (!self.isEmulating) return;
	
	//Ignore mounts if we currently have the mount panel open;
	//we assume that the user will want to handle the new volume manually.
	NSWindow *attachedSheet = self.windowForSheet.attachedSheet;
	if ([attachedSheet isMemberOfClass: [NSOpenPanel class]]) return;
	
	NSArray *automountedTypes = [NSArray arrayWithObjects:
								 dataCDVolumeType,
								 audioCDVolumeType,
								 FATVolumeType,
								 nil];
	
	NSWorkspace *workspace	= [NSWorkspace sharedWorkspace];
	NSString *volumePath	= [theNotification.userInfo objectForKey: @"NSDevicePath"];
	NSString *volumeType	= [workspace volumeTypeForPath: volumePath];
    
    //Ignore the mount if it's a hidden volume.
    if (![workspace volumeIsVisibleAtPath: volumePath]) return;
	
    //Ignore mount if we're scanning this volume for executables:
    //this indicates that the scan is responsible for the mount,
    //and it's not a user-mounted drive.
    for (BXExecutableScan *scan in self.scanQueue.operations)
    {
        if ([scan.mountedVolumePath isEqualToString: volumePath]) return;
    }
    
	//Only mount volumes that are of an appropriate type
	if (![automountedTypes containsObject: volumeType]) return;
	
	//Only mount CD audio volumes if they have no corresponding data volume
	//(Otherwise, we mount the data volume instead and shadow it with the audio CD's tracks)
	if ([volumeType isEqualToString: audioCDVolumeType] && [workspace dataVolumeOfAudioCD: volumePath]) return;
	
	//Only mount FAT volumes that are floppy-sized
	if ([volumeType isEqualToString: FATVolumeType] && ![workspace isFloppySizedVolumeAtPath: volumePath]) return;
	
	NSString *mountPoint = [self.class preferredMountPointForPath: volumePath];
    
	if ([self.emulator pathIsMountedAsDrive: mountPoint]) return;
	
    //If an existing drive corresponds to this volume already,
    //then mount it if it's not already
    BXDrive *existingDrive  = [self queuedDriveForPath: mountPoint];
    if (existingDrive)
    {
        [self mountDrive: existingDrive
                ifExists: BXDriveReplace
                 options: BXDefaultDriveMountOptions
                   error: nil];
    }
	//Alright, if we got this far then it's ok to mount a new drive for it
    else
    {
        BXDrive *drive = [BXDrive driveFromPath: mountPoint atLetter: nil];
        
        //Ignore errors when automounting volumes, since these
        //are not directly triggered by the user.
        [self mountDrive: drive
                ifExists: BXDriveReplace
                 options: BXDefaultDriveMountOptions
                   error: nil];
    }
}

//Implementation note: this handler is called in response to NSVolumeWillUnmountNotifications,
//so that we can remove any of our own file locks that would prevent OS X from continuing to unmount.
//However, it's also called again in response to NSVolumeDidUnmountNotifications, so that we can catch
//unmounts that happened too suddenly to send a WillUnmount notification (which can happen when
//pulling out a USB drive or mechanically ejecting a disk)
- (void) volumeWillUnmount: (NSNotification *)theNotification
{
	//Ignore unmount events if the emulator isn't actually running
	if (!self.isEmulating) return;
	
	NSString *volumePath = [theNotification.userInfo objectForKey: @"NSDevicePath"];
	//Should already be standardized, but still
	NSString *standardizedPath = volumePath.stringByStandardizingPath;
	
    //Scan our drive list to see which drives would be affected by this volume
    //becoming unavailable.
	for (BXDrive *drive in self.allDrives)
	{
        //TODO: refactor this so that we can move the decision off to BXDrive itself
		//(We can't use representsPath: because that includes path aliases too, and we
        //don't want to eject backing-image drives inadvertently.)
		if ([drive.path isEqualToString: standardizedPath] || [drive.mountPoint isEqualToString: standardizedPath])
		{
            //Drive import processes may unmount a volume themselves in the course
            //of importing it: in which case we want to leave the drive in place.
            //(TODO: check that this is still the desired behaviour, now that we
            //have implemented drive queues.)
            if ([[[self activeImportOperationForDrive: drive] class] driveUnavailableDuringImport]) continue;
            
            //If the drive is mounted, then unmount it now and remove it from the drive list.
            if ([self driveIsMounted: drive])
            {
                [self unmountDrive: drive
                           options: BXVolumeUnmountingDriveUnmountOptions
                             error: nil];
            }
            //If the drive is not mounted, then just remove it from the drive list.
            else
            {
                [self dequeueDrive: drive];
            }
		}
		else
		{
			[drive.pathAliases removeObject: standardizedPath];
		}
	}
}

- (void) filesystemDidChange: (NSNotification *)theNotification
{
	NSString *path = [theNotification.userInfo objectForKey: @"path"];
	if ([self.emulator pathIsDOSAccessible: path])
        [self.emulator refreshMountedDrives];
	
	//Also check if the file was inside our gamebox - if so, flush the gamebox's caches
	BXPackage *package = self.gamePackage;
	if (package && [path hasPrefix: package.gamePath])
        [package refresh];
}


#pragma mark -
#pragma mark Emulator delegate methods

- (void) emulatorDidMountDrive: (NSNotification *)theNotification
{	
	BXDrive *drive = [theNotification.userInfo objectForKey: @"drive"];
    
    //Flag the drive as being mounted
    drive.mounted = YES;
    
    //Add the drive to our set of known drives
    [self enqueueDrive: drive];
	
	if (!drive.isInternal)
	{
		NSString *drivePath = drive.path;
	
		[self _startTrackingChangesAtPath: drivePath];
        if (drive.shadowPath)
            [self _startTrackingChangesAtPath: drive.shadowPath];
		
		//If this drive is part of the gamebox, scan it for executables
        //to display in the program panel
        if ([self driveIsBundled: drive])
		{
			[self executableScanForDrive: drive startImmediately: YES];
		}
	}
}

- (void) emulatorDidUnmountDrive: (NSNotification *)theNotification
{
	BXDrive *drive = [theNotification.userInfo objectForKey: @"drive"];
	
    //Flag the drive as no longer being mounted
    drive.mounted = NO;
    
    //Stop scanning for executables on the drive
    [self cancelExecutableScanForDrive: drive];
    
	if (!drive.isInternal)
	{
		NSString *path = drive.path;
		//Stop tracking for changes on the drive, if there are no other drives mapping to that path either.
		if (![self.emulator pathIsDOSAccessible: path])
            [self _stopTrackingChangesAtPath: path];
        
        if (drive.shadowPath)
            [self _stopTrackingChangesAtPath: drive.shadowPath];
	}
	
    //Remove the cached executable list when the drive is unmounted
	if ([self.executables objectForKey: drive.letter])
	{
		[self willChangeValueForKey: @"executables"];
		[_executables removeObjectForKey: drive.letter];
		[self didChangeValueForKey: @"executables"];
	}
}

//Pick up on the creation of new executables
- (void) emulatorDidCreateFile: (NSNotification *)notification
{
	BXDrive *drive = [notification.userInfo objectForKey: @"drive"];
	NSString *path = [notification.userInfo objectForKey: @"path"];
	
	//The drive is in our executables cache: check if the created file path was an executable
	//(If so, add it to the executables cache) 
	NSMutableArray *driveExecutables = [self.executables mutableArrayValueForKey: drive.letter];
	if (driveExecutables && ![driveExecutables containsObject: path])
	{
		NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
        
		if ([workspace isCompatibleExecutableAtPath: path error: nil])
		{
			[self willChangeValueForKey: @"executables"];
			[driveExecutables addObject: path];
			[self didChangeValueForKey: @"executables"];
		}
	}
}

//Pick up on the deletion of executables
- (void) emulatorDidRemoveFile: (NSNotification *)notification
{
	BXDrive *drive = [notification.userInfo objectForKey: @"drive"];
	NSString *path = [notification.userInfo objectForKey: @"path"];
	
	//The drive is in our executables cache: remove any reference to the deleted file
	NSMutableArray *driveExecutables = [self.executables objectForKey: drive.letter];
	if (driveExecutables && [driveExecutables containsObject: path])
	{
		[self willChangeValueForKey: @"executables"];
		[driveExecutables removeObject: path];
		[self didChangeValueForKey: @"executables"];
	}
}

- (BOOL) emulator: (BXEmulator *)emulator shouldShowFileWithName: (NSString *)fileName
{
	//Permit . and .. to be shown
	if ([fileName isEqualToString: @"."] || [fileName isEqualToString: @".."]) return YES;
	
	//Hide all hidden UNIX files
	//CHECK: will this ever hide valid DOS files?
	if ([fileName hasPrefix: @"."]) return NO;
	
	//Hide OSX and Boxer metadata files
	if ([[self.class hiddenFilenamePatterns] containsObject: fileName]) return NO;
    
	return YES;
}

- (BOOL) emulator: (BXEmulator *)emulator shouldAllowWriteAccessToPath: (NSString *)filePath onDrive: (BXDrive *)drive
{
	//Don't allow write access to files on drives marked as read-only
	if (drive.isReadOnly) return NO;
    
	//Don't allow write access to files inside Boxer's application bundle
    //Disabled for now, because:
    //1. our internal drives are flagged as read-only anyway, and
    //2. standalone game bundles have all the game files inside the application,
    //and so need to allow write access.
    /*
	filePath = filePath.stringByStandardizingPath;
	NSString *boxerPath = [[NSBundle mainBundle] bundlePath];
	if ([filePath isRootedInPath: boxerPath]) return NO;
	*/
	//TODO: don't allow write access to files in system directories
	
	//Let other files go through unmolested
	return YES;
}

- (BOOL) emulator: (BXEmulator *)theEmulator shouldMountDriveFromShell: (NSString *)drivePath
{
    //TODO: show an error message
    if (!self.allowsDriveChanges && _hasConfigured)
        return NO;
    
    NSError *validationError = nil;
    BOOL shouldMount = [self validateDrivePath: &drivePath error: &validationError];
    
    if (validationError)
    {
        [self presentError: validationError
            modalForWindow: self.windowForSheet
                  delegate: nil
        didPresentSelector: NULL
               contextInfo: NULL];
    }
    return shouldMount;
}


#pragma mark -
#pragma mark Drive executable scanning

- (BXExecutableScan *) executableScanForDrive: (BXDrive *)drive
                             startImmediately: (BOOL)start
{
    NSString *scanPath = drive.path;
    //Don't scan non-physical drives
    if (!scanPath) return nil;
    
    BXExecutableScan *scan = [BXExecutableScan scanWithBasePath: scanPath];
    scan.delegate = self;
    scan.didFinishSelector = @selector(executableScanDidFinish:);
    scan.contextInfo = drive;
    
    if (start)
    {
        for (BXExecutableScan *otherScan in self.scanQueue.operations)
        {
            //Ignore completed scans
            if (otherScan.isFinished) continue;

            //If a scan for this drive is already in progress and hasn't been cancelled,
            //then use that scan instead.
            if (!otherScan.isCancelled && [otherScan.contextInfo isEqual: drive])
            {
                return otherScan;
            }
            
            //If there's a scan going on for the same path, then make ours wait for that
            //one to finish. This prevents image scans from piling up and un/re-mounting
            //drives out of turn.
            else if ([otherScan.basePath isEqualToString: scanPath] ||
                     [otherScan.mountedVolumePath isEqualToString: scanPath])
                [scan addDependency: otherScan];
        }    

        [self willChangeValueForKey: @"isScanningForExecutables"];
        [self.scanQueue addOperation: scan];
        [self didChangeValueForKey: @"isScanningForExecutables"];
    }
    return scan;
}

- (BOOL) isScanningForExecutables
{
    for (NSOperation *scan in self.scanQueue.operations)
	{
		if (!scan.isFinished && !scan.isCancelled) return YES;
	}    
    return NO;
}

- (BXExecutableScan *) activeExecutableScanForDrive: (BXDrive *)drive
{
    for (BXExecutableScan *scan in self.scanQueue.operations)
	{
		if (scan.isExecuting && [scan.contextInfo isEqual: drive]) return scan;
	}    
    return nil;
}

- (BOOL) cancelExecutableScanForDrive: (BXDrive *)drive
{
    BOOL didCancelScan = NO;
    for (BXExecutableScan *operation in self.scanQueue.operations)
	{
        //Ignore completed scans
        if (operation.isFinished) continue;
        
		if ([operation.contextInfo isEqual: drive])
        {
            [self willChangeValueForKey: @"isScanningForExecutables"];
            [operation cancel];
            [self didChangeValueForKey: @"isScanningForExecutables"];
            didCancelScan = YES;
        }
	}    
    return didCancelScan;
}

- (void) executableScanDidFinish: (NSNotification *)theNotification
{
    BXExecutableScan *scan = theNotification.object;
	BXDrive *drive = scan.contextInfo;
    
    [self willChangeValueForKey: @"isScanningForExecutables"];
	if (scan.succeeded)
	{
        //Construct absolute paths out of the relative ones returned by the scan.
        NSArray *driveExecutables = [scan.basePath stringsByAppendingPaths: scan.matchingPaths];
        
        //Only send notifications if any executables were found, to prevent unnecessary redraws
        BOOL notify = (driveExecutables.count > 0);
        
        //TODO: is there a better notification method we could use here?
        if (notify) [self willChangeValueForKey: @"executables"];
        [_executables setObject: [NSMutableArray arrayWithArray: driveExecutables]
                         forKey: drive.letter];
        if (notify) [self didChangeValueForKey: @"executables"];
	}
    [self didChangeValueForKey: @"isScanningForExecutables"];
}

#pragma mark -
#pragma mark Drive importing

- (BOOL) driveIsBundled: (BXDrive *)drive
{
	if (drive.path && self.isGamePackage)
	{
		NSString *bundlePath = self.gamePackage.resourcePath;
		NSString *drivePath = drive.path;

		if ([drivePath isEqualToString: bundlePath] ||
            [drivePath.stringByDeletingLastPathComponent isEqualToString: bundlePath])
            return YES;
	}
	return NO;
}

- (BOOL) equivalentDriveIsBundled: (BXDrive *)drive
{
	if (drive.path && self.isGamePackage)
	{
		Class importClass		= [BXDriveImport importClassForDrive: drive];
		NSString *importedName	= [importClass nameForDrive: drive];
		NSString *importedPath	= [self.gamePackage.resourcePath stringByAppendingPathComponent: importedName];
	
		//A file already exists with the same name as we would import it with,
		//which probably means the drive was bundled earlier
		NSFileManager *manager = [NSFileManager defaultManager];
	
		return [manager fileExistsAtPath: importedPath];
	}
	return NO;
}

- (BXOperation <BXDriveImport> *) activeImportOperationForDrive: (BXDrive *)drive
{
	for (BXOperation <BXDriveImport> *import in self.importQueue.operations)
	{
		if (import.isExecuting && [import.drive isEqual: drive]) return import; 
	}
	return nil;
}

- (BOOL) canImportDrive: (BXDrive *)drive
{
	//Don't import drives if:
	//...we're not running a gamebox
	if (!self.isGamePackage) return NO;
	
	//...the drive is DOSBox-internal or hidden (which means it's a Boxer-internal drive)
	if (drive.isInternal || drive.isHidden) return NO;
	
	//...the drive is currently being imported or is already bundled in the current gamebox
	if ([self activeImportOperationForDrive: drive] ||
		[self driveIsBundled: drive] ||
		[self equivalentDriveIsBundled: drive]) return NO;
	
	//Otherwise, go for it!
	return YES;
}

- (BXOperation <BXDriveImport> *) importOperationForDrive: (BXDrive *)drive
										 startImmediately: (BOOL)start
{
	if ([self canImportDrive: drive])
	{
		NSString *destinationFolder = self.gamePackage.resourcePath;
		
		BXOperation <BXDriveImport> *driveImport = [BXDriveImport importOperationForDrive: drive
                                                                            toDestination: destinationFolder
                                                                                copyFiles: YES];
		
		driveImport.delegate = self;
		driveImport.didFinishSelector = @selector(driveImportDidFinish:);
    	
		if (start)
        {
            //If we'll lose access to the drive during importing,
            //eject it but leave it in the drive queue: and make
            //a note to remount it afterwards.
            if ([self driveIsMounted: drive] && [driveImport.class driveUnavailableDuringImport])
            {
                [self unmountDrive: drive
                           options: BXDriveForceUnmounting | BXDriveReplaceWithSiblingFromQueue
                             error: nil];
                
                NSDictionary *contextInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool: YES], @"remountAfterImport",
                                             nil];
                
                driveImport.contextInfo = contextInfo;
            }
            
            [self.importQueue addOperation: driveImport];
        }
        
		return driveImport;
	}
	else
	{
		return nil;
	}
}

- (BOOL) cancelImportForDrive: (BXDrive *)drive
{
	for (BXOperation <BXDriveImport> *import in self.importQueue.operations)
	{
		if (!import.isFinished && [import.drive isEqual: drive])
		{
			[import cancel];
			return YES;
		}
	}
	return NO;
}

- (BOOL) isImportingDrives
{
    for (NSOperation *import in self.importQueue.operations)
	{
		if (!import.isFinished && !import.isCancelled) return YES;
	}    
    return NO;
}

- (void) driveImportDidFinish: (NSNotification *)theNotification
{
	BXOperation <BXDriveImport> *import = theNotification.object;
	BXDrive *originalDrive = import.drive;
    
    BOOL remountDrive = [[import.contextInfo objectForKey: @"remountAfterImport"] boolValue];

	if (import.succeeded)
	{
		//Once the drive has successfully imported, replace the old drive
		//with the newly-imported version (as long as the old one is not currently in use)
		if (![self.emulator driveInUseAtLetter: originalDrive.letter])
		{
            NSString *destinationPath	= [import importedDrivePath];
			BXDrive *importedDrive		= [BXDrive driveFromPath: destinationPath
                                                        atLetter: originalDrive.letter];
			
            //Make the new drive an alias for the old one.
            [importedDrive.pathAliases addObject: originalDrive.path];
            
            //If the old drive is currently mounted, or was mounted back when we started
            //then replace it entirely.
			if (remountDrive || [self driveIsMounted: originalDrive])
            {
                //Mount the new drive without showing notification
                //or bothering to check for backing images.
                //Note that this will automatically fail if the old
                //drive is still in use.
                NSError *mountError = nil;
                BXDrive *mountedDrive = [self mountDrive: importedDrive
                                                ifExists: BXDriveReplace
                                                 options: 0
                                                   error: &mountError];
                
                //Remove the old drive from the queue, once we've mounted the new one.
                if (mountedDrive)
                {
                    [self replaceQueuedDrive: originalDrive
                                   withDrive: mountedDrive];
                }
            }
            //Otherwise, just replace the original drive in the same position in its queue.
            else
            {
                [self replaceQueuedDrive: originalDrive
                               withDrive: importedDrive];
            }
		}
		
		//Display a notification that this drive was successfully imported.
        [[BXBezelController controller] showDriveImportedBezelForDrive: originalDrive
                                                             toPackage: self.gamePackage];
	}
    
	else if (import.error)
	{
        //Remount the original drive, if it was unmounted as a result of the import
        if (remountDrive)
        {
            NSError *mountError = nil;
            [self mountDrive: originalDrive
                    ifExists: BXDriveReplace
                     options: 0
                       error: &mountError];
        }
		
        //Display a sheet for the error, unless it was just the user cancelling
		NSError *importError = import.error;
		if (!([importError.domain isEqualToString: NSCocoaErrorDomain] &&
              importError.code == NSUserCancelledError))
		{
			[self presentError: importError
				modalForWindow: self.windowForSheet
					  delegate: nil
			didPresentSelector: NULL
				   contextInfo: NULL];
		}
	}
}


- (void) _startTrackingChangesAtPath: (NSString *)path
{
	NSFileManager *manager = [NSFileManager defaultManager];
	BOOL isFolder, exists = [manager fileExistsAtPath: path isDirectory: &isFolder];
	//Note: UKFNSubscribeFileWatcher can only watch directories, not regular files 
	if (exists && isFolder)
	{
		[self.watcher addPath: path];
	}
}

- (void) _stopTrackingChangesAtPath: (NSString *)path
{
	[self.watcher removePath: path];
}

@end
