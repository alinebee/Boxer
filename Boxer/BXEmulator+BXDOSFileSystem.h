/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//The BXDOSFileSystem category extends BXEmulator to expose methods for inspecting and controlling
//the DOSBox filesystem: mounting and unmounting drives, and changing the active drive and working
//directory.


#import "BXEmulator.h"

@class BXDrive;

@interface BXEmulator (BXDOSFileSystem)

#pragma mark -
#pragma mark Properties

@property (readonly, nonatomic) NSArray *mountedDrives;

//The current DOS drive.
@property (readonly, nonatomic) BXDrive *currentDrive;

//The letter of the current drive.
@property (readonly, nonatomic) NSString *currentDriveLetter;

//The DOS path to the current working directory.
@property (readonly, nonatomic) NSString *currentWorkingDirectory;

//The local filesystem path to the current working directory on the current drive.
//Returns the drive's base path if Boxer cannot 'see into' the drive (e.g. the drive is on a disk image.)
//Returns nil if the drive does not exist on the local filesystem (e.g. it is a DOSBox-internal drive.)
@property (readonly, nonatomic) NSString *pathOfCurrentWorkingDirectory;


#pragma mark -
#pragma mark Helper class methods

+ (NSArray *) driveLetters;			//all drive letters in order, including reserved letters
+ (NSArray *) floppyDriveLetters;	//letters appropriate for floppy drives
+ (NSArray *) hardDriveLetters;		//letters appropriate for hard disk/CD-ROM drives (excludes reserved letters)

+ (NSSet *) dosFileExclusions;		//Filenames to hide from DOS directory listings


#pragma mark -
#pragma mark Mounting and unmounting drives

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


#pragma mark -
#pragma mark Converting paths to/from DOSBox

//Returns the drive mounted at the specified letter, or nil if no drive is mounted at that letter.
- (BXDrive *)driveAtLetter: (NSString *)driveLetter;

//Returns whether the drive at the specified letter is being actively used by DOS.
- (BOOL) driveInUseAtLetter: (NSString *)driveLetter;

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


#pragma mark -
#pragma mark Filesystem validation

//Returns whether the specified path is safe for DOS programs to access (i.e. not a system folder)
+ (BOOL) pathIsSafeToMount: (NSString *)thePath;

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


#pragma mark -
#pragma mark Translating between Boxer and DOSBox drives

//Returns the DOSBox drive index for a specified drive letter and vice-versa.
- (NSUInteger)_indexOfDriveLetter: (NSString *)driveLetter;
- (NSString *)_driveLetterForIndex: (NSUInteger)index;


//Returns the Boxer drive that matches the specified DOSBox drive, or nil if no drive was found.
- (BXDrive *)_driveMatchingDOSBoxDrive: (DOS_Drive *)dosDrive;

//Does the inverse of the above - returns the DOSBox drive corresponding to the specified Boxer drive.
- (DOS_Drive *)_DOSBoxDriveMatchingDrive: (BXDrive *)drive;

//Returns the local filesystem path corresponding to the specified DOS path on the specified DOSBox drive index.
//Returns nil if there is no corresponding local file (e.g. if the drive is a disk image or DOSBox-internal drive.)
- (NSString *)_filesystemPathForDOSPath: (const char *)dosPath atIndex: (NSUInteger)driveIndex;


#pragma mark -
#pragma mark Adding and removing DOSBox drives

//Registers a new drive with DOSBox and adds it to the drive list. Returns YES if the drive was successfully added,
//or NO if there was an error (e.g. there was already a drive at that index).
//TODO: should populate an optional NSError object for cases like this.
- (BOOL) _addDOSBoxDrive: (DOS_Drive *)drive atIndex: (NSUInteger)index;

//Unmounts the DOSBox drive at the specified index and clears any references to the drive.
//Returns YES if the drive was successfully removed, or NO if there was an error (e.g. there was no drive at that index.)
//TODO: should populate an optional NSError object for cases like this.
- (BOOL) _unmountDOSBoxDriveAtIndex: (NSUInteger)index;

//Generates a Boxer drive object for a drive at the specified drive index.
- (BXDrive *)_driveFromDOSBoxDriveAtIndex: (NSUInteger)index;

//Create a new DOS_Drive CDROM from a path to a disc image.
- (DOS_Drive *) _CDROMDriveFromImageAtPath:	(NSString *)path forIndex: (NSUInteger)index;
- (DOS_Drive *) _CDROMDriveFromPath:		(NSString *)path forIndex: (NSUInteger)index withAudio: (BOOL)useCDAudio;
- (DOS_Drive *) _hardDriveFromPath:			(NSString *)path freeSpace: (NSInteger)freeSpace;
- (DOS_Drive *) _floppyDriveFromPath:		(NSString *)path freeSpace: (NSInteger)freeSpace;

- (DOS_Drive *) _DOSBoxDriveFromPath: (NSString *)path
						   freeSpace: (NSInteger)freeSpace
							geometry: (BXDriveGeometry)size
							 mediaID: (NSUInteger)mediaID;

//Synchronizes Boxer's mounted drive cache with DOSBox's drive array, adding and removing drives as necessary.
- (void) _syncDriveCache;
- (void) _addDriveToCache: (BXDrive *)drive;
- (void) _removeDriveFromCache: (BXDrive *)drive;


#pragma mark -
#pragma mark Filesystem validation and notifications

//Returns whether the specified drive is being used by DOS programs.
//Currently, this means whether any files are open on that drive.
- (BOOL) _DOSBoxDriveInUseAtIndex: (NSUInteger)index;

//Decides whether to let the DOS session mount the specified path
//This checks against pathIsSafeToMount, and prints an error to the console if not
- (BOOL) _shouldMountPath: (NSString *)thePath;

//Returns whether to show files with the specified name in DOS directory listings
//This hides all files starting with . or that are in dosFileExclusions
- (BOOL) _shouldShowFileWithName: (NSString *)fileName;

//Returns whether to allow the file at the specified path to be written to or modified by DOS, via the specified drive.
- (BOOL) _shouldAllowWriteAccessToPath: (NSString *)filePath onDrive: (BXDrive *)drive;

- (void) _didCreateFileAtPath: (NSString *)filePath onDrive: (BXDrive *)drive;
- (void) _didRemoveFileAtPath: (NSString *)filePath onDrive: (BXDrive *)drive;

@end

#endif
