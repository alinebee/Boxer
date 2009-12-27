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

#import "NSWorkspace+BXMountedVolumes.h"
#import "NSWorkspace+BXFileTypes.h"
#import "NSString+BXPaths.h"


@implementation BXSession (BXFileManager)

+ (NSSet *) keyPathsForValuesAffectingDrives			{ return [NSSet setWithObject: @"emulator.mountedDrives"]; }
+ (NSSet *) keyPathsForValuesAffectingExecutables		{ return [NSSet setWithObject: @"gamePackage.executables"]; }


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
	[[self emulator] unmountDrive: sender];
}


//Returns the currently mounted drives, filtered to hide internal drives
- (NSArray *) drives
{
	NSArray *drives = [[self emulator] mountedDrives];
	NSPredicate *isNotInternal = [NSPredicate predicateWithFormat:@"isInternal == NO && isHidden == NO"];

	return [drives filteredArrayUsingPredicate: isNotInternal];
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
		//Note what file it was also, so we can track it internally
		[self setActiveProgramPath: path];
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

	//If it's on an audio CD, hunt around for the corresponding data CD volume and use that as the mount point (if found.)
	if ([volumeType isEqualToString: audioCDVolumeType])
	{
		NSString *dataVolumePath = [workspace findDataVolumeForAudioCD: [workspace volumeForPath: filePath]];
		if (dataVolumePath) return dataVolumePath;
	}
	
	//Otherwise if it's on a CD volume, use that as the mount point.
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
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSArray *mountedCDs = [workspace mountedVolumesOfType: dataCDVolumeType];
	BXEmulator *theEmulator = [self emulator];
	
	BOOL returnValue = NO;
	for (NSString *mountedCD in mountedCDs)
	{
		if (![theEmulator pathIsMountedAsDrive: mountedCD])
		{
			BXDrive *drive = [BXDrive CDROMFromPath: mountedCD atLetter: nil];
			drive = [theEmulator mountDrive: drive];
			if (drive != nil) returnValue = YES;
		}
	}
	return returnValue;
}

//Simple helper function to unmount a set of drives. Returns YES if any drives were unmounted, NO otherwise.
//Implemented just so that BXInspectorController doesn't have to know about BXEmulator+BXDOSFileSystem or BXEmulator+BXShell.
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
	BXEmulator *theEmulator = [self emulator];
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSNotificationCenter *center = [workspace notificationCenter];
	
	[center addObserver:	self
			selector:		@selector(volumeDidMount:)
			name:			@"NSWorkspaceDidMountNotification"
			object:			workspace];
	
	[center addObserver:	self
			selector:		@selector(volumeDidUnmount:)
			name:			@"NSWorkspaceDidUnmountNotification"
			object:			workspace];
	
	[center addObserver:	self
			selector:		@selector(DOSDriveDidMount:)
			name:			@"BXDriveDidMountNotification"
			object:			theEmulator];
			
	[center addObserver:	self
			selector:		@selector(DOSDriveDidUnmount:)
			name:			@"BXDriveDidUnmountNotification"
			object:			theEmulator];

	[center addObserver:	self
			selector:		@selector(filesystemDidChange:)
			name:			UKFileWatcherWriteNotification
			object:			nil];
}

- (void) _deregisterForFilesystemNotifications
{
	BXEmulator *theEmulator = [self emulator];
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSNotificationCenter *center = [workspace notificationCenter];

	[center removeObserver: self name: @"NSWorkspaceDidMountNotification"	object: workspace];
	[center removeObserver: self name: @"NSWorkspaceDidUnmountNotification"	object: workspace];
	[center removeObserver: self name: @"BXDriveDidMountNotification"		object: theEmulator];
	[center removeObserver: self name: @"BXDriveDidUnmountNotification"		object: theEmulator];
	[center removeObserver: self name: UKFileWatcherWriteNotification		object: nil];

}

- (void) volumeDidUnmount: (NSNotification *)theNotification
{
	NSString *volumePath = [[theNotification userInfo] objectForKey: @"NSDevicePath"];
	[[self emulator] unmountDrivesForPath: volumePath];
}

- (void) volumeDidMount: (NSNotification *)theNotification
{
	//Ignore mounts if we currently have the mount panel open;
	//we assume that the user will want to handle the new volume manually.
	NSWindow *attachedSheet = [[self windowForSheet] attachedSheet];
	if (![attachedSheet isMemberOfClass: [NSOpenPanel class]])
	{
		NSWorkspace *workspace	= [NSWorkspace sharedWorkspace];
		NSString *volumePath	= [[theNotification userInfo] objectForKey: @"NSDevicePath"];
		
		//Only auto-mount CD-ROM volumes, and only if they're not already mounted
		if ([[workspace volumeTypeForPath: volumePath] isEqualToString: dataCDVolumeType]
			&& ![[self emulator] pathIsDOSAccessible: volumePath])
		{
			NSString *mountPoint = [self preferredMountPointForPath: volumePath];
			BXDrive *drive = [BXDrive CDROMFromPath: mountPoint atLetter: nil];
			
			[[self emulator] mountDrive: drive];
		}
	}
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
	[self _startTrackingChangesAtPath: [drive path]];
	
	//only show notifications once the session has started up fully,
	//so we don't spray out notifications for our initial drive mounts
	if (hasConfigured) [[BXGrowlController controller] notifyDriveMounted: drive];
}

- (void) DOSDriveDidUnmount: (NSNotification *)theNotification
{
	BXDrive *drive = [[theNotification userInfo] objectForKey: @"drive"];
	NSString *path = [drive path];
	//Only stop tracking if there are no other drives mapping to that path either
	if (![[self emulator] pathIsDOSAccessible: path]) [self _stopTrackingChangesAtPath: path];
	
	//only show notifications once the session has started up fully,
	//just in case we have to unmount something during launch
	if (hasConfigured) [[BXGrowlController controller] notifyDriveUnmounted: drive];
}

- (void) _startTrackingChangesAtPath: (NSString *)path
{
	UKFNSubscribeFileWatcher *watcher = [UKFNSubscribeFileWatcher sharedFileWatcher];
	[watcher addPath: path];
}

- (void) _stopTrackingChangesAtPath: (NSString *)path
{
	UKFNSubscribeFileWatcher *watcher = [UKFNSubscribeFileWatcher sharedFileWatcher];
	[watcher removePath: path];
}

@end