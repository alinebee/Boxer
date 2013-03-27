/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXDrive represents a single DOS drive and encapsulates all the data needed to mount the drive
//and locate it on the OS X filesystem. BXDrives are mounted via ADBFilesystem's mountDrive: method.

#import <Foundation/Foundation.h>


#pragma mark -
#pragma mark Constants

typedef enum {
	BXDriveAutodetect	= -1,
	BXDriveHardDisk		= 0,
	BXDriveFloppyDisk	= 1,
	BXDriveCDROM		= 2,
	BXDriveInternal		= 3
} BXDriveType;

//Setting freeSpace to BXDefaultFreeSpace indicates that the drive should use whatever free space DOSBox thinks is best.
#define BXDefaultFreeSpace -1


#pragma mark -
#pragma mark Interface

@protocol ADBFilesystemPathAccess;
@interface BXDrive : NSObject
{
	NSString *_path;
    NSString *_shadowPath;
	NSString *_mountPoint;
	NSMutableSet *_pathAliases;
    
	NSString *_letter;
	NSString *_title;
	NSString *_volumeLabel;
    NSString *_DOSVolumeLabel;
	BXDriveType _type;
	NSInteger _freeSpace;
	BOOL _usesCDAudio;
	BOOL _readOnly;
	BOOL _locked;
	BOOL _hidden;
    BOOL _mounted;
    
    BOOL _hasAutodetectedMountPoint;
    BOOL _hasAutodetectedLetter;
    BOOL _hasAutodetectedTitle;
    BOOL _hasAutodetectedVolumeLabel;
    BOOL _hasAutodetectedType;
    
    id <ADBFilesystemPathAccess> _filesystem;
}


#pragma mark - Properties

//The absolute path on the OS X filesystem which represents this drive.
//This may or may not be the same as the path that gets mounted in DOS:
//see mountPoint below.
@property (copy, nonatomic) NSString *path;

//An optional absolute path on the OS X filesystem to which we will perform
//shadow write operations for this drive. That is, any files that are
//opened for modification on this drive will be silently written to this
//location instead of creating/modifying files in the original path.
@property (copy, nonatomic) NSString *shadowPath;

//The absolute path to the source file or folder that will get mounted
//in DOS for this drive. Usually this is the same as path, but may differ
//for drive packages.
@property (copy, nonatomic) NSString *mountPoint;

//A set of other OS X filesystem paths which represent this drive, used
//when resolving DOS paths or determining if a drive is already mounted.
//This is mainly used for matching up paths on the OS X volume for an ISO
//that is mounted in DOS.
@property (readonly, retain, nonatomic) NSMutableSet *pathAliases;

//The DOS drive letter under which this drive will be mounted.
//If nil, BXEmulator will choose an appropriate drive letter at mount time
//(and update this property with the chosen letter).
@property (copy, nonatomic) NSString *letter;

//The display title to show for this drive in drive lists. Automatically derived
//from the filename of the source URL, but can be modified.
@property (copy, nonatomic) NSString *title;

//The volume label to use for this drive in DOS. Automatically derived from the filename
//of the source URL, but can be modified. For image-based drives this value is ignored,
//since the volume label is stored inside the image itself.
@property (copy, nonatomic) NSString *volumeLabel;

//The volume label that the drive ended up with after mounting in DOS.
//This is populated by BXEmulator when the drive is first mounted and will be a munged
//version of the above: cropped to 11 characters and uppercased for most drive types.
@property (copy, nonatomic) NSString *DOSVolumeLabel;

//The amount of free disk space to report for the drive, in bytes. Defaults to
//BXDefaultFreeSpace: which is ~250MB for hard disks, 1.44MB for floppies and 0B for CDROMs.
//Note that this is not an enforced limit: it only affects how much free space is reported
//to DOS programs.
@property (assign, nonatomic) NSInteger freeSpace;

//Whether to use SDL CD-ROM audio: only relevant for folders mounted as CD-ROM drives.
//If YES, DOS emulation will read CD audio for this drive from the first audio CD volume mounted in OS X.
@property (assign, nonatomic) BOOL usesCDAudio;

//Whether to prevent DOS from writing to the OS X filesystem representing this drive. Defaults to NO.
@property (assign, nonatomic, getter=isReadOnly) BOOL readOnly;

//Whether to protect this drive from being unmounted from Boxer's drive manager UI. Defaults to NO.
//Ignored for DOSBox's Z drive, which is always locked.
@property (assign, nonatomic, getter=isLocked) BOOL locked;

//Whether to hide this drive from Boxer's drive manager UI. Defaults to NO.
//Ignored for DOSBox's Z drive, which is always hidden.
@property (assign, nonatomic, getter=isHidden) BOOL hidden;

