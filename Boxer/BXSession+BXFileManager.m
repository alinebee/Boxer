/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXAppController.h"
#import "BXSession+BXFileManager.h"
#import "BXEmulator+BXDOSFileSystem.h"
#import "BXEmulator+BXShell.h"
#import "UKFNSubscribeFileWatcher.h"
#import "BXMountPanelController.h"
#import "BXGrowlController.h"
#import "BXPackage.h"
#import "BXDrive.h"
#import "BXDrivesInUseAlert.h"

#import "NSWorkspace+BXMountedVolumes.h"
#import "NSWorkspace+BXFileTypes.h"
#import "NSString+BXPaths.h"


@implementation BXSession (BXFileManager)

+ (NSSet *) keyPathsForValuesAffectingDrives		{ return [NSSet setWithObject: @"emulator.mountedDrives"]; }
+ (NSSet *) keyPathsForValuesAffectingExecutables	{ return [NSSet setWithObject: @"gamePackage.executables"]; }


//Class methods concerning filetypes
//----------------------------------


//Return an array of all filetypes that should be mounted as a separate drive even if they're already accessible
//from another drive
+ (NSArray *) separatelyMountedTypes
{
	NSArray *separatelyMountedTypes = [NSArray arrayWithObjects:
		@"net.washboardabs.boxer-mountable-folder",	//Any of .floppy, .cdrom, .harddisk
		@"net.washboardabs.boxer-game-package",		//.boxer
	nil];
	return [[BXAppController mountableImageTypes] arrayByAddingObjectsFromArray: separatelyMountedTypes];
}

+ (BOOL) isExecutable: (NSString *)path
{
	return [[NSWorkspace sharedWorkspace] file: path matchesTypes: [BXAppController executableTypes]];
}


//File and folder mounting
//------------------------

- (IBAction) refreshFolders:	(id)sender	{ [[self emulator] refreshMountedDrives]; }
- (IBAction) showMountPanel:	(id)sender	{ [[BXMountPanelController controller] showMountPanelForSession: self]; }
- (IBAction) openInDOS:			(id)sender
{
	if ([sender respondsToSelector: @selector(representedObject)]) sender = [sender representedObject];
	NSString *path;
	
	//NSString paths
	if ([sender isKindOfClass: [NSString class]])			path = sender;
	//NSURLs and BXDrives
	else if ([sender respondsToSelector: @selector(path)])	path = [sender path];
	//NSDictionaries with paths
	else if ([sender isKindOfClass: [NSDictionary class]])	path = [sender objectForKey: @"path"];	
	
	if (path) [self openFileAtPath: path];	
}

- (IBAction) unmountDrive: (id)sender
{
	if ([sender respondsToSelector: @selector(representedObject)]) sender = [sender representedObject];
	if ([self shouldUnmountDrives: [NSArray arrayWithObject: sender] sender: sender])
		[[self emulator] unmountDrive: sender];
}

- (BOOL) shouldUnmountDrives: (NSArray *)drives sender: (id)sender
{
	//If the Option key was held down, bypass this check altogether and allow any drive to be unmounted
	NSUInteger optionKeyDown = [[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask;
	if (optionKeyDown) return YES;

	NSMutableArray *drivesInUse = [[NSMutableArray alloc] initWithCapacity: [drives count]];
	for (BXDrive *drive in drives)
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
							contextInfo: drives];
		return NO;
	}
	return YES;
}

- (void) drivesInUseAlertDidEnd: (BXDrivesInUseAlert *)alert
					 returnCode: (NSInteger)returnCode
					  forDrives: (NSArray *)drives
{
	[alert release];
	if (returnCode == NSAlertFirstButtonReturn) [self unmountDrives: drives];
}


