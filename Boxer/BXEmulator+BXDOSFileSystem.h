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
+ (NSArray *) floppyDriveLetters;	//letters appropriate for floppy drives (A-W)
+ (NSArray *) hardDriveLetters;		//letters appropriate for hard disk drives (C-W)
+ (NSArray *) CDROMDriveLetters;	//letters appropriate for CD-ROM drives (D-W)
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
//Call DOSPathForPath: if you need the actual DOS path; this is just a quick
//way of determining if a volume is mounted at all.
- (BOOL) pathIsDOSAccessible: (NSString *)path;

//Returns the 'best match' drive on which the specified path is accessible.
//(If a path is accessible on several drives, this will return the 'deepest-nested' drive,
//to handle gameboxes that have additional drives inside them. 
- (BXDrive *) driveForPath: (NSString *)path;

//Returns the standardized DOS path corresponding to the specified real path,
//or nil if the path is not currently accessible from DOS.
- (NSString *) DOSPathForPath: (NSString *)path;
- (NSString *) DOSPathForPath: (NSString *)path onDrive: (BXDrive *)drive;

//Returns the real filesystem path corresponding to the specified DOS path.
//This may return the base path of the drive instead, if the specified DOS path
//resides on an image or is otherwise inaccessible to the local filesystem.
//Will return nil if the path could not be resolved.
- (NSString *) pathForDOSPath: (NSString *)path;

#pragma mark -
#pragma mark Filesystem validation

//Returns whether the specified path is safe for DOS programs to access (i.e. not a system folder)
+ (BOOL) pathIsSafeToMount: (NSString *)thePath;

@end
