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
@synthesize path, letter, label;
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
		@"hard drive",				//BXDriveTypeHardDisk
		@"floppy drive",			//BXDriveTypeFloppyDisk
		@"CD-ROM drive",			//BXDriveTypeCDROM
		@"internal system disk",	//BXDriveTypeInternal
	nil];
	if (driveType >= 0 && driveType < [descriptions count]) return [descriptions objectAtIndex: driveType];
	else return @"unknown drive type";
}

+ (BXDriveType) preferredTypeForPath: (NSString *)filePath
{	
	if (filePath == nil) return BXDriveInternal;
	
	NSWorkspace *workspace	= [NSWorkspace sharedWorkspace];
	if ([workspace file: filePath matchesTypes: [BXAppController cdVolumeTypes]])		return BXDriveCDROM;
	if ([workspace file: filePath matchesTypes: [BXAppController floppyVolumeTypes]])	return BXDriveFloppyDisk;

	//Check the volume type of the underlying filesystem for that path
	NSString *volumeType = [workspace volumeTypeForPath: filePath];
	if ([volumeType isEqualToString: dataCDVolumeType] || [volumeType isEqualToString: audioCDVolumeType]) return BXDriveCDROM;
	
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
		[self setPath: drivePath];
		if (driveLetter) [self setLetter: driveLetter];
		
		//Autodetect the appropriate mount type for the specified path
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


- (void) dealloc
{
	[self setLetter: nil],	[letter release];
	[self setPath: nil],	[path release];
	[self setLabel: nil],	[label release];
	[super dealloc];
}


- (void) setPath: (NSString *)filePath
{
	filePath = [filePath stringByStandardizingPath];
	
	[self willChangeValueForKey: @"path"];
	[path autorelease];
	path = [filePath retain];
	[self didChangeValueForKey: @"path"];
	
	//Automatically parse the drive letter and label from the name of the drive
	if (![self letter])	[self setLetter:	[[self class] preferredDriveLetterForPath: filePath]];
	if (![self label])	[self setLabel:		[[self class] preferredLabelForPath: filePath]];
}

- (void) setLetter: (NSString *)driveLetter
{
	driveLetter = [driveLetter uppercaseString];
	
	[self willChangeValueForKey: @"letter"];
	[letter autorelease];
	letter = [driveLetter retain];
	[self didChangeValueForKey: @"letter"];	
}

//If type was set to auto, autodetect the appropriate mount type for our current path the first time we need that information
- (BXDriveType) type
{
	if (type == BXDriveAutodetect) [self setType: [[self class] preferredTypeForPath: [self path]]];
	return type;
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
	return [NSString stringWithFormat: @"%@: %@ (%@)", [self letter], [self path], [[self class] descriptionForType: [self type]], nil]; 
}

//Generated display properties
//----------------------------

- (NSString *) displayName
{
	NSFileManager *manager = [NSFileManager defaultManager];
	return [manager displayNameAtPath: [self path]];
}

- (NSImage *) icon
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	return [workspace iconForFile: [self path]];
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