- (BOOL) shouldMountDriveForPath: (NSString *)path
{
	//If the file isn't already accessible from DOS, we should mount it
	BXEmulator *theEmulator = [self emulator];
	if (![theEmulator pathIsDOSAccessible: path]) return YES;
	
	
	//If it is accessible, but is of a type that should get its own drive, mount it separately
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
	if (![manager fileExistsAtPath: path isDirectory: nil]) return nil;
	
	//Choose an appropriate mount point and create the new drive for it
	NSString *mountPoint	= [self preferredMountPointForPath: path];
	BXDrive *drive			= [BXDrive driveFromPath: mountPoint atLetter: nil];
	
	return [theEmulator mountDrive: drive];
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


- (NSString *) preferredMountPointForPath: (NSString *)filePath
{	
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	
	//If the path is a disc image, use that as the mount point.
	if ([workspace file: filePath matchesTypes: [BXAppController mountableImageTypes]]) return filePath;

	
	//If the path is (itself or inside) a gamebox or mountable folder, use that as the mount point.
	NSArray *containerTypes = [NSArray arrayWithObjects:
		@"net.washboardabs.boxer-game-package",
		@"net.washboardabs.boxer-mountable-folder",
	nil];
	NSString *container = [workspace parentOfFile: filePath matchingTypes: containerTypes];
	if (container) return container;
	

	//Check what kind of volume the file is on
	NSString *volumeType = [workspace volumeTypeForPath: filePath];

	//If it's on an audio CD, hunt around for the corresponding data CD volume and use that as the mount point (if found)
	if ([volumeType isEqualToString: audioCDVolumeType])
	{
		NSString *dataVolumePath = [workspace findDataVolumeForAudioCD: [workspace volumeForPath: filePath]];
		if (dataVolumePath) return dataVolumePath;
	}
	
	//If it's on a data CD volume, use the base folder of the volume as the mount point
	else if ([volumeType isEqualToString: dataCDVolumeType])
	{
		NSString *cdVolume = [workspace volumeForPath: filePath];
	
		//Check to see if the volume is actually mounted from a supported disc image;
		//If so, use the source image instead.
		//This option is not fully implemented downstream and is disabled for now.
		/*
		if (useSourceImage)
		{
			NSString *imagePath = [workspace sourceImageForVolume: cdVolume];
			if (imagePath && [workspace file: imagePath matchesTypes: [BXEmulator mountableImageTypes]])
				cdVolume = imagePath;
		}
		*/
		return cdVolume;
	}
	
	//If it's a floppy-sized FAT volume, also use the base folder as the mount point 
	else if ([volumeType isEqualToString: FATVolumeType])
	{
		NSString *floppyVolume = [workspace volumeForPath: filePath];
		return floppyVolume;
	}
	
	//If we get this far, then treat the path as a regular file or folder.
	BOOL isDir;
	NSFileManager *manager = [NSFileManager defaultManager];
	[manager fileExistsAtPath: filePath isDirectory: &isDir];
	
	//If the path is a folder, use it directly as the mount point...
	if (isDir) return filePath;
		
	//...otherwise use the path's parent folder.
	else return [filePath stringByDeletingLastPathComponent]; 
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
			drive = [theEmulator mountDrive: drive];
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
	NSArray *volumes = [workspace mountedVolumesOfType: FATVolumeType];
	BXEmulator *theEmulator = [self emulator];
	
	BOOL returnValue = NO;
	for (NSString *volume in volumes)
	{
		if (![theEmulator pathIsMountedAsDrive: volume] && [self _isFloppySizedVolume: volume])
		{
			BXDrive *drive = [BXDrive floppyDriveFromPath: volume atLetter: nil];
			drive = [theEmulator mountDrive: drive];
			if (drive != nil) returnValue = YES;
		}
	}
	return returnValue;
}

//Simple helper function to unmount a set of drives. Returns YES if any drives were unmounted, NO otherwise.
//Implemented just so that BXInspectorController doesn't have to know about BXEmulator+BXDOSFileSystem.
- (BOOL) unmountDrives: (NSArray *)drives
{
	BOOL succeeded = NO;
	BXEmulator *theEmulator = [self emulator];
	for (BXDrive *drive in drives)
	{
		succeeded = [theEmulator unmountDrive: drive] || succeeded;
	}
	return succeeded;
}


//Handling filesystem notifications
//---------------------------------

//Register ourselves as an observer for filesystem notifications
//Called from BXSession init
- (void) _registerForFilesystemNotifications
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSNotificationCenter *center = [workspace notificationCenter];
	
	[center addObserver:	self
			selector:		@selector(volumeDidMount:)
			name:			@"NSWorkspaceDidMountNotification"
			object:			workspace];
	
	[center addObserver:	self
			   selector:	@selector(volumeWillUnmount:)
				   name:	@"NSWorkspaceWillUnmountNotification"
				 object:	workspace];

	[center addObserver:	self
			   selector:	@selector(volumeWillUnmount:)
				   name:	@"NSWorkspaceDidUnmountNotification"
				 object:	workspace];
	
	[center addObserver:	self
			selector:		@selector(filesystemDidChange:)
			name:			UKFileWatcherWriteNotification
			object:			nil];
}

