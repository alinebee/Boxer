/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDrive.h"
#import "BXAppController.h"
#import "NSWorkspace+BXMountedVolumes.h"
#import "NSWorkspace+BXFileTypes.h"
#import "NSString+BXPaths.h"
#import "RegexKitLite.h"

@implementation BXDrive
@synthesize path, letter, label, icon;
@synthesize type, freeSpace;
@synthesize usesCDAudio, readOnly, locked, hidden;


//Pretty much all our properties depend on our path, so we add it here
+ (NSSet *)keyPathsForValuesAffectingValueForKey: (NSString *)key
{
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey: key];
	if (![key isEqualToString: @"path"]) keyPaths = [keyPaths setByAddingObject: @"path"];
	return keyPaths;
}

+ (NSString *) descriptionForType: (BXDriveType)driveType
{
	static NSArray *descriptions = nil;
	if (!descriptions) descriptions = [[NSArray alloc] initWithObjects:
		NSLocalizedString(@"hard drive",			@"Label for hard disk mounts."),				//BXDriveTypeHardDisk
		NSLocalizedString(@"floppy drive",			@"Label for floppy-disk mounts."),				//BXDriveTypeFloppyDisk
		NSLocalizedString(@"CD-ROM drive",			@"Label for CD-ROM drive mounts."),				//BXDriveTypeCDROM
		NSLocalizedString(@"internal system disk",	@"Label for DOSBox virtual drives (i.e. Z)."),	//BXDriveTypeInternal
	nil];
	if (driveType >= 0 && driveType < (NSInteger)[descriptions count]) return [descriptions objectAtIndex: driveType];
	else return NSLocalizedString(@"unknown drive type", @"Label for drive mounts of an unknown type (should never happen).");
}

+ (BXDriveType) preferredTypeForPath: (NSString *)filePath
{	
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	if ([workspace file: filePath matchesTypes: [BXAppController cdVolumeTypes]])		return BXDriveCDROM;
	if ([workspace file: filePath matchesTypes: [BXAppController floppyVolumeTypes]])	return BXDriveFloppyDisk;

	//Check the volume type of the underlying filesystem for that path
	NSString *volumeType = [workspace volumeTypeForPath: filePath];
	
	//Mount data or audio CD volumes as CD-ROM drives 
	if ([volumeType isEqualToString: dataCDVolumeType] || [volumeType isEqualToString: audioCDVolumeType])
		return BXDriveCDROM;

	//If the path is a FAT/FAT32 volume, check its volume size: volumes smaller than BXFloppySizeCutoff will be treated as floppy disks.
	//TODO: is it really relevant whether it's FAT? Should we do this for all very small volumes?
	if ([volumeType isEqualToString: FATVolumeType])
	{
		NSFileManager *manager = [NSFileManager defaultManager];
		NSDictionary *fsAttrs = [manager attributesOfFileSystemForPath: filePath error: nil];
		NSUInteger volumeSize = [[fsAttrs valueForKey: NSFileSystemSize] integerValue];
		if (volumeSize <= BXFloppySizeCutoff) return BXDriveFloppyDisk;
	}
	
	//Fall back on a standard hard-disk mount
	return BXDriveHardDisk;
}

+ (NSString *) preferredLabelForPath: (NSString *)filePath
{
	NSWorkspace *workspace	= [NSWorkspace sharedWorkspace];
						   
	//Disk images store their own volume labels
	if ([workspace file: filePath matchesTypes: [BXAppController mountableImageTypes]]) return nil;
						   
	//Extensions to strip from filenames
	NSArray *strippedExtensions = [NSArray arrayWithObjects:
								   @"boxer",
								   @"cdrom",
								   @"floppy",
								   @"harddisk",
								   nil];
						   
						   
	NSString *baseName		= [filePath lastPathComponent];
	NSString *extension		= [[baseName pathExtension] lowercaseString];
	if ([strippedExtensions containsObject: extension]) baseName = [baseName stringByDeletingPathExtension];
	
	//Mountable folders can include a drive letter prefix as well as a drive label,
	//so have a crack at parsing that out
	if ([workspace file: filePath matchesTypes: [BXAppController mountableFolderTypes]])
	{
		NSString *detectedLabel	= [baseName stringByMatching: @"^([a-xA-X] )?(.+)$" capture: 2];
		if (detectedLabel) return detectedLabel;		
	}

	//For all other cases, just use the base filename as the drive label
	return baseName;
}

+ (NSString *) preferredDriveLetterForPath: (NSString *)filePath
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	if ([workspace file: filePath matchesTypes: [BXAppController mountableImageTypes]] ||
		[workspace file: filePath matchesTypes: [BXAppController mountableFolderTypes]])
	{
		NSString *baseName			= [[filePath stringByDeletingPathExtension] lastPathComponent];
		NSString *detectedLetter	= [baseName stringByMatching: @"^([a-xA-X])( .*)?$" capture: 1];
		return detectedLetter;	//will be nil if no match was found
	}
	return nil;
}

