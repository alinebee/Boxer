/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXDrive represents a single DOS drive and encapsulates all the data needed to mount the drive
//and locate it on the OS X filesystem. BXDrives are mounted via BXFileSystem's mountDrive: method.

//Could be Foundation, except we use NSImage
#import <Cocoa/Cocoa.h>

enum BXDriveTypes {
	BXDriveAutodetect	= -1,
	BXDriveHardDisk		= 0,
	BXDriveFloppyDisk	= 1,
	BXDriveCDROM		= 2,
	BXDriveInternal		= 3
};

typedef NSInteger BXDriveType;

//Setting freeSpace to BXDefaultFreeSpace indicates that the drive should use whatever free space DOSBox thinks is best.
static const NSInteger BXDefaultFreeSpace = -1;

//FAT volumes smaller than 2MB will be treated as floppy drives.
static const NSInteger BXFloppySizeCutoff = 2 * 1024 * 1024;


@interface BXDrive : NSObject
{
	NSString *path;
	NSString *letter;
	NSString *label;
	BXDriveType type;
	NSUInteger freeSpace;
	BOOL usesCDAudio;
	BOOL readOnly;
	BOOL locked;
	BOOL hidden;
	NSImage *icon;
}

//Properties
//----------

//The absolute path to the source folder (or image) of the drive on the OS X filesystem.
@property (copy) NSString *path;

//The DOS drive letter under which this drive will be mounted.
//If nil, BXEmulator mountDrive: will choose an appropriate drive letter at mount time.
//This property is not prescriptive: if a drive is already mounted at the specified letter,
//BXEmulator mountDrive: may mount the drive as a different letter and modify the letter
//property of the returned drive to match.
@property (copy) NSString *letter;

//The DOS disk label to use for this drive. For folder-based drives this will be
//auto-generated from the folder's OS X filename, if not explicitly provided.
//The label does not apply to disk images, which encapsulate their own drive label.
@property (copy) NSString *label;

//The icon representing this drive. This will be taken from the drive path's filesystem icon.
@property (copy) NSImage *icon;

//The type of DOS drive to mount, as a BXDriveType constant (see above.) This will
//be auto-detected based on the source folder or image, if not explicitly provided.
@property (assign) BXDriveType type;

//The amount of free disk space to represent on the drive, in bytes. Defaults to
//BXDefaultFreeSpace: which is ~250MB for hard disks, 1.44MB for floppies and 0B for CDROMs.
@property (assign) NSUInteger freeSpace;

//Whether to use SDL CD-ROM audio: only relevant for CD-ROM drives. If YES, DOS emulation
//will read CD audio for this drive from the first audio CD volume mounted in OS X.
@property (assign) BOOL usesCDAudio;

//Whether to prevent writing to the OS X filesystem representing this drive: defaults to NO.
@property (assign) BOOL readOnly;

//Whether to protect this drive from being unmounted from the drive manager UI: defaults to NO.
//Ignored for DOSBox internal drives (which are always locked).
@property (assign, getter=isLocked) BOOL locked;

//Whether to hide this drive from Boxer's drive manager UI: defaults to NO.
//Ignored for DOSBox internal drives (which are always hidden).
@property (assign, getter=isHidden) BOOL hidden;


//Class methods
//-------------

//Returns a localised descriptive name for the specified drive type. e.g. @"hard disk", @"CD-ROM" etc. 
+ (NSString *) descriptionForType: (BXDriveType)driveType;

//Auto-detects the appropriate drive type for the specified path, based on the path's UTI and the
//filesystem of the path's volume: e.g. folders located on CD-ROM volume will be detected as CD-ROMs.
+ (BXDriveType) preferredTypeForPath:	(NSString *)filePath;

//Autogenerates a suitable DOS label for the specified path.
//For disk images, this will be nil (their volume labels are stored internally);
//For regular folders and CD-ROM volumes, this will be their filename;
//For .floppy, .cdrom and .harddisk folders, this will be their filename minus extension
//and parsed drive letter (see preferredDriveLetterForPath: below.)
+ (NSString *) preferredLabelForPath:	(NSString *)filePath;

//Parses a recommended drive letter from the specified path. For disk images and Boxer mountable folders,
//this will be the first letter of the filename if the filename starts with a single letter followed by a space.
//For regular folders and CD-ROM volumes, this will be nil (as their names are probably coincidental.)
+ (NSString *) preferredDriveLetterForPath: (NSString *)filePath;


//Initializers
//------------

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


//Describing the drive
//--------------------

//A friendly OS X title for the drive's type.
- (NSString *) typeDescription;

//A friendly OS X name for the drive's source path. This corresponds to NSManager displayNameAtPath:.
- (NSString *)displayName;


//Introspecting the drive
//-----------------------

//Returns whether the file at the specified path would be accessible in DOS from this drive.
//This is determined by checking if the base folder of this drive is a parent of the specified path. 
- (BOOL) exposesPath: (NSString *)subPath;

//Returns whether this drive is the specified drive type.
- (BOOL) isInternal;
- (BOOL) isCDROM;
- (BOOL) isFloppy;
- (BOOL) isHardDisk;


//Sort comparisons
//----------------

//Sorts drives based on how deep their source path is.
- (NSComparisonResult) pathDepthCompare: (BXDrive *)comparison;

//Sorts drives by drive letter.
- (NSComparisonResult) letterCompare: (BXDrive *)comparison;
@end