//Whether this drive is currently mounted in an emulation session.
//This is merely a flag to make displaying the state of a drive easier; setting it to YES
//will not actually mount the drive, just indicate that it is mounted somewhere.
@property (assign, nonatomic, getter=isMounted) BOOL mounted;


#pragma mark - Immutable properties

//The type of DOS drive that was mounted.
//Determined at drive creation and cannot be changed afterward.
@property (readonly, nonatomic) BXDriveType type;

//Returns whether this drive is the specified drive type.
@property (readonly, nonatomic) BOOL isInternal;
@property (readonly, nonatomic) BOOL isCDROM;
@property (readonly, nonatomic) BOOL isFloppy;
@property (readonly, nonatomic) BOOL isHardDisk;

//A filesystem instance appropriate for the backing medium of this drive.
@property (readonly, retain, nonatomic) id <ADBFilesystemPathAccess> filesystem;

//A friendly OS X title for the drive's type.
@property (readonly, nonatomic) NSString *typeDescription;

//A friendly OS X name for the drive's source path. This corresponds to NSManager displayNameAtPath:.
@property (readonly, nonatomic) NSString *displayName;


#pragma mark - Class methods

//Returns a localised descriptive name for the specified drive type. e.g. @"hard disk", @"CD-ROM" etc. 
+ (NSString *) descriptionForType: (BXDriveType)driveType;

//Auto-detects the appropriate drive type for the specified path, based on the path's UTI and the
//filesystem of the path's volume: e.g. folders located on CD-ROM volume will be detected as CD-ROMs.
+ (BXDriveType) preferredTypeForPath: (NSString *)filePath;

//Autogenerates a suitable DOS volume label for the specified path.
//For regular folders and CD-ROM volumes, this will be their filename;
//For .floppy, .cdrom, .cdmedia and .harddisk folders, this will be their filename
//minus extension and parsed drive letter (see preferredDriveLetterForPath: below.)
+ (NSString *) preferredVolumeLabelForPath: (NSString *)filePath;

//Autogenerates a suitable display title for the specified path.
//This is currently the base filename of the path, including file extension.
+ (NSString *) preferredTitleForPath: (NSString *)filePath;

//Parses a recommended drive letter from the specified path. For disk images and Boxer mountable folders,
//this will be the first letter of the filename if the filename starts with a single letter followed by a space.
//For regular folders and CD-ROM volumes, this will be nil (as their names are probably coincidental.)
+ (NSString *) preferredDriveLetterForPath: (NSString *)filePath;

//Returns the path that will actually be mounted when creating a drive with the specified path.
//This is usually the same as the path itself, but may differ for disk bundles.
+ (NSString *) mountPointForPath: (NSString *)filePath;


#pragma mark -
#pragma mark Initializers

//Initialise a retained drive with the specified parameters.
- (id) initFromPath: (NSString *)drivePath atLetter: (NSString *)driveLetter withType: (BXDriveType)driveType;

//Return a new nonretained drive with the specified parameters.
+ (id) driveFromPath: (NSString *)drivePath atLetter: (NSString *)driveLetter withType: (BXDriveType)driveType;

//Return a new nonretained drive, autodetecting the appropriate drive type.
+ (id) driveFromPath: (NSString *)drivePath atLetter: (NSString *)driveLetter;

//Return a new nonretained drive initialized as the appropriate type.
+ (id) CDROMFromPath:		(NSString *)drivePath atLetter: (NSString *)driveLetter;
+ (id) floppyDriveFromPath: (NSString *)drivePath atLetter: (NSString *)driveLetter;
+ (id) hardDriveFromPath:	(NSString *)drivePath atLetter: (NSString *)driveLetter;
+ (id) internalDriveAtLetter: (NSString *)driveLetter;


#pragma mark -
#pragma mark Introspecting the drive

//Returns whether the file at the specified path is equivalent to this drive.
//This is mostly used for determining whether a path is already mounted as a DOS drive.
- (BOOL) representsPath: (NSString *)basePath;

//Returns whether the file at the specified path would be accessible in DOS from this drive.
//This is determined by checking if the mount path of this drive is a parent of the
//specified path. 
- (BOOL) exposesPath: (NSString *)subPath;

//Returns the location of the specified path relative to the root of the drive,
//or nil if the specified path was not present on this drive.
//Used by BXDOSFileSystem for matching OS X filesystem paths with DOS filesystem paths.
- (NSString *) relativeLocationOfPath: (NSString *)realPath;


#pragma mark -
#pragma mark Sort comparisons

//Sorts drives based on how deep their source path is.
- (NSComparisonResult) pathDepthCompare: (BXDrive *)comparison;

//Sorts drives by drive letter.
- (NSComparisonResult) letterCompare: (BXDrive *)comparison;

@end
