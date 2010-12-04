/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXSession+BXFileManager.h"
#import "BXAppController.h"

#import "BXEmulator+BXDOSFileSystem.h"
#import "BXEmulator+BXShell.h"
#import "UKFNSubscribeFileWatcher.h"
#import "BXMountPanelController.h"
#import "BXGrowlController.h"
#import "BXPackage.h"
#import "BXDrive.h"
#import "BXDrivesInUseAlert.h"
#import "BXGameProfile.h"

#import "BXDriveImport.h"

#import "NSWorkspace+BXMountedVolumes.h"
#import "NSWorkspace+BXFileTypes.h"
#import "NSWorkspace+BXExecutableTypes.h"
#import "NSString+BXPaths.h"
#import "NSFileManager+BXTemporaryFiles.h"
#import "BXPathEnumerator.h"


//Boxer will delay its handling of volume mount notifications by this many seconds,
//to allow multipart volumes to finish mounting properly
#define BXVolumeMountDelay 1.0


//The methods in this category are not intended to be called outside BXSession.
@interface BXSession ()

- (void) volumeDidMount:		(NSNotification *)theNotification;
- (void) volumeWillUnmount:		(NSNotification *)theNotification;
- (void) filesystemDidChange:	(NSNotification *)theNotification;

- (void) DOSDriveDidMount:		(NSNotification *)theNotification;
- (void) DOSDriveDidUnmount:	(NSNotification *)theNotification;

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
	return [NSSet setWithObject: @"principalDrive"];
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

	NSMutableArray *drivesInUse = [[NSMutableArray alloc] initWithCapacity: [selectedDrives count]];
	for (BXDrive *drive in selectedDrives)
	{
		if ([drive isLocked]) return NO; //Prevent locked drives from being removed altogether
		
		//If the drive is in use, then warn about it
		if ([[self emulator] driveInUseAtLetter: [drive letter]]) [drivesInUse addObject: drive];
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
	if (returnCode == NSAlertFirstButtonReturn) [self unmountDrives: selectedDrives];
}


- (BOOL) shouldMountDriveForPath: (NSString *)path
{
	//If the file isn't already accessible from DOS, we should mount it
	BXEmulator *theEmulator = [self emulator];
	if (![theEmulator pathIsDOSAccessible: path]) return YES;
	
	
	//If it is accessible within another drive, but the path is of a type that
	//should get its own drive, then mount it as a new drive of its own.
	NSWorkspace *workspace	= [NSWorkspace sharedWorkspace];
	if ([workspace file: path matchesTypes: [[self class] separatelyMountedTypes]]
	&& ![theEmulator pathIsMountedAsDrive: path])
		return YES;
	
	return NO;
}

- (BXDrive *) mountDriveForPath: (NSString *)path
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
	
	return [self mountDrive: drive];
}

- (BOOL) openFileAtPath: (NSString *)path
{
	BXEmulator *theEmulator = [self emulator];
	if (![theEmulator isExecuting] || [theEmulator isRunningProcess]) return NO;

	//Get the path to the file in the DOS filesystem
	NSString *dosPath = [theEmulator DOSPathForPath: path];
	if (!dosPath) return NO;
	
	if ([[self class] isExecutable: path])
	{
		//If an executable was specified, execute it!
		[theEmulator executeProgramAtPath: dosPath changingDirectory: YES];
	}
	else
	{
		//Otherwise, just switch to the specified path
		[theEmulator changeWorkingDirectoryToPath: dosPath];
	}
	return YES;
}


//Mount drives for all CD-ROMs that are currently mounted in OS X (as long as they're not already mounted, that is)
//Returns YES if any drives were mounted, NO otherwise
- (BOOL) mountCDVolumes
{
	BXEmulator *theEmulator = [self emulator];
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSArray *volumes = [workspace mountedVolumesOfType: dataCDVolumeType];
	
	//If there were no data CD volumes, then check for audio CD volumes and mount them instead
	//(We avoid doing this if there were data CD volumes, since the audio CDs will then be used
	//as 'shadow' audio volumes for those data CDs.)
	if (![volumes count])
		volumes = [workspace mountedVolumesOfType: audioCDVolumeType];
	
	BOOL returnValue = NO;
	for (NSString *volume in volumes)
	{
		if (![theEmulator pathIsMountedAsDrive: volume])
		{
			BXDrive *drive = [BXDrive CDROMFromPath: volume atLetter: nil];
			drive = [self mountDrive: drive];
			if (drive != nil) returnValue = YES;
		}
	}
	return returnValue;
}

