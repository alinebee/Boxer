/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXSession+BXFileManager.h"
#import "BXSessionPrivate.h"
#import "BXAppController.h"

#import "BXEmulator+BXDOSFileSystem.h"
#import "BXEmulatorErrors.h"
#import "BXEmulator+BXShell.h"
#import "UKFNSubscribeFileWatcher.h"
#import "BXMountPanelController.h"
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
@interface BXSession ()

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

+ (NSString *) preferredMountPointForPath: (NSString *)filePath
{	
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	
	//If the path is a disc image, use that as the mount point.
	if ([workspace file: filePath matchesTypes: [BXAppController mountableImageTypes]]) return filePath;
	
	//If the path is (itself or inside) a gamebox or mountable folder, use that as the mount point.
	NSString *container = [workspace parentOfFile: filePath matchingTypes: [[self class] preferredMountPointTypes]];
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
	
	NSArray *typeOrder = [NSArray arrayWithObjects:
						  @"net.washboardabs.boxer-game-package",
						  @"net.washboardabs.boxer-mountable-folder",
						  nil];
	
	//If the file is inside a gamebox (first in preferredMountPointTypes) then search from that;
	//If the file is inside a mountable folder (second) then search from that.
	for (NSString *type in typeOrder)
	{
		NSString *parent = [workspace parentOfFile: path matchingTypes: [NSSet setWithObject: type]];
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
	if (!types) types = [[NSSet alloc] initWithObjects:
						 @"net.washboardabs.boxer-game-package",		//.boxer
						 @"net.washboardabs.boxer-mountable-folder",	//Any of .floppy, .cdrom, .harddisk
						 nil];
	return types;
}

+ (NSSet *) separatelyMountedTypes
{
	static NSSet *types = nil;
	if (!types)
	{
		NSSet *imageTypes	= [BXAppController mountableImageTypes];
		NSSet *folderTypes	= [self preferredMountPointTypes];
		types = [[imageTypes setByAddingObjectsFromSet: folderTypes] retain];
	}
	return types;
}

+ (BOOL) isExecutable: (NSString *)path
{
	return [[NSWorkspace sharedWorkspace] file: path matchesTypes: [BXAppController executableTypes]];
}


#pragma mark -
#pragma mark File and folder mounting

+ (NSSet *) keyPathsForValuesAffectingPrincipalDrive
{
	return [NSSet setWithObject: @"executables"];
}

- (BXDrive *) principalDrive
{
	//Prioritise drive C, if it's available and has executables on it
	if ([[executables objectForKey: @"C"] count]) return [emulator driveAtLetter: @"C"];
	
	//Otherwise, go through the drives in letter order and return the first one that has programs on it
	NSArray *sortedDrives = [[self drives] sortedArrayUsingSelector: @selector(letterCompare:)];
	
	for (BXDrive *drive in sortedDrives)
	{
		NSString *letter = [drive letter];
		if ([[executables objectForKey: letter] count]) return drive;
	}
	return nil;
}

+ (NSSet *) keyPathsForValuesAffectingProgramPathsOnPrincipalDrive
{
	return [NSSet setWithObjects: @"principalDrive", @"executables", nil];
}

- (NSArray *) programPathsOnPrincipalDrive
{
	NSString *driveLetter = [[self principalDrive] letter];
	if (driveLetter) return [executables objectForKey: driveLetter];
	else return nil;
}


- (IBAction) refreshFolders:	(id)sender	{ [[self emulator] refreshMountedDrives]; }
- (IBAction) showMountPanel:	(id)sender	{ [[BXMountPanelController controller] showMountPanelForSession: self]; }

- (IBAction) openInDOS:			(id)sender
{
	if ([sender respondsToSelector: @selector(representedObject)]) sender = [sender representedObject];
	
	NSString *path = nil;
	
	//NSString paths
	if ([sender isKindOfClass: [NSString class]])			path = sender;
	//NSURLs and BXDrives
	else if ([sender respondsToSelector: @selector(path)])	path = [sender path];
	//NSDictionaries with paths
	else if ([sender isKindOfClass: [NSDictionary class]])	path = [sender objectForKey: @"path"];	
	
	if (path) [self openFileAtPath: path];
}

- (IBAction) relaunch: (id)sender
{
	if ([self targetPath]) [self openFileAtPath: [self targetPath]];
}

- (BOOL) shouldUnmountDrives: (NSArray *)selectedDrives sender: (id)sender
{
	//If the Option key was held down, bypass this check altogether and allow any drive to be unmounted
	NSUInteger optionKeyDown = [[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask;
	if (optionKeyDown) return YES;

	NSMutableArray *drivesInUse = [[[NSMutableArray alloc] initWithCapacity: [selectedDrives count]] autorelease];
	for (BXDrive *drive in selectedDrives)
	{
		if ([drive isLocked]) return NO; //Prevent locked drives from being removed altogether
		
		//If a program is running and the drive is in use, then warn about it
		if (![[self emulator] isAtPrompt] && [[self emulator] driveInUseAtLetter: [drive letter]])
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
		
		[alert beginSheetModalForWindow: sheetWindow
						  modalDelegate: self
						 didEndSelector: @selector(drivesInUseAlertDidEnd:returnCode:forDrives:)
							contextInfo: selectedDrives];

		return NO;
	}
	return YES;
}

- (void) drivesInUseAlertDidEnd: (BXDrivesInUseAlert *)alert
					 returnCode: (NSInteger)returnCode
					  forDrives: (NSArray *)selectedDrives
{
	[alert release];
	if (returnCode == NSAlertFirstButtonReturn)
    {
        NSError *unmountError = nil;
        [self unmountDrives: selectedDrives
                    options: BXDefaultDriveUnmountOptions
                      error: &unmountError];
        
        if (unmountError)
        {
            [self presentError: unmountError
                modalForWindow: [self windowForSheet]
                      delegate: nil
            didPresentSelector: NULL
                   contextInfo: NULL];
        }
    }
}


- (BOOL) shouldMountDriveForPath: (NSString *)path
{
	//If the file isn't already accessible from DOS, we should mount it
	BXEmulator *theEmulator = [self emulator];
	if (![theEmulator pathIsDOSAccessible: path]) return YES;
	
	
	//If it is accessible within another drive, but the path is of a type
	//that should get its own drive, then mount it as a new drive of its own.
	NSWorkspace *workspace	= [NSWorkspace sharedWorkspace];
	if ([workspace file: path matchesTypes: [[self class] separatelyMountedTypes]]
	&& ![theEmulator pathIsMountedAsDrive: path])
		return YES;
	
	return NO;
}

- (BXDrive *) mountDriveForPath: (NSString *)path
                        options: (BXDriveMountOptions)options
                          error: (NSError **)outError
{
	NSFileManager *manager = [NSFileManager defaultManager];
	BXEmulator *theEmulator = [self emulator];

	//Emulator isn't running
	if (![theEmulator isExecuting]) return nil;

	//File doesn't exist, bail out
	if (![manager fileExistsAtPath: path isDirectory: NULL]) return nil;
	
	//Choose an appropriate mount point and create the new drive for it
	NSString *mountPoint	= [[self class] preferredMountPointForPath: path];
	BXDrive *drive			= [BXDrive driveFromPath: mountPoint atLetter: nil];
	
	return [self mountDrive: drive options: options error: outError];
}

- (BOOL) openFileAtPath: (NSString *)path
{
	BXEmulator *theEmulator = [self emulator];
	if (![theEmulator isExecuting] || [theEmulator isRunningProcess]) return NO;
    
	//Get the path to the file in the DOS filesystem
	NSString *dosPath = [theEmulator DOSPathForPath: path];
	if (!dosPath || ![theEmulator DOSPathExists: dosPath]) return NO;
	
	//Unpause the emulation if it's paused
	[self setPaused: NO];
	
	if ([[self class] isExecutable: path])
	{
		//If an executable was specified, execute it
        [self setLastLaunchedProgramPath: path];
		[theEmulator executeProgramAtPath: dosPath changingDirectory: YES];
	}
	else
	{
		//Otherwise, just switch to the specified path
		[theEmulator changeWorkingDirectoryToPath: dosPath];
	}
	return YES;
}


//Mount drives for all CD-ROMs that are currently mounted in OS X
//(as long as they're not already mounted in DOS, that is.)
//Returns YES if any drives were mounted, NO otherwise.
- (BOOL) mountCDVolumesWithError: (NSError **)outError
{
	BXEmulator *theEmulator = [self emulator];
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSArray *volumes = [workspace mountedVolumesOfType: dataCDVolumeType];
	
	//If there were no data CD volumes, then check for audio CD volumes and mount them instead
	//(We avoid doing this if there were data CD volumes, since the audio CDs will then be used
	//as 'shadow' audio volumes for those data CDs.)
	if (![volumes count])
		volumes = [workspace mountedVolumesOfType: audioCDVolumeType];
    
    //Queue these drives with any existing CD-ROM drives,
    //use a backing image if available, and don't show
    //drive-added notifications
    BXDriveMountOptions mountOptions = BXDriveMountImageIfAvailable | BXDriveQueueWithSameType;
    
	BOOL returnValue = NO;
	for (NSString *volume in volumes)
	{
		if (![theEmulator pathIsMountedAsDrive: volume])
		{
			BXDrive *drive = [BXDrive CDROMFromPath: volume
                                           atLetter: nil];

            drive = [self mountDrive: drive 
                             options: mountOptions
                               error: outError];
            
			if (drive != nil) returnValue = YES;
            
            //If there was any error in mounting a drive,
            //then bail out and don't attempt to mount further drives
            //TODO: check the actual error to determine whether we can
            //continue after failure.
            else return NO;
		}
	}
	return returnValue;
}

//Mount drives for all floppy-sized FAT volumes that are currently mounted in OS X.
//Returns YES if any drives were mounted, NO otherwise.
- (BOOL) mountFloppyVolumesWithError: (NSError **)outError
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSArray *volumePaths = [workspace mountedVolumesOfType: FATVolumeType];
	BXEmulator *theEmulator = [self emulator];
	
    //Queue these drives with any existing floppy drives,
    //use a backing image if available, and don't show
    //drive-added notifications
    BXDriveMountOptions mountOptions = BXDriveMountImageIfAvailable | BXDriveQueueWithSameType;
    
	BOOL returnValue = NO;
	for (NSString *volumePath in volumePaths)
	{
		if (![theEmulator pathIsMountedAsDrive: volumePath] && [workspace isFloppySizedVolumeAtPath: volumePath])
		{
			BXDrive *drive = [BXDrive floppyDriveFromPath: volumePath atLetter: nil];
            
            drive = [self mountDrive: drive
                             options: mountOptions
                               error: outError];
            
			if (drive != nil) returnValue = YES;
            
            //If there was any error in mounting a drive,
            //then bail out and don't attempt to mount further drives
            //TODO: check the actual error to determine whether we can
            //continue after failure.
            else return NO;
		}
	}
	return returnValue;
}

+ (NSSet *) keyPathsForValuesAffectingHasFloppyDrives	{ return [NSSet setWithObject: @"drives"]; }
+ (NSSet *) keyPathsForValuesAffectingHasCDDrives		{ return [NSSet setWithObject: @"drives"]; }

- (BOOL) hasFloppyDrives
{
	for (BXDrive *drive in [self drives])
	{
		if ([drive isFloppy]) return YES;
	}
	return NO;
}

- (BOOL) hasCDDrives
{
	for (BXDrive *drive in [self drives])
	{
		if ([drive isCDROM]) return YES;
	}
	return NO;
}

- (void) mountToolkitDriveWithError: (NSError **)outError
{
	BXEmulator *theEmulator = [self emulator];

	NSString *toolkitDriveLetter	= [[NSUserDefaults standardUserDefaults] stringForKey: @"toolkitDriveLetter"];
	NSString *toolkitFiles			= [[NSBundle mainBundle] pathForResource: @"DOS Toolkit" ofType: nil];
	BXDrive *toolkitDrive			= [BXDrive hardDriveFromPath: toolkitFiles atLetter: toolkitDriveLetter];
	
	//Hide and lock the toolkit drive so that it will not appear in the drive manager UI
	[toolkitDrive setLocked: YES];
	[toolkitDrive setReadOnly: YES];
	[toolkitDrive setHidden: YES];
	[toolkitDrive setFreeSpace: 0];
    //Replace any existing drive at the same letter, and don't show any notifications
	toolkitDrive = [self mountDrive: toolkitDrive
                            options: BXDriveReplaceExisting
                              error: outError];
	
	//Point DOS to the correct paths if we've mounted the toolkit drive successfully
	//TODO: we should treat this as an error if it didn't mount!
	if (toolkitDrive)
	{
		//Todo: the DOS path should include the root folder of every drive, not just Y and Z.
		NSString *dosPath	= [NSString stringWithFormat: @"%1$@:\\;%1$@:\\UTILS;Z:\\", [toolkitDrive letter], nil];
		NSString *ultraDir	= [NSString stringWithFormat: @"%@:\\ULTRASND", [toolkitDrive letter], nil];
		NSString *utilsDir	= [NSString stringWithFormat: @"%@:\\UTILS", [toolkitDrive letter], nil];
		
		[theEmulator setVariable: @"path"		to: dosPath		encoding: BXDirectStringEncoding];
		[theEmulator setVariable: @"boxerutils"	to: utilsDir	encoding: BXDirectStringEncoding];
		[theEmulator setVariable: @"ultradir"	to: ultraDir	encoding: BXDirectStringEncoding];
	}	
}

- (void) mountTempDriveWithError: (NSError **)outError
{
	BXEmulator *theEmulator = [self emulator];

	//Mount a temporary folder at the appropriate drive
	NSFileManager *manager		= [NSFileManager defaultManager];
	NSString *tempDriveLetter	= [[NSUserDefaults standardUserDefaults] stringForKey: @"temporaryDriveLetter"];
	NSString *tempDrivePath		= [manager createTemporaryDirectoryWithPrefix: @"Boxer" error: outError];
	
	if (tempDrivePath)
	{
		temporaryFolderPath = [tempDrivePath retain];
		
		BXDrive *tempDrive = [BXDrive hardDriveFromPath: tempDrivePath atLetter: tempDriveLetter];
		[tempDrive setLocked: YES];
		[tempDrive setHidden: YES];
		
        //Replace any existing drive at the same letter, and don't show any notifications
		tempDrive = [self mountDrive: tempDrive
                             options: BXDriveReplaceExisting
                               error: outError];
		
		if (tempDrive)
		{
			NSString *tempPath = [NSString stringWithFormat: @"%@:\\", [tempDrive letter], nil];
			[theEmulator setVariable: @"temp"	to: tempPath	encoding: BXDirectStringEncoding];
			[theEmulator setVariable: @"tmp"	to: tempPath	encoding: BXDirectStringEncoding];
		}
        //If we couldn't mount the temporary folder for some reason, then delete it
        else
        {
            [manager removeItemAtPath: tempDrivePath error: nil];
        }
	}	
}

- (BXDrive *) mountDrive: (BXDrive *)drive
                 options: (BXDriveMountOptions)options
                   error: (NSError **)outError
{
    if (outError) *outError = nil;
    
    if (options == 0) options = BXDefaultDriveMountOptions;
    
    //Determine which queue behaviour is applicable
#define NUM_QUEUE_OPTIONS 5
    BXDriveMountOptions queueOptions[NUM_QUEUE_OPTIONS] = {BXDriveQueueIfAppropriate, BXDriveQueueWithExisting, BXDriveQueueWithSameType, BXDriveReplaceExisting, BXDriveNeverQueue};
    BXDriveMountOptions queueBehaviour = BXDriveQueueIfAppropriate;
    NSUInteger i;
    for (i=0; i<NUM_QUEUE_OPTIONS; i++)
    {
        if (options & queueOptions[i]) { queueBehaviour = queueOptions[i]; break; }
    }
	
    if (queueBehaviour == BXDriveQueueIfAppropriate)
    {
        if ([drive type] == BXDriveCDROM || [drive type] == BXDriveFloppyDisk)
            queueBehaviour = BXDriveQueueWithSameType;
        else
            queueBehaviour = BXDriveNeverQueue;
    }
    
    //BXDriveQueueWithSameType behaviour:
    //If the drive doesn't have a specific drive letter, then try to find
    //other drives of the same type to queue it with.
    if (![drive letter] && queueBehaviour == BXDriveQueueWithSameType)
    {
        for (BXDrive *otherDrive in [self drives])
        {
            if ([drive type] == [otherDrive type])
            {
                [drive setLetter: [otherDrive letter]];
                break;
            }
        }
    }
    
    //Allow the game profile to override the drive label if needed.
    //TODO: make this subject to an options flag?
	NSString *customLabel = [[self gameProfile] labelForDrive: drive];
	if (customLabel) [drive setLabel: customLabel];
    

    BXDrive *driveToMount = drive;
    BXDrive *fallbackDrive = nil;
    
	if (options & BXDriveMountImageIfAvailable)
    {
        //Check if the specified path has a DOSBox-compatible image backing it:
        //if so then try to mount that instead, and assign the current path as an alias.
        NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
        NSString *sourceImagePath = [workspace sourceImageForVolume: [drive path]];
        
        if (sourceImagePath && [workspace file: sourceImagePath matchesTypes: [BXAppController mountableImageTypes]])
        {
            //Check if the source image is already mounted:
            //if so, then just add the path as an alias to that existing drive.
            //TODO: make this subject to an options flag.
            BXDrive *existingDrive = [[self emulator] driveForPath: sourceImagePath];
            if (existingDrive)
            {
                [[existingDrive pathAliases] addObject: [drive path]];
                return existingDrive;
            }
            //Otherwise, make a new drive using the image, and mount that instead.
            else
            {
                BXDrive *imageDrive = [BXDrive driveFromPath: sourceImagePath
                                                    atLetter: [drive letter]
                                                    withType: [drive type]];
                
                [imageDrive setReadOnly: [drive readOnly]];
                [imageDrive setHidden: [drive isHidden]];
                [imageDrive setLocked: [drive isLocked]];
                [[imageDrive pathAliases] addObject: [drive path]];
                
                driveToMount = imageDrive;
                fallbackDrive = drive;
            }
        }
    }
    
    BXDrive *mountedDrive = nil;
    BXDrive *replacedDrive = nil;
    BOOL replacedDriveWasCurrent = NO;
    
    do
    {
        NSError *mountError = nil;
        mountedDrive = [[self emulator] mountDrive: driveToMount error: &mountError];
    
        //If mounting fails, check what the failure was and try to recover
        if (!mountedDrive)
        {
            switch ([mountError code])
            {
                //The drive letter was already taken: decide what to do
                //based on our queueing behaviour.
                case BXDOSFilesystemDriveLetterOccupied:
                    if (queueBehaviour == BXDriveNeverQueue)
                    {
                        //Clear the preferred drive letter,
                        //to let the drive take the next available letter.
                        [driveToMount setLetter: nil];
                    }
                    //If we want to replace the existing drive, or we want to queue
                    //but push this to the front, then unmount the previous drive.
                    else if (queueBehaviour == BXDriveReplaceExisting || (options & BXDriveMountImmediately))
                    {
                        NSError *unmountError = nil;
                        replacedDrive = [[self emulator] driveAtLetter: [driveToMount letter]];
                        replacedDriveWasCurrent = [[[self emulator] currentDrive] isEqual: replacedDrive];
                        
                        BOOL unmounted = [[self emulator] unmountDrive: replacedDrive
                                                                 error: &unmountError];
                        //If we couldn't unmount the drive, then bail the hell out
                        if (!unmounted && unmountError)
                        {
                            if (outError) *outError = unmountError;
                            return nil;
                        }
                    }
                    //Otherwise, we want to queue the drive at the back of the list.
                    //But because we haven't actually implemented queuing yet, this means
                    //we just silently ignore the drive mount.
                    else
                    {
                        return nil;
                    }
                    break;
                    
                //The image couldn't be mounted: if we have a fallback volume, use that instead.
                //Otherwise, bail out altogether
                case BXDOSFilesystemInvalidImage:
                    if (fallbackDrive)
                    {
                        driveToMount = fallbackDrive;
                        fallbackDrive = nil;
                    }
                    else
                    {
                        if (outError) *outError = mountError;
                        return nil;
                    }
                    break;
                
                //Bail out completely after any other error - after putting back any drive
                //we were attempting to replace
                default:
                    if (replacedDrive)
                    {
                        [[self emulator] mountDrive: replacedDrive error: nil];
                        if (replacedDriveWasCurrent && [[self emulator] isAtPrompt])
                            [[self emulator] changeToDriveLetter: [replacedDrive letter]];
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
            [[BXBezelController controller] showDriveSwappedBezelFromDrive: replacedDrive toDrive: mountedDrive];
        }
        else
        {
            [[BXBezelController controller] showDriveAddedBezelForDrive: mountedDrive];
        }
    }
    
    //If we replaced DOS's current drive in the course of ejecting, then switch 
    if (replacedDrive && replacedDriveWasCurrent && [[self emulator] isAtPrompt])
    {
        [[self emulator] changeToDriveLetter: [mountedDrive letter]];
    }
    
    return mountedDrive;
}


- (BOOL) unmountDrive: (BXDrive *)drive
              options: (BXDriveUnmountOptions)options
                error: (NSError **)outError
{
	//Refuse to eject drives that are currently being imported.
	if (!(options & BXDriveForceUnmount) && [self driveIsImporting: drive])
    {
        if (outError) *outError = [BXEmulatorDriveInUseError errorWithDrive: drive];
        return NO;
    }
    else
    {
        BOOL unmounted = [[self emulator] unmountDrive: drive error: outError];
        if (unmounted && (options & BXDriveShowNotifications))
        {
            [[BXBezelController controller] showDriveRemovedBezelForDrive: drive];
        }
        return unmounted;
    }
}


//Simple helper function to unmount a set of drives. Returns YES if all drives were unmounted,
//NO if there was an error or no drives were selected.
//Implemented just so that BXDrivePanelController doesn't have to know about BXEmulator+BXDOSFileSystem.
- (BOOL) unmountDrives: (NSArray *)selectedDrives
               options: (BXDriveUnmountOptions)options
                 error: (NSError **)outError
{
	BOOL succeeded = NO;
	for (BXDrive *drive in selectedDrives)
	{
        if ([self unmountDrive: drive options: options error: outError]) succeeded = YES;
        //If any of the drive unmounts failed, don't continue further
        else return NO;
	}
	return succeeded;
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
				 object: watcher];
	
	[center addObserver: self
			   selector: @selector(filesystemDidChange:)
				   name: UKFileWatcherDeleteNotification
				 object: watcher];
	
	[center addObserver: self
			   selector: @selector(filesystemDidChange:)
				   name: UKFileWatcherRenameNotification
				 object: watcher];
	
	[center addObserver: self
			   selector: @selector(filesystemDidChange:)
				   name: UKFileWatcherAccessRevocationNotification
				 object: watcher];
}

- (void) _deregisterForFilesystemNotifications
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSNotificationCenter *center = [workspace notificationCenter];

	[center removeObserver: self name: NSWorkspaceDidMountNotification		object: workspace];
	[center removeObserver: self name: NSWorkspaceDidUnmountNotification	object: workspace];
	[center removeObserver: self name: NSWorkspaceWillUnmountNotification	object: workspace];
	[center removeObserver: self name: UKFileWatcherWriteNotification		object: watcher];
	[center removeObserver: self name: UKFileWatcherDeleteNotification		object: watcher];
	[center removeObserver: self name: UKFileWatcherRenameNotification		object: watcher];
	[center removeObserver: self name: UKFileWatcherAccessRevocationNotification object: watcher];
}

- (void) volumeDidMount: (NSNotification *)theNotification
{
	//We decide what to do with audio CD volumes based on whether they have a corresponding
	//data volume. Unfortunately, the volumes are reported as soon as they are mounted, so
	//often the audio volume will send a mount notification before its data volume exists.
	
	//To work around this, we add a slight delay before we process the volume mount notification,
	//to allow other volumes to finish mounting.
	[self performSelector: @selector(_handleVolumeDidMount:)
			   withObject: theNotification
			   afterDelay: BXVolumeMountDelay];
}

- (void) _handleVolumeDidMount: (NSNotification *)theNotification
{
	//Don't respond to mounts if the emulator isn't actually running
	if (![emulator isExecuting]) return;
	
	//Ignore mounts if we currently have the mount panel open;
	//we assume that the user will want to handle the new volume manually.
	NSWindow *attachedSheet = [[self windowForSheet] attachedSheet];
	if ([attachedSheet isMemberOfClass: [NSOpenPanel class]]) return;
	
	NSArray *automountedTypes = [NSArray arrayWithObjects:
								 dataCDVolumeType,
								 audioCDVolumeType,
								 FATVolumeType,
								 nil];
	
	NSWorkspace *workspace	= [NSWorkspace sharedWorkspace];
	NSString *volumePath	= [[theNotification userInfo] objectForKey: @"NSDevicePath"];
	NSString *volumeType	= [workspace volumeTypeForPath: volumePath];
	
    //Ignore mount if we're scanning this volume for executables:
    //this indicates that the scan is responsible for the mount,
    //and it's not a user-mounted drive.
    for (BXExecutableScan *scan in [scanQueue operations])
    {
        if ([[scan mountedVolumePath] isEqualToString: volumePath]) return;
    }
    
	//Only mount volumes that are of an appropriate type
	if (![automountedTypes containsObject: volumeType]) return;
	
	//Only mount CD audio volumes if they have no corresponding data volume
	//(Otherwise, we mount the data volume instead and shadow it with the audio CD's tracks)
	if ([volumeType isEqualToString: audioCDVolumeType] && [workspace dataVolumeOfAudioCD: volumePath]) return;
	
	//Only mount FAT volumes that are floppy-sized
	if ([volumeType isEqualToString: FATVolumeType] && ![workspace isFloppySizedVolumeAtPath: volumePath]) return;
	
	//Only mount volumes that aren't already mounted as drives
	NSString *mountPoint = [[self class] preferredMountPointForPath: volumePath];
	if ([[self emulator] pathIsMountedAsDrive: mountPoint]) return;
	
	//Alright, if we got this far then it's ok to mount a new drive for it
	BXDrive *drive = [BXDrive driveFromPath: mountPoint atLetter: nil];
	
    //Ignore errors when automounting volumes, since these
    //are not directly triggered by the user.
	[self mountDrive: drive options: BXDefaultDriveMountOptions error: nil];
}

//Implementation note: this handler is called in response to NSVolumeWillUnmountNotifications,
//so that we can remove any of our own file locks that would prevent OS X from continuing to unmount.
//However, it's also called again in response to NSVolumeDidUnmountNotifications, so that we can catch
//unmounts that happened too suddenly to send a WillUnmount notification (which can happen when
//pulling out a USB drive or mechanically ejecting a disk)
- (void) volumeWillUnmount: (NSNotification *)theNotification
{
	//Don't respond to unmount events if the emulator isn't actually running
	if (![emulator isExecuting]) return;
	
	NSString *volumePath = [[theNotification userInfo] objectForKey: @"NSDevicePath"];
	//Should already be standardized, but still
	NSString *standardizedPath = [volumePath stringByStandardizingPath];
	
	for (BXDrive *drive in [[self emulator] mountedDrives])
	{
		//TODO: refactor this so that we can move the decision off to BXDrive itself
		//(We can't use representsPath: because that includes path aliases too)
		if ([[drive path] isEqualToString: standardizedPath] || [[drive mountPoint] isEqualToString: standardizedPath])
		{
			//NOTE: This will fail to unmount if the drive is currently importing.
			//This is intentional, because some import methods unmount the volume
			//themselves while they import. However, it means we can end up with
			//'ghost' drives if the user physically removes the disk themselves
			//during import.
			[self unmountDrive: drive
                       options: BXDefaultDriveUnmountOptions
                         error: nil];
		}
		else
		{
			[[drive pathAliases] removeObject: standardizedPath];
		}
	}
}

- (void) filesystemDidChange: (NSNotification *)theNotification
{
	NSString *path = [[theNotification userInfo] objectForKey: @"path"];
	if ([[self emulator] pathIsDOSAccessible: path]) [[self emulator] refreshMountedDrives];
	
	//Also check if the file was inside our gamebox - if so, flush the gamebox's caches
	BXPackage *package = [self gamePackage];
	if (package && [path hasPrefix: [package gamePath]]) [package refresh];
}

- (void) emulatorDidMountDrive: (NSNotification *)theNotification
{	
	BXDrive *drive = [[theNotification userInfo] objectForKey: @"drive"];
	
	//We access it this way so that KVO notifications get posted properly
	[[self mutableArrayValueForKey: @"drives"] addObject: drive];
	
	if (![drive isInternal])
	{
		NSString *drivePath = [drive path];
	
		[self _startTrackingChangesAtPath: drivePath];
		
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
	BXDrive *drive = [[theNotification userInfo] objectForKey: @"drive"];
	
	//We access it this way so that KVO notifications get posted properly
	[[self mutableArrayValueForKey: @"drives"] removeObject: drive];
	
    //Stop scanning for executables on the drive
    [self cancelExecutableScanForDrive: drive];
    
	if (![drive isInternal])
	{
		NSString *path = [drive path];
		//Stop tracking for changes on the drive, if there are no other drives mapping to that path either.
		if (![[self emulator] pathIsDOSAccessible: path]) [self _stopTrackingChangesAtPath: path];
	}
	
	if ([executables objectForKey: [drive letter]])
	{
		[self willChangeValueForKey: @"executables"];
		[executables removeObjectForKey: [drive letter]];
		[self didChangeValueForKey: @"executables"];
	}
}

//Pick up on the creation of new executables
- (void) emulatorDidCreateFile: (NSNotification *)notification
{
	BXDrive *drive = [[notification userInfo] objectForKey: @"drive"];
	NSString *path = [[notification userInfo] objectForKey: @"path"];
	
	//The drive is in our executables cache: check if the created file path was an executable
	//(If so, add it to the executables cache) 
	NSMutableArray *driveExecutables = [executables mutableArrayValueForKey: [drive letter]];
	if (driveExecutables)
	{
		NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
        
        //Disabled windows-only file check for now to avoid slowdowns
		if ([workspace file: path matchesTypes: [BXAppController executableTypes]]) // && ![workspace isWindowsOnlyExecutableAtPath: path]
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
	BXDrive *drive = [[notification userInfo] objectForKey: @"drive"];
	NSString *path = [[notification userInfo] objectForKey: @"path"];
	
	//The drive is in our executables cache: remove any reference to the deleted file
	NSMutableArray *driveExecutables = [executables objectForKey: [drive letter]];
	if (driveExecutables && [driveExecutables containsObject: path])
	{
		[self willChangeValueForKey: @"executables"];
		[driveExecutables removeObject: path];
		[self didChangeValueForKey: @"executables"];
	}
}

#pragma mark -
#pragma mark Drive executable scanning

- (BXExecutableScan *) executableScanForDrive: (BXDrive *)drive
                             startImmediately: (BOOL)start
{
    BXExecutableScan *scan = [BXExecutableScan scanWithBasePath: [drive path]];
    [scan setDelegate: self];
    [scan setDidFinishSelector: @selector(executableScanDidFinish:)];
    [scan setContextInfo: drive];
    
    if (start)
    {
        [self willChangeValueForKey: @"isScanningForExecutables"];
        [scanQueue addOperation: scan];
        [self didChangeValueForKey: @"isScanningForExecutables"];
    }
    return scan;
}

- (BOOL) isScanningForExecutables
{
    for (NSOperation *scan in [scanQueue operations])
	{
		if (![scan isFinished] && ![scan isCancelled]) return YES;
	}    
    return NO;
}

- (BOOL) isScanningForExecutablesInDrive: (BXDrive *)drive
{
    for (BXExecutableScan *operation in [scanQueue operations])
	{
		if ([operation isExecuting] && [[operation contextInfo] isEqual: drive]) return YES;
	}    
    return NO;
}

- (BOOL) cancelExecutableScanForDrive: (BXDrive *)drive
{
    for (BXExecutableScan *operation in [scanQueue operations])
	{
		if (![operation isFinished] && [[operation contextInfo] isEqual: drive])
        {
            [self willChangeValueForKey: @"isScanningForExecutables"];
            [operation cancel];
            [self didChangeValueForKey: @"isScanningForExecutables"];
            return YES;
        }
	}    
    return NO;   
}

- (void) executableScanDidFinish: (NSNotification *)theNotification
{
    BXExecutableScan *scan = [theNotification object];
	BXDrive *drive = [scan contextInfo];
    
    [self willChangeValueForKey: @"isScanningForExecutables"];
	if ([scan succeeded])
	{
        //Construct absolute paths out of the relative ones returned by the scan.
        NSArray *driveExecutables = [[scan basePath] stringsByAppendingPaths: [scan matchingPaths]];
        
        //Only send notifications if any executables were found, to prevent unnecessary redraws
        BOOL notify = ([driveExecutables count] > 0);
        
        //TODO: is there a better notification method we could use here?
        if (notify) [self willChangeValueForKey: @"executables"];
        [executables setObject: [NSMutableArray arrayWithArray: driveExecutables]
                        forKey: [drive letter]];
        if (notify) [self didChangeValueForKey: @"executables"];
	}
    [self didChangeValueForKey: @"isScanningForExecutables"];
}

#pragma mark -
#pragma mark Drive importing

- (BOOL) driveIsBundled: (BXDrive *)drive
{
	if ([self isGamePackage])
	{
		NSString *gameboxPath = [[self gamePackage] bundlePath];
		NSString *drivePath = [drive path];

		if ([drivePath isRootedInPath: gameboxPath]) return YES;
	}
	return NO;
}

- (BOOL) equivalentDriveIsBundled: (BXDrive *)drive
{
	if ([self isGamePackage])
	{
		Class importClass		= [BXDriveImport importClassForDrive: drive];
		NSString *importedName	= [importClass nameForDrive: drive];
		NSString *importedPath	= [[[self gamePackage] resourcePath] stringByAppendingPathComponent: importedName];
	
		//A file already exists with the same name as we would import it with,
		//which probably means the drive was bundled earlier
		NSFileManager *manager = [NSFileManager defaultManager];
	
		return [manager fileExistsAtPath: importedPath];
	}
	return NO;
}

- (BOOL) driveIsImporting: (BXDrive *)drive
{
	for (BXOperation *operation in [importQueue operations])
	{
		if ([operation isExecuting] && [[operation contextInfo] isEqual: drive]) return YES; 
	}
	return NO;
}

- (BOOL) canImportDrive: (BXDrive *)drive
{
	//Don't import drives if:
	//...we're not running a gamebox
	if (![self isGamePackage]) return NO;
	
	//...the drive is DOSBox-internal or hidden (which means it's a Boxer-internal drive)
	if ([drive isInternal] || [drive isHidden]) return NO;
	
	//...the drive is currently being imported or is already bundled in the current gamebox
	if ([self driveIsImporting: drive] ||
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
		NSString *destinationFolder = [[self gamePackage] resourcePath];
		
		BXOperation <BXDriveImport> *driveImport = [BXDriveImport importOperationForDrive: drive
																   toDestination: destinationFolder
																	   copyFiles: YES];
		
		[driveImport setDelegate: self];
		[driveImport setDidFinishSelector: @selector(driveImportDidFinish:)];
		[driveImport setContextInfo: drive];
		
		if (start) [importQueue addOperation: driveImport];
		return driveImport;
	}
	else
	{
		return nil;
	}
}

- (BOOL) cancelImportForDrive: (BXDrive *)drive
{
	for (BXOperation *operation in [importQueue operations])
	{
		if (![operation isFinished] && [[operation contextInfo] isEqual: drive])
		{
			[operation cancel];
			return YES;
		}
	}
	return NO;
}

- (BOOL) isImportingDrives
{
    for (NSOperation *import in [importQueue operations])
	{
		if (![import isFinished] && ![import isCancelled]) return YES;
	}    
    return NO;
}

- (void) driveImportDidFinish: (NSNotification *)theNotification
{
	BXOperation <BXDriveImport> *import = [theNotification object];
	BXDrive *originalDrive = [import drive];

	if ([import succeeded])
	{
		//Once the drive has successfully imported, replace the old drive
		//with the newly-imported version (if the old one is not currently in use)
		if (![[self emulator] driveInUseAtLetter: [originalDrive letter]])
		{
			NSString *destinationPath	= [import importedDrivePath];
			BXDrive *importedDrive		= [BXDrive driveFromPath: destinationPath
                                                        atLetter: [originalDrive letter]];
			
			//Replace the original drive with the newly-imported drive,
            //without showing notifications or bothering to check for
            //backing images.
            NSError *mountError = nil;
            BXDrive *mountedDrive = [self mountDrive: importedDrive
                                             options: BXDriveReplaceExisting
                                               error: &mountError];
            
            if (mountedDrive)
            {
                //Make the new drive an alias for the old one.
                //(This will prevent it from getting remounted as a duplicate drive.)
                [[mountedDrive pathAliases] addObject: [originalDrive path]];
            }
		} 
		
		//Display a notification that this drive was successfully imported.
        [[BXBezelController controller] showDriveImportedBezelForDrive: originalDrive
                                                             toPackage: [self gamePackage]];
	}
	else if ([import error])
	{
		NSError *importError = [import error];
		
		//Unwind failed transfers, whatever the reason
		[import undoTransfer];
		
		//Display a sheet for the error, unless it was just the user cancelling
		if (!([[importError domain] isEqualToString: NSCocoaErrorDomain] && [importError code] == NSUserCancelledError))
		{
			[self presentError: importError
				modalForWindow: [self windowForSheet]
					  delegate: nil
			didPresentSelector: NULL
				   contextInfo: nil];
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
		[watcher addPath: path];
	}
}

- (void) _stopTrackingChangesAtPath: (NSString *)path
{
	[watcher removePath: path];
}

@end
