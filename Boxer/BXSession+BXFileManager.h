/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXFileManager category extends BXSession with methods for controlling the DOS filesystem
//and for responding to relevant changes in the OS X filesystem. It implements Boxer's policies
//for opening files and folders from the OS X filesystem and creating new drives for them.

#import "BXSession.h"
#import "BXFileTransferDelegate.h"

@class BXDrive;
@class BXDrivesInUseAlert;
@class BXFileTransfer;

@interface BXSession (BXFileManager) <BXEmulatorFileSystemDelegate, BXFileTransferDelegate>

#pragma mark -
#pragma mark Filetype-related class methods

//UTI filetypes of folders that should be used as mount-points for files inside them: if we open a file
//inside a folder matching one of these types, it will mount that folder as its drive.
//Used by preferredMountPointForPath: which will also prefer the root folders of floppy and CD-ROM volumes.
+ (NSSet *) preferredMountPointTypes;


//UTI filetypes that should be given their own drives, even if they are already accessible within an existing DOS drive.
//This is used by shouldMountDriveForPath: to allow disc images or drive folders inside a gamebox to be mounted as
//separate drives even when their containing gamebox is already mounted.
+ (NSSet *) separatelyMountedTypes;

//Returns whether the specified OS X path represents a DOS/Windows executable.
+ (BOOL) isExecutable: (NSString *)path;


#pragma mark -
#pragma mark File and folder mounting

//Tells the emulator to flush its DOS drive caches to reflect changes in the OS X filesystem.
//No longer used, since we explicitly listen for changes to the underlying filesystem and do this automatically.
- (IBAction) refreshFolders:	(id)sender;

//Display the mount-a-new-drive sheet in this session's window.
- (IBAction) showMountPanel:	(id)sender;

//Open the represented object of the sender in DOS.
- (IBAction) openInDOS:			(id)sender;

//Unmount the represented object of the sender (assumed to be a BXDrive). 
- (IBAction) unmountDrive:		(id)sender;

//Returns whether the specified drives are allowed to be unmounted.
//This may display a confirmation sheet and return NO.
- (BOOL) shouldUnmountDrives:	(NSArray *)selectedDrives sender: (id)sender;

//Called when the "are you sure you want to unmount this drive?" alert is closed.
- (void) drivesInUseAlertDidEnd: (BXDrivesInUseAlert *)alert
					 returnCode: (NSInteger)returnCode
					  forDrives: (NSArray *)selectedDrives;

//Returns whether the specified path should be mounted as a new drive.
//Returns YES if the path isn't already DOS-accessible or deserves its own drive anyway, NO otherwise.
- (BOOL) shouldMountDriveForPath: (NSString *)path;

//Adds a new drive to expose the specified path, using preferredMountPointForPath:
//to choose an appropriate base location for the drive.
- (BXDrive *) mountDriveForPath: (NSString *)path;


//Open the file at the specified path in DOS.
//If path is an executable, it will be launched; otherwise, we'll just change the working directory to it.
- (BOOL) openFileAtPath: (NSString *)path;

//Returns the most appropriate base location for a drive to expose the specified path:
//If path points to a disc image, that will be returned
//If path is inside a gamebox or Boxer mountable folder type, that container will be returned.
//If path is on a CD or floppy volume, then the volume will be returned.
//Otherwise, the parent folder of the item, or the item itself if it is a folder, will be returned. 
- (NSString *) preferredMountPointForPath: (NSString *)path;

//Given an arbitrary target path, returns the most appropriate base location from which to start searching for games:
//If path is inside a gamebox or Boxer mountable folder type, that container will be returned (and shouldRecurse will be YES).
//If path is on a CD or floppy volume, then the volume will be returned (and shouldRecurse will be YES).
//Otherwise, the parent folder of the item, or the item itself if it is a folder, will be returned (and shouldRecurse will be NO). 
- (NSString *) gameDetectionPointForPath: (NSString *)path shouldSearchSubfolders: (BOOL *)shouldRecurse;

//Automount all ISO9660 CD-ROM volumes that are currently mounted in OS X.
//Will not create new mounts for ones that are already mounted.
//Returns YES if any new volumes were created, NO otherwise.
- (BOOL) mountCDVolumes;

//Mount all floppy-sized FAT volumes that are currently mounted in OS X.
//Will not create new mounts for ones that are already mounted.
//Returns YES if any drives were mounted, NO otherwise.
- (BOOL) mountFloppyVolumes;

//Unmount the BXDrives in the specified array.
- (BOOL) unmountDrives: (NSArray *)selectedDrives;


#pragma mark -
#pragma mark Drive importing

//Returns whether the specified drive is located inside the session's gamebox.
- (BOOL) driveIsBundled: (BXDrive *)drive;

//Returns whether the specified drive

//Returns whether the specified drive can be imported.
//Will be NO if:
//- there is no gamebox for this session
//- the drive is a DOSBox/Boxer-internal drive
//- the drive has already been or is currently being imported
- (BOOL) canImportDrive: (BXDrive *)drive;

//Imports the specified drive to a bundled drive folder in the gamebox.
//This will occur asynchronously using a BXFileTransfer, which is returned by this method.
//Will return nil if the drive cannot be imported.
- (BXFileTransfer *) beginImportForDrive: (BXDrive *)drive;

//Cancel the in-progress import of the specified drive. Returns YES if the import was cancelled,
//NO if the import had already finished or the drive was not being imported.
- (BOOL) cancelImportForDrive: (BXDrive *)drive;

@end


//These methods should not be called outside BXSession
@interface BXSession (BXFileManagerInternals)

- (void) _registerForFilesystemNotifications;
- (void) _deregisterForFilesystemNotifications;

@end