//Mount drives for all floppy-sized FAT volumes that are currently mounted in OS X.
//Returns YES if any drives were mounted, NO otherwise.
- (BOOL) mountFloppyVolumes
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSArray *volumePaths = [workspace mountedVolumesOfType: FATVolumeType];
	BXEmulator *theEmulator = [self emulator];
	
	BOOL returnValue = NO;
	for (NSString *volumePath in volumePaths)
	{
		if (![theEmulator pathIsMountedAsDrive: volumePath] && [workspace isFloppySizedVolumeAtPath: volumePath])
		{
			BXDrive *drive = [BXDrive floppyDriveFromPath: volumePath atLetter: nil];
			drive = [self mountDrive: drive];
			if (drive != nil) returnValue = YES;
		}
	}
	return returnValue;
}


- (void) mountToolkitDrive
{
	BXEmulator *theEmulator = [self emulator];

	NSString *toolkitDriveLetter	= [[NSUserDefaults standardUserDefaults] stringForKey: @"toolkitDriveLetter"];
	NSString *toolkitFiles			= [[NSBundle mainBundle] pathForResource: @"DOS Toolkit" ofType: nil];
	BXDrive *toolkitDrive			= [BXDrive hardDriveFromPath: toolkitFiles atLetter: toolkitDriveLetter];
	
	//Hide and lock the toolkit drive so that it will not appear in the drive manager UI
	[toolkitDrive setLocked: YES];
	[toolkitDrive setReadOnly: YES];
	[toolkitDrive setHidden: YES];
	toolkitDrive = [self mountDrive: toolkitDrive];
	
	//Point DOS to the correct paths if we've mounted the toolkit drive successfully
	//TODO: we should treat this as an error if it didn't mount!
	if (toolkitDrive)
	{
		//Todo: the DOS path should include the root folder of every drive, not just Y and Z.
		NSString *dosPath	= [NSString stringWithFormat: @"%1$@:\\;%1$@:\\UTILS;Z:\\", [toolkitDrive letter], nil];
		NSString *ultraDir	= [NSString stringWithFormat: @"%@:\\ULTRASND", [toolkitDrive letter], nil];
		
		[theEmulator setVariable: @"path"		to: dosPath		encoding: BXDirectStringEncoding];
		[theEmulator setVariable: @"ultradir"	to: ultraDir	encoding: BXDirectStringEncoding];
	}	
}

- (void) mountTempDrive
{
	BXEmulator *theEmulator = [self emulator];

	//Mount a temporary folder at the appropriate drive
	NSFileManager *manager		= [NSFileManager defaultManager];
	NSString *tempDriveLetter	= [[NSUserDefaults standardUserDefaults] stringForKey: @"temporaryDriveLetter"];
	NSString *tempDrivePath		= [manager createTemporaryDirectoryWithPrefix: @"Boxer" error: NULL];
	
	if (tempDrivePath)
	{
		temporaryFolderPath = [tempDrivePath retain];
		
		BXDrive *tempDrive = [BXDrive hardDriveFromPath: tempDrivePath atLetter: tempDriveLetter];
		[tempDrive setLocked: YES];
		[tempDrive setHidden: YES];
		
		tempDrive = [self mountDrive: tempDrive];
		
		if (tempDrive)
		{
			NSString *tempPath = [NSString stringWithFormat: @"%@:\\", [tempDrive letter], nil];
			[theEmulator setVariable: @"temp"	to: tempPath	encoding: BXDirectStringEncoding];
			[theEmulator setVariable: @"tmp"	to: tempPath	encoding: BXDirectStringEncoding];
		}		
	}	
}

- (BXDrive *) mountDrive: (BXDrive *)drive
{
	//Allow the game profile to override the drive label if needed
	NSString *customLabel = nil;
	if ([self gameProfile]) customLabel = [[self gameProfile] labelForDrive: drive];
	if (customLabel) [drive setLabel: customLabel];
	
	return [[self emulator] mountDrive: drive];
}