- (void) _deregisterForFilesystemNotifications
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSNotificationCenter *center = [workspace notificationCenter];

	[center removeObserver: self name: @"NSWorkspaceDidMountNotification"		object: workspace];
	[center removeObserver: self name: @"NSWorkspaceWillUnmountNotification"	object: workspace];
	[center removeObserver: self name: UKFileWatcherWriteNotification			object: nil];

}

- (void) volumeDidMount: (NSNotification *)theNotification
{
	//We decide what to do with audio CD volumes based on whether they have a corresponding
	//data volume. Unfortunately, the volumes are reported as soon as they are mounted, so
	//often the audio volume will send a mount notification before its data volume exists.
	
	//To work around this, we add a slight delay before we process the volume mount notification,
	//to allow other volumes to finish mounting.
	[self performSelector:@selector(_handleVolumeDidMount:) withObject: theNotification afterDelay: 0.1];
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
	NSString *volume		= [[theNotification userInfo] objectForKey: @"NSDevicePath"];
	NSString *volumeType	= [workspace volumeTypeForPath: volume];
	
	//Only mount volumes that are of an appropriate type
	if (![automountedTypes containsObject: volumeType]) return;
	
	//Only mount CD audio volumes if they have no corresponding data volume
	//(Otherwise, we mount the data volume instead and shadow it with the audio CD's tracks)
	if ([volumeType isEqualToString: audioCDVolumeType] && [workspace findDataVolumeForAudioCD: volume]) return;
	
	//Only mount FAT volumes that are floppydisk-sized
	if ([volumeType isEqualToString: FATVolumeType] && ![self _isFloppySizedVolume: volume]) return;
	
	//Only mount volumes that aren't already mounted as drives
	NSString *mountPoint = [self preferredMountPointForPath: volume];
	if ([[self emulator] pathIsMountedAsDrive: mountPoint]) return;
	
	//Alright, if we got this far then it's ok to mount a new drive for it
	BXDrive *drive = [BXDrive driveFromPath: mountPoint atLetter: nil];
	
	[[self emulator] mountDrive: drive];
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
	
	//Also check if the file was inside our gamebox - if so, flush the gamebox's caches
	BXPackage *package = [self gamePackage];
	if (package && [path hasPrefix: [package gamePath]])
	{
		[package setExecutables:	nil];
		[package setDocumentation:	nil];
	}
}

- (void) DOSDriveDidMount: (NSNotification *)theNotification
{
	BXDrive *drive = [[theNotification userInfo] objectForKey: @"drive"];
	if (![drive isInternal])
	{
		[self _startTrackingChangesAtPath: [drive path]];
	
		//only show notifications once the session has started up fully,
		//so we don't spray out notifications for our initial drive mounts.
		if (hasConfigured) [[BXGrowlController controller] notifyDriveMounted: drive];
	}
}

- (void) DOSDriveDidUnmount: (NSNotification *)theNotification
{
	BXDrive *drive = [[theNotification userInfo] objectForKey: @"drive"];
	if (![drive isInternal])
	{
		NSString *path = [drive path];
		//Only stop tracking if there are no other drives mapping to that path either.
		if (![[self emulator] pathIsDOSAccessible: path]) [self _stopTrackingChangesAtPath: path];
	
		//only show notifications once the session has started up fully,
		//in case something gets unmounted during startup.
		if (hasConfigured) [[BXGrowlController controller] notifyDriveUnmounted: drive];
	}
}

- (void) _startTrackingChangesAtPath: (NSString *)path
{
	NSFileManager *manager = [NSFileManager defaultManager];
	BOOL isDir, exists = [manager fileExistsAtPath: path isDirectory: &isDir];
	//Note: UKFNSubscribeFileWatcher can only watch directories, not regular files 
	if (exists && isDir)
	{
		UKFNSubscribeFileWatcher *watcher = [UKFNSubscribeFileWatcher sharedFileWatcher];
		[watcher addPath: path];
	}
}

- (void) _stopTrackingChangesAtPath: (NSString *)path
{
	UKFNSubscribeFileWatcher *watcher = [UKFNSubscribeFileWatcher sharedFileWatcher];
	[watcher removePath: path];
}

- (BOOL) _isFloppySizedVolume: (NSString *)path
{
	NSFileManager *manager = [NSFileManager defaultManager];
	NSDictionary *fsAttrs = [manager attributesOfFileSystemForPath: path error: nil];
	NSUInteger volumeSize = [[fsAttrs valueForKey: NSFileSystemSize] integerValue];
	return volumeSize <= BXFloppySizeCutoff;
}

@end