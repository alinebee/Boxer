/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//The BXDOSFileSystem category extends BXEmulator to expose methods for inspecting and controlling
//the DOSBox filesystem: mounting and unmounting drives, and changing the active drive and working
//directory.

#import <Cocoa/Cocoa.h>
#import "BXEmulator.h"


@class BXDrive;

@interface BXEmulator (BXDOSFileSystem)

//Class methods for reporting accepted values
//-------------------------------------------

+ (NSArray *) executableTypes;		//UTIs that the file system can execute

+ (NSArray *) mountableImageTypes;	//UTIs of disk image formats that the file system can mount
+ (NSArray *) mountableFolderTypes;	//UTIs of folder formats that the file system can mount
+ (NSArray *) mountableTypes;		//UTIs that the file system can mount (union of the above two)

+ (NSArray *) driveLetters;			//all drive letters, including reserved letters
+ (NSArray *) floppyDriveLetters;	//letters appropriate for floppy drives
+ (NSArray *) hardDriveLetters;		//letters appropriate for hard disk/CD-ROM drives (excludes reserved letters)


//Instance methods for mounting drives
//------------------------------------

//Mount the specified drive as a new DOS drive, autodetecting the appropriate drive letter if needed.
//Returns the drive, updated to match the chosen drive letter, or nil if the drive could not be mounted.
- (BXDrive *) mountDrive: (BXDrive *)drive;

//Unmount the specified drive letter. Returns YES if drive was successfully unmounted, NO otherwise.
- (BOOL) unmountDrive: (BXDrive *)drive;

//Unmount the drive at the specified letter. Returns YES if drive was successfully unmounted, NO otherwise.
- (BOOL) unmountDriveAtLetter: (NSString *)letter;

//Unmount all drives matching the specified path. Returns YES if any drives were successfully unmounted, NO otherwise.
- (BOOL) unmountDrivesForPath: (NSString *)path;


//Flush the DOS filesystem cache and rescan to synchronise it with the local filesystem state.
- (void) refreshMountedDrives;

//Returns the preferred available drive letter to which the specified path should be mounted,
//or nil if no letters are available.
- (NSString *) preferredLetterForDrive: (BXDrive *)drive;


//Methods for introspecting DOS mounts and OS X paths 
//---------------------------------------------------

//Returns the drive mounted at the specified letter, or nil if no drive is mounted at that letter.
- (BXDrive *)driveAtLetter: (NSString *)driveLetter;

//Returns an array of mounted drives as BXDrive objects.
- (NSArray *) mountedDrives;

//Returns the number of drives currently mounted, including internal drives.
- (NSUInteger) numDrives;

//Returns an array of mounted drive letters as NSStrings.
- (NSArray *) mountedDriveLetters;

//Returns whether a drive exists at the specified drive letter.
- (BOOL) driveExistsAtLetter: (NSString *)driveLetter;


//Returns YES if the specified OS X path is explicitly mounted as its own DOS drive; NO otherwise.
//Use pathIsDOSAccessible below if you want to know if a path is accessible on any DOS drive.
- (BOOL) pathIsMountedAsDrive: (NSString *)path;

//Returns YES if the specified OS X path is accessible in DOS, NO otherwise.
//Call DOSPathForPath: if you need the actual DOS path; this is just a quick way of determining if a volume is mounted at all.
- (BOOL) pathIsDOSAccessible: (NSString *)path;

//Returns the 'best match' drive on which the specified path is accessible.
//(If a path is accessible on several drives, this will return the 'deepest-nested' drive,
//to handle gameboxes that have additional drives inside them. 
- (BXDrive *) driveForPath: (NSString *)path;

//Returns the standardized DOS path corresponding to the specified real path,
//or nil if the path is not currently accessible from DOS.
- (NSString *) DOSPathForPath: (NSString *)path;
- (NSString *) DOSPathForPath: (NSString *)path onDrive: (BXDrive *)drive;


//Methods for performing filesystem tasks
//---------------------------------------

//Returns a BXDrive record for the current drive.
- (BXDrive *) currentDrive;

//Returns the letter of the current drive.
- (NSString *) currentDriveLetter;

//Change to the specified drive letter. This will not alter the working directory on that drive.
//Returns YES if the working drive was changed, NO if the specified drive was not mounted.
- (BOOL) changeToDriveLetter: (NSString *)driveLetter;

//Change directory to the specified DOS path, which may include a drive letter.
- (BOOL) changeWorkingDirectoryToPath: (NSString *)dosPath;


//Filesystem validation
//---------------------

//Returns whether the specified path is safe for DOS programs to access (i.e. not a system folder)
+ (BOOL) pathIsSafeToMount: (NSString *)thePath;

//Decides whether to let the DOS session mount the specified path
//This checks against pathIsSafeToMount, and prints an error to the console if not
- (BOOL) shouldMountPath: (NSString *)thePath;

@end



#if __cplusplus

typedef struct BXDriveGeometry {
	NSUInteger bytesPerSector;
	NSUInteger sectorsPerCluster;
	NSUInteger numClusters;
	NSUInteger freeClusters;
} BXDriveGeometry;

class DOS_Drive;

//Methods in this category should not be called from outside of BXEmulator. Like, really, I mean it this time.
//Indeed, this category will not even be seen by other classes, since it is only visible to Objective C++ files.
@interface BXEmulator (BXDOSFileSystemInternals)

- (NSUInteger)_indexOfDriveLetter: (NSString *)driveLetter;
- (BXDrive *)_driveAtIndex: (NSUInteger)index;

- (void) _addDOSBoxDrive: (DOS_Drive *)drive atIndex: (NSUInteger)index;
- (BOOL) _unmountDriveAtIndex: (NSUInteger)index;

- (DOS_Drive *) _CDROMDriveFromImageAtPath:	(NSString *)path forIndex: (NSUInteger)index;
- (DOS_Drive *) _CDROMDriveFromPath:		(NSString *)path forIndex: (NSUInteger)index withAudio: (BOOL)useCDAudio;
- (DOS_Drive *) _hardDriveFromPath:			(NSString *)path freeSpace: (NSInteger)freeSpace;
- (DOS_Drive *) _floppyDriveFromPath:		(NSString *)path freeSpace: (NSInteger)freeSpace;

- (DOS_Drive *) _DOSBoxDriveFromPath: (NSString *)path
						   freeSpace: (NSInteger)freeSpace
							geometry: (BXDriveGeometry)size
							 mediaID: (NSUInteger)mediaID;

@end
#endif