- (BOOL) unmountDrive: (BXDrive *)drive
{
	return [[self emulator] unmountDrive: drive];
}


//Simple helper function to unmount a set of drives. Returns YES if any drives were unmounted, NO otherwise.
//Implemented just so that BXDrivePanelController doesn't have to know about BXEmulator+BXDOSFileSystem.
- (BOOL) unmountDrives: (NSArray *)selectedDrives
{
	BOOL succeeded = NO;
	for (BXDrive *drive in selectedDrives)
	{
		succeeded = [self unmountDrive: drive] || succeeded;
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
	
	[self mountDrive: drive];
}

//Implementation note: this handler is called in response to NSVolumeWillUnmountNotifications,
//so that we can remove any of our own file locks that would prevent OS X from continuing to unmount.
//However, it's also called again in response to NSVolumeDidUnmountNotifications, so that we can catch
//unmounts that happened too suddenly to send a WillUnmount notification (which can happen when
//pulling out a USB drive or mechanically ejecting a disk)
- (void) volumeWillUnmount: (NSNotification *)theNotification
{
	NSString *volumePath = [[theNotification userInfo] objectForKey: @"NSDevicePath"];
	[[self emulator] unmountDrivesForPath: volumePath];
}

- (void) filesystemDidChange: (NSNotification *)theNotification
{
	NSString *path = [[theNotification userInfo] objectForKey: @"path"];
	if ([[self emulator] pathIsDOSAccessible: path]) [[self emulator] refreshMountedDrives];
	
	//NSLog(@"Path changed: %@", path);
	
	//Also check if the file was inside our gamebox - if so, flush the gamebox's caches
	BXPackage *package = [self gamePackage];
	if (package && [path hasPrefix: [package gamePath]]) [package refresh];
}

- (void) DOSDriveDidMount: (NSNotification *)theNotification
{	
	BXDrive *drive = [[theNotification userInfo] objectForKey: @"drive"];
	
	//We access it this way so that KVO notifications get posted properly
	[[self mutableArrayValueForKey: @"drives"] addObject: drive];
	
	if (![drive isInternal])
	{
		NSString *drivePath = [drive path];
	
		[self _startTrackingChangesAtPath: drivePath];

		if (showDriveNotifications) [[BXGrowlController controller] notifyDriveMounted: drive];
		
		//Determine what executables are stored on this drive, if it's public
		//Tweak: only do this if we're running a gamebox, since launchable executables
		//are not displayed for non-gamebox sessions.
		if ([self isGamePackage] && ![drive isHidden])
		{
			NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
			NSMutableArray *foundExecutables = [NSMutableArray arrayWithCapacity: 10];
			BXPathEnumerator *enumerator = [BXPathEnumerator enumeratorAtPath: drivePath];
			
			NSSet *mountableFolderTypes	= [BXAppController mountableFolderTypes];
			NSSet *executableTypes		= [BXAppController executableTypes];
			for (NSString *path in enumerator)
			{
				NSString *fileType = [[enumerator fileAttributes] fileType];
				
				//Filter out the contents of any nested drive folders
				if ([fileType isEqualToString: NSFileTypeDirectory])
				{
					if ([workspace file: path matchesTypes: mountableFolderTypes]) [enumerator skipDescendents];
				}
				else
				{
					//Skip non-executables
					if (![workspace file: path matchesTypes: executableTypes]) continue;
					//Skip windows-only executables
					//This check is disabled for now because it's so costly
					//if ([workspace isWindowsOnlyExecutableAtPath: path]) continue;
					
					[foundExecutables addObject: path];
				}
			}
			
			//Only send notifications if any executables were found
			BOOL notify = ([foundExecutables count] > 0);
			
			//TODO: is there a better notification method we could use here?
			if (notify) [self willChangeValueForKey: @"executables"];
			[executables setObject: [NSMutableArray arrayWithArray: foundExecutables]
							forKey: [drive letter]];
			if (notify) [self didChangeValueForKey: @"executables"];
		}
	}
}

- (void) DOSDriveDidUnmount: (NSNotification *)theNotification
{
	BXDrive *drive = [[theNotification userInfo] objectForKey: @"drive"];
	
	//We access it this way so that KVO notifications get posted properly
	[[self mutableArrayValueForKey: @"drives"] removeObject: drive];
	
	if (![drive isInternal])
	{
		NSString *path = [drive path];
		//Only stop tracking if there are no other drives mapping to that path either.
		if (![[self emulator] pathIsDOSAccessible: path]) [self _stopTrackingChangesAtPath: path];
	
		if (showDriveNotifications) [[BXGrowlController controller] notifyDriveUnmounted: drive];
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
	
	//The drive is in our executables cache: remove any reference to the deleted file) 
	NSMutableArray *driveExecutables = [executables objectForKey: [drive letter]];
	if (driveExecutables && [driveExecutables containsObject: path])
	{
		[self willChangeValueForKey: @"executables"];
		[driveExecutables removeObject: path];
		[self didChangeValueForKey: @"executables"];
	}
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
		NSString *importedName = [BXDriveImport nameForDrive: drive];
		NSString *importedPath = [[[self gamePackage] resourcePath] stringByAppendingPathComponent: importedName];
	
		//A file already exists with the same name as we would import it with,
		//which probably means the drive was bundled earlier
		NSFileManager *manager = [NSFileManager defaultManager];
	
		return [manager fileExistsAtPath: importedPath];
	}
	return NO;
}

- (BOOL) driveIsImporting: (BXDrive *)drive
{
	for (BXDriveImport *operation in [importQueue operations])
	{
		if ([operation isExecuting] && [[operation contextInfo] isEqualTo: drive]) return YES; 
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

- (BXDriveImport *) beginImportForDrive: (BXDrive *)drive
{
	if ([self canImportDrive: drive])
	{
		NSString *destinationBase = [[self gamePackage] resourcePath];
		
		BXDriveImport *driveImport = [BXDriveImport importForDrive: drive toFolder: destinationBase copyFiles: YES];
		[driveImport setDelegate: self];
		
		[importQueue addOperation: driveImport];
		return driveImport;
	}
	return nil;
}

- (BOOL) cancelImportForDrive: (BXDrive *)drive
{
	for (BXDriveImport *operation in [importQueue operations])
	{
		if (![operation isFinished] && [[operation contextInfo] isEqualTo: drive])
		{
			[operation cancel];
			return YES;
		}
	}
	return NO;
}

- (void) operationDidFinish: (NSNotification *)theNotification
{
	BXDriveImport *import = [theNotification object];
	BXDrive *drive = [import contextInfo];

	if ([import succeeded])
	{
		//Once the drive has successfully imported, replace the old drive
		//with the newly-imported version (if the old one is not in use by DOS)
		if (![[self emulator] driveInUseAtLetter: [drive letter]])
		{
			NSString *destinationPath = [import destinationPath];
			BXDrive *importedDrive = [BXDrive driveFromPath: destinationPath atLetter: [drive letter]];
			
			//Temporarily suppress drive mount/unmount notifications
			BOOL oldShowDriveNotifications = showDriveNotifications;
			showDriveNotifications = NO;
			
			BOOL wasCurrentDrive = [[[self emulator] currentDrive] isEqualTo: drive];
			
			//Unmount the old drive first...
			if ([self unmountDrive: drive])
			{
				//...then mount the new one in its place
				BXDrive *mountedDrive = [self mountDrive: importedDrive];
				//If it worked, use the newly-mounted drive from now on
				if (mountedDrive)
				{
					drive = mountedDrive;
				}
				//If the mount failed for some reason, then put the old drive back
				else
				{
					[self mountDrive: drive];
				}
				//Switch to the new drive, if the replaced drive was the active drive
				if (wasCurrentDrive) [[self emulator] changeToDriveLetter: [drive letter]];
			}
			showDriveNotifications = oldShowDriveNotifications;
		} 
		
		//Post a Growl notification that this drive was successfully imported.
		[[BXGrowlController controller] notifyDriveImported: drive toPackage: [self gamePackage]];
	}
	else
	{
		//TODO: handle the transfer error gracefully, ideally giving the user the option to try again
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