//Copious initialisation methods we will never use
//------------------------------------------------

- (id) init
{
	if ((self = [super init]))
	{
		//Initialise properties to sensible defaults
		[self setType:			BXDriveHardDisk];
		[self setFreeSpace:		BXDefaultFreeSpace];
		[self setUsesCDAudio:	YES];
		[self setReadOnly:		NO];
	}
	return self;
}

- (id) initFromPath: (NSString *)drivePath atLetter: (NSString *)driveLetter withType: (BXDriveType)driveType
{
	if ((self = [self init]))
	{
		if (driveLetter) [self setLetter: driveLetter];
		
		if (drivePath)
		{
			[self setPath: drivePath];
			//Fetch the filesystem icon for the drive
			NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
			[self setIcon: [workspace iconForFile: drivePath]];
		}
		
		//Detect the appropriate mount type for the specified path
		if (driveType == BXDriveAutodetect) driveType = [[self class] preferredTypeForPath: [self path]];
		
		[self setType: driveType];
	}
	return self;
}

+ (id) driveFromPath: (NSString *)drivePath atLetter: (NSString *)driveLetter withType: (BXDriveType)driveType
{
	return [[[self alloc] initFromPath: drivePath atLetter: driveLetter withType: driveType] autorelease];
}

+ (id) driveFromPath: (NSString *)drivePath atLetter: (NSString *)driveLetter
{
	return [self driveFromPath: drivePath atLetter: driveLetter withType: BXDriveAutodetect];
}

+ (id) CDROMFromPath:		(NSString *)drivePath atLetter: (NSString *)driveLetter
	{ return [self driveFromPath: drivePath atLetter: driveLetter withType: BXDriveCDROM]; }
+ (id) floppyDriveFromPath: (NSString *)drivePath atLetter: (NSString *)driveLetter
	{ return [self driveFromPath: drivePath atLetter: driveLetter withType: BXDriveFloppyDisk]; }
+ (id) hardDriveFromPath:	(NSString *)drivePath atLetter: (NSString *)driveLetter
	{ return [self driveFromPath: drivePath atLetter: driveLetter withType: BXDriveHardDisk]; }
+ (id) internalDriveAtLetter: (NSString *)driveLetter
{ return [self driveFromPath: nil atLetter: driveLetter withType: BXDriveInternal]; }


- (void) dealloc
{
	[self setLetter: nil],	[letter release];
	[self setPath: nil],	[path release];
	[self setLabel: nil],	[label release];
	[self setIcon: nil],	[icon release];
	[super dealloc];
}


- (void) setPath: (NSString *)filePath
{
	filePath = [filePath stringByStandardizingPath];
	
	[self willChangeValueForKey: @"path"];
	if (![path isEqualToString: filePath])
	{
		[path release];
		path = [filePath copy];
		
		if (path)
		{
			//Automatically parse the drive letter and label from the name of the drive
			if (![self letter])	[self setLetter:	[[self class] preferredDriveLetterForPath: filePath]];
			if (![self label])	[self setLabel:		[[self class] preferredLabelForPath: filePath]];
		}
	}
	[self didChangeValueForKey: @"path"];
}

- (void) setLetter: (NSString *)driveLetter
{
	driveLetter = [driveLetter uppercaseString];
	
	[self willChangeValueForKey: @"letter"];
	if (![letter isEqualToString: driveLetter])
	{
		[letter release];
		letter = [driveLetter copy];
	}
	[self didChangeValueForKey: @"letter"];
}

- (BOOL) exposesPath: (NSString *)subPath
{
	if ([self isInternal]) return NO;
	subPath = [subPath stringByStandardizingPath];
	
	return [subPath isRootedInPath: [self path]];
}

- (BOOL) isInternal	{ return ([self type] == BXDriveInternal); }
- (BOOL) isCDROM	{ return ([self type] == BXDriveCDROM); }
- (BOOL) isFloppy	{ return ([self type] == BXDriveFloppyDisk); }
- (BOOL) isHardDisk	{ return ([self type] == BXDriveHardDisk); }

- (NSString *) typeDescription
{
	return [[self class] descriptionForType: [self type]];
}
- (NSString *) description
{
	return [NSString stringWithFormat: @"%@: %@ (%@)",
			[self letter],
			[self path],
			[[self class] descriptionForType: [self type]],
			nil]; 
}

//Generated display properties
//----------------------------

- (NSString *) displayName
{
	NSFileManager *manager = [NSFileManager defaultManager];
	return [manager displayNameAtPath: [self path]];
}


//Comparison functions for easy drive sorting
//-------------------------------------------

//Sort by path depth
- (NSComparisonResult) pathDepthCompare: (BXDrive *)comparison
{
	return [[self path] pathDepthCompare: [comparison path]];
}

//Sort by drive letter
- (NSComparisonResult) letterCompare: (BXDrive *)comparison
{
	return [[self letter] caseInsensitiveCompare: [comparison letter]];
}

@end
