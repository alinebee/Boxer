/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//The BXDOSFileSystem category extends BXEmulator to expose methods for inspecting and controlling
//the DOSBox filesystem: mounting and unmounting drives, and changing the active drive and working
//directory.


#import "BXEmulator.h"

//The maximum number of CD-ROM drives supported by MSCDEX.
//Drives beyond this will fail to mount.
#define BXMaxCDROMDrives 7


@class BXDrive;

@interface BXEmulator (BXDOSFileSystem)

#pragma mark -
#pragma mark Properties

//The drives currently mounted in DOS. These are not intrinsically ordered.
@property (readonly, nonatomic) NSArray *mountedDrives;

//The current DOS drive.
@property (readonly, nonatomic) BXDrive *currentDrive;

//The letter of the current drive.
@property (readonly, nonatomic) NSString *currentDriveLetter;

//The DOS path to the current directory.
@property (readonly, nonatomic) NSString *currentDirectory;

//The OS X filesystem location of the current directory on the current drive.
//In the case of disk images, this will return the URL of the disk image itself.
//Returns nil if the location of the directory cannot be resolved at all
//(e.g. because the current drive is a virtual drive.)
@property (readonly, nonatomic) NSURL *currentDirectoryURL;


#pragma mark -
#pragma mark Helper class methods

+ (NSArray *) driveLetters;			//all drive letters in order, including reserved letters
+ (NSArray *) floppyDriveLetters;	//letters appropriate for floppy drives (A-W)
+ (NSArray *) hardDriveLetters;		//letters appropriate for hard disk drives (C-W)
+ (NSArray *) CDROMDriveLetters;	//letters appropriate for CD-ROM drives (D-W)


//Generates a drive from the specified mount/imgmount command string,
//with or without the mount/imgmount command name.
//If baseURL is specified, relative paths in the command will be resolved
//relative to that.
//Returns nil and populates outError if the mount command could not be parsed.
+ (BXDrive *) driveFromMountCommand: (NSString *)mountCommand
                      relativeToURL: (NSURL *)baseURL
                              error: (NSError **)outError;


#pragma mark -
#pragma mark Mounting and unmounting drives

//Mount the specified drive as a new DOS drive, autodetecting the appropriate drive letter if needed.
//Returns the drive, updated to match the chosen drive letter, or nil and populates outError if the drive
//could not be mounted.
- (BXDrive *) mountDrive: (BXDrive *)drive
                   error: (NSError **)outError;

//Unmount the specified drive letter. Returns YES if drive was successfully unmounted, 
//or NO and populates outError otherwise.
//If force is YES, the drive will be unmounted even if it is currently in use.
- (BOOL) unmountDrive: (BXDrive *)drive
                force: (BOOL)force
                error: (NSError **)outError;

//Release any open resources for the specified drive, without unmounting the drive itself.
//Returns YES if successful, NO and populates outError on failure.
//Note that doing this may cause DOS programs that are using those resources to crash:
//this should only be called as a prelude to terminating or restarting the DOS session.
- (BOOL) releaseResourcesForDrive: (BXDrive *)drive error: (NSError **)outError;

//Flush the DOS filesystem cache and rescan to synchronise it with the local filesystem state.
- (void) refreshMountedDrives;

//Returns the preferred available drive letter to which the specified path should be mounted,
//or nil if no letters are available.
- (NSString *) preferredLetterForDrive: (BXDrive *)drive;


#pragma mark -
#pragma mark Drive introspection

//Returns whether the specified drive is currently mounted in DOS.
- (BOOL) driveIsMounted: (BXDrive *)drive;

//Returns whether the specified drive is currently in use in DOS.
- (BOOL) driveInUse: (BXDrive *)drive;

//Returns the drive mounted at the specified letter, or nil if no drive is mounted at that letter.
- (BXDrive *)driveAtLetter: (NSString *)driveLetter;

//Returns whether the drive at the specified letter is being actively used by DOS.
- (BOOL) driveInUseAtLetter: (NSString *)driveLetter;


#pragma mark - Converting paths from the OS X filesystem to DOS

//Returns the 'best match' drive on which the specified OS X filesystem path is accessible,
//or nil if no drive contains the specified URL. This is slower than URLIsAccessibleInDOS:
//so use that if you don't need to know which drive.
- (BXDrive *) driveContainingLogicalURL: (NSURL *)URL;

//Returns whether the specified OS X filesystem resource is exposed by any DOS drive.
- (BOOL) logicalURLIsAccessibleInDOS: (NSURL *)URL;

//Returns whether any mounted drive uses the specified URL directly as its source.
- (BOOL) logicalURLIsMountedInDOS: (NSURL *)URL;

//Returns the standardized DOS path corresponding to the specified OS X filesystem resource,
//or nil if that resource is not currently accessible from DOS.
- (NSString *) DOSPathForLogicalURL: (NSURL *)URL;
- (NSString *) DOSPathForLogicalURL: (NSURL *)URL onDrive: (BXDrive *)drive;

//Returns the actual OS X filesystem URL corresponding to the specified DOS path.
//Returns nil if the file does not exist or is not accessible via the OS X filesystem.
- (NSURL *) fileURLForDOSPath: (NSString *)dosPath;

//Returns the logical URL representing the specified DOS path.
- (NSURL *) logicalURLForDOSPath: (NSString *)dosPath;


#pragma mark Resolving DOS paths

//Returns whether the specified DOS path exists within the DOS filesystem.
- (BOOL) DOSPathExists: (NSString *)dosPath;

//Returns the drive upon which the specified DOS path is found.
- (BXDrive *) driveForDOSPath: (NSString *)path;

//Given a DOS path relative to the current drive and working directory,
//returns a fully-resolved DOS path including complete drive letter.
- (NSString *) resolvedDOSPath: (NSString *)path;

@end



#pragma mark - Legacy API

//This is the old NSString-based API for handling OS X file paths, which has been replaced with the NSURL-based API above.
//It will be removed once all legacy code has been ported.

@interface BXEmulator (BXDOSFilesystemLegacyPathAPI)

//Returns whether the specified OS X path exists within the DOS filesystem.
- (BOOL) pathExistsInDOS: (NSString *)path __deprecated;

//Returns the standardized DOS path corresponding to the specified real path,
//or nil if the path is not currently accessible from DOS.
- (NSString *) DOSPathForPath: (NSString *)path __deprecated;
- (NSString *) DOSPathForPath: (NSString *)path onDrive: (BXDrive *)drive __deprecated;

@end