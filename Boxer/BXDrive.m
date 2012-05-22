/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDrive.h"
#import "NSWorkspace+BXMountedVolumes.h"
#import "NSWorkspace+BXFileTypes.h"
#import "NSString+BXPaths.h"
#import "RegexKitLite.h"
#import "NDAlias.h"

@interface BXDrive ()

@property (readwrite, retain, nonatomic) NSMutableSet *pathAliases;

@end

@implementation BXDrive
@synthesize path = _path;
@synthesize mountPoint = _mountPoint;
@synthesize pathAliases = _pathAliases;
@synthesize letter = _letter;
@synthesize title = _title;
@synthesize volumeLabel = _volumeLabel;
@synthesize type = _type;
@synthesize freeSpace = _freeSpace;
@synthesize usesCDAudio = _usesCDAudio;
@synthesize readOnly = _readOnly;
@synthesize locked = _locked;
@synthesize hidden = _hidden;
@synthesize mounted = _mounted;

#pragma mark -
#pragma mark Class methods

+ (NSSet *) hddVolumeTypes
{
	static NSSet *types = nil;
	if (!types) types = [[NSSet alloc] initWithObjects:
						 @"net.washboardabs.boxer-harddisk-folder",
						 nil];
	return types;
}

+ (NSSet *) cdVolumeTypes
{
	static NSSet *types = nil;
	if (!types) types = [[NSSet alloc] initWithObjects:
						 @"com.goldenhawk.cdrwin-cuesheet",
						 @"net.washboardabs.boxer-cdrom-folder",
						 @"net.washboardabs.boxer-cdrom-bundle",
						 @"public.iso-image",
						 @"com.apple.disk-image-cdr",
						 nil];
	return types;
}

+ (NSSet *) floppyVolumeTypes
{
	static NSSet *types = nil;
	if (!types) types = [[NSSet alloc] initWithObjects:
						 @"net.washboardabs.boxer-floppy-folder",
						 @"com.winimage.raw-disk-image",
                         @"com.apple.disk-image-ndif",
                         @"com.microsoft.virtualpc-disk-image",
						 nil];
	return types;
}

+ (NSSet *) mountableFolderTypes
{
	static NSSet *types = nil;
	if (!types) types = [[NSSet alloc] initWithObjects:
						 @"net.washboardabs.boxer-mountable-folder",
						 nil];
	return types;
}

+ (NSSet *) mountableImageTypes
{
	static NSSet *types = nil;
	if (!types) types = [[NSSet alloc] initWithObjects:
						 @"public.iso-image",					//.iso
						 @"com.apple.disk-image-cdr",			//.cdr
						 @"com.goldenhawk.cdrwin-cuesheet",		//.cue
						 @"net.washboardabs.boxer-disk-bundle", //.cdmedia
						 @"com.winimage.raw-disk-image",		//.ima
                         @"com.microsoft.virtualpc-disk-image", //.vfd
                         @"com.apple.disk-image-ndif",          //.img
						 nil];
	return types;
}


+ (NSString *) descriptionForType: (BXDriveType)driveType
{
	static NSArray *descriptions = nil;
	if (!descriptions) descriptions = [[NSArray alloc] initWithObjects:
		NSLocalizedString(@"hard disk",             @"Label for hard disk mounts."),				//BXDriveTypeHardDisk
		NSLocalizedString(@"floppy disk",           @"Label for floppy-disk mounts."),				//BXDriveTypeFloppyDisk
		NSLocalizedString(@"CD-ROM",                @"Label for CD-ROM drive mounts."),				//BXDriveTypeCDROM
		NSLocalizedString(@"internal system disk",	@"Label for DOSBox virtual drives (i.e. Z)."),	//BXDriveTypeInternal
	nil];
	NSAssert1(driveType >= BXDriveHardDisk && (NSUInteger)driveType < [descriptions count],
			  @"Unknown drive type supplied to BXDrive descriptionForType: %i", driveType);
	
	return [descriptions objectAtIndex: driveType];
}

+ (BXDriveType) preferredTypeForPath: (NSString *)filePath
{	
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	if ([workspace file: filePath matchesTypes: [self cdVolumeTypes]])		return BXDriveCDROM;
	if ([workspace file: filePath matchesTypes: [self floppyVolumeTypes]])	return BXDriveFloppyDisk;

	//Check the volume type of the underlying filesystem for that path
	NSString *volumeType = [workspace volumeTypeForPath: filePath];
	
	//Mount data or audio CD volumes as CD-ROM drives 
	if ([volumeType isEqualToString: dataCDVolumeType] || [volumeType isEqualToString: audioCDVolumeType])
		return BXDriveCDROM;

	//If the path is a FAT/FAT32 volume, check its volume size:
	//volumes smaller than BXFloppySizeCutoff will be treated as floppy disks.
	if ([workspace isFloppyVolumeAtPath: filePath]) return BXDriveFloppyDisk;
	
	//Fall back on a standard hard-disk mount
	return BXDriveHardDisk;
}

+ (NSString *) preferredTitleForPath: (NSString *)filePath
{
    NSString *label = [self preferredVolumeLabelForPath: filePath];
    if (label.length > 1) return label;
	else return [[NSFileManager defaultManager] displayNameAtPath: filePath];
}

+ (NSString *) preferredVolumeLabelForPath: (NSString *)filePath
{						   
	//Extensions to strip from filenames
    //TODO: derive these from somewhere else
	NSArray *strippedExtensions = [NSArray arrayWithObjects:
								   @"boxer",
								   @"cdrom",
								   @"floppy",
								   @"harddisk",
								   nil];

    NSString *baseName		= filePath.lastPathComponent;
	NSString *extension		= baseName.pathExtension.lowercaseString;
	if ([strippedExtensions containsObject: extension])
        baseName = baseName.stringByDeletingPathExtension;
	
	//Mountable folders can include a drive label as well as a letter prefix,
    //so have a crack at parsing that out
    NSString *detectedLabel	= [baseName stringByMatching: @"^([a-xA-X] )?(.+)$" capture: 2];
    if (detectedLabel.length) return detectedLabel;
	
	//For all other cases, just use the base filename as the drive label
	else return baseName;
}

+ (NSString *) preferredDriveLetterForPath: (NSString *)filePath
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	if ([workspace file: filePath matchesTypes: [self mountableImageTypes]] ||
		[workspace file: filePath matchesTypes: [self mountableFolderTypes]])
	{
		NSString *baseName			= filePath.stringByDeletingPathExtension.lastPathComponent;
		NSString *detectedLetter	= [baseName stringByMatching: @"^([a-xA-X])( .*)?$" capture: 1];
		return detectedLetter;	//will be nil if no match was found
	}
	return nil;
}

+ (NSString *) mountPointForPath: (NSString *)filePath
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	if ([workspace file: filePath matchesTypes: [NSSet setWithObject: @"net.washboardabs.boxer-cdrom-bundle"]])
	{
		return [filePath stringByAppendingPathComponent: @"tracks.cue"];
	}
	else return filePath;
}

//Pretty much all our properties depend on our path, so we add it here
+ (NSSet *)keyPathsForValuesAffectingValueForKey: (NSString *)key
{
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey: key];
	if (![key isEqualToString: @"path"]) keyPaths = [keyPaths setByAddingObject: @"path"];
	return keyPaths;
}


#pragma mark -
#pragma mark Initializers

- (id) init
{
	if ((self = [super init]))
	{
		//Initialise properties to sensible defaults
        self.type = BXDriveHardDisk;
        self.freeSpace = BXDefaultFreeSpace;
        self.usesCDAudio = YES;
        self.readOnly = NO;
        
        self.pathAliases = [NSMutableSet setWithCapacity: 1];
	}
	return self;
}

- (id) initFromPath: (NSString *)drivePath atLetter: (NSString *)driveLetter withType: (BXDriveType)driveType
{
    NSAssert1(!(drivePath == nil && driveType != BXDriveInternal), @"Nil drive path passed to BXDrive -initFromPath:atLetter:withType:. Drive type was %i, which is not permitted to have an empty drive path.", driveType);
    
	if ((self = [self init]))
	{
		if (driveLetter)
            self.letter = driveLetter;
        
		if (drivePath)
            self.path = drivePath;
        
		//Detect the appropriate mount type for the specified path
		if (driveType == BXDriveAutodetect)
            driveType = [self.class preferredTypeForPath: self.path];
		
		self.type = driveType;
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

+ (id) CDROMFromPath: (NSString *)drivePath atLetter: (NSString *)driveLetter
{ return [self driveFromPath: drivePath atLetter: driveLetter withType: BXDriveCDROM]; }
+ (id) floppyDriveFromPath: (NSString *)drivePath atLetter: (NSString *)driveLetter
{ return [self driveFromPath: drivePath atLetter: driveLetter withType: BXDriveFloppyDisk]; }
+ (id) hardDriveFromPath: (NSString *)drivePath atLetter: (NSString *)driveLetter
{ return [self driveFromPath: drivePath atLetter: driveLetter withType: BXDriveHardDisk]; }
+ (id) internalDriveAtLetter: (NSString *)driveLetter
{ return [self driveFromPath: nil atLetter: driveLetter withType: BXDriveInternal]; }

- (id) initWithCoder: (NSCoder *)aDecoder
{
    if ((self = [self init]))
    {
        NDAlias *pathAlias = [aDecoder decodeObjectForKey: @"path"];
        NDAlias *mountPointAlias = [aDecoder decodeObjectForKey: @"mountPoint"];
        
        if (pathAlias.path)
            self.path = pathAlias.path;
        
        if (mountPointAlias.path)
            self.mountPoint = mountPointAlias.path;
        
        NSSet *pathAliases = [aDecoder decodeObjectForKey: @"pathAliases"];
        for (NDAlias *alias in pathAliases)
        {
            if (alias.path)
                [self.pathAliases addObject: alias.path];
        }
        
        self.type           = [aDecoder decodeIntegerForKey: @"type"];
        self.letter         = [aDecoder decodeObjectForKey: @"letter"];
        self.title          = [aDecoder decodeObjectForKey: @"title"];
        self.volumeLabel    = [aDecoder decodeObjectForKey: @"volumeLabel"];
        
        self.usesCDAudio    = [aDecoder decodeBoolForKey: @"usesCDAudio"];
        self.freeSpace      = [aDecoder decodeIntegerForKey: @"freeSpace"];
        self.readOnly       = [aDecoder decodeBoolForKey: @"readOnly"];
        self.locked         = [aDecoder decodeBoolForKey: @"locked"];
        self.hidden         = [aDecoder decodeBoolForKey: @"hidden"];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *)aCoder
{
    
}


- (void) dealloc
{
    self.path = nil;
    self.letter = nil;
    self.title = nil;
    self.volumeLabel = nil;
    self.pathAliases = nil;
    
	[super dealloc];
}


- (void) setPath: (NSString *)filePath
{
	filePath = [filePath stringByStandardizingPath];
	
	if (![self.path isEqualToString: filePath])
	{
		[_path release];
		_path = [filePath copy];
		
		if (filePath)
		{
			if (!self.mountPoint)
				self.mountPoint = [self.class mountPointForPath: filePath];
			
			//Automatically parse the drive letter, title and volume label from the name of the drive
			if (!self.letter)
                self.letter = [self.class preferredDriveLetterForPath: filePath];
            
			if (!self.volumeLabel)
                self.volumeLabel = [self.class preferredVolumeLabelForPath: filePath];
            
			if (!self.title)
                self.title = [self.class preferredTitleForPath: filePath];
		}
	}
}

- (void) setLetter: (NSString *)driveLetter
{
	driveLetter = driveLetter.uppercaseString;
	
	if (![self.letter isEqualToString: driveLetter])
	{
		[_letter release];
		_letter = [driveLetter copy];
	}
}

- (void) setVolumeLabel: (NSString *)newLabel
{
	if (![_volumeLabel isEqualToString: newLabel])
	{
		[_volumeLabel release];
		_volumeLabel = [newLabel copy];
		
		//if (![[self title] length]) [self setTitle: volumeLabel];
	}
}

- (BOOL) representsPath: (NSString *)basePath
{
	if (self.isInternal) return NO;
	basePath = [basePath stringByStandardizingPath];
	
	if ([self.path isEqualToString: basePath]) return YES;
	if ([self.mountPoint isEqualToString: basePath]) return YES;
	if ([self.pathAliases containsObject: basePath]) return YES;
	
	return NO;
}

- (BOOL) exposesPath: (NSString *)subPath
{
	if (self.isInternal) return NO;
	subPath = [subPath stringByStandardizingPath];
	
	if ([subPath isEqualToString: self.path]) return YES;
	if ([subPath isRootedInPath: self.mountPoint]) return YES;
	
	for (NSString *alias in self.pathAliases)
	{
		if ([subPath isRootedInPath: alias]) return YES;
	}
	
	return NO;
}

- (NSString *) relativeLocationOfPath: (NSString *)realPath
{
	if (self.isInternal) return nil;
	realPath = [realPath stringByStandardizingPath];
	
	NSString *relativePath = nil;
	
	//Special-case: map the 'represented' path directly onto the mount path
	if ([realPath isEqualToString: self.path])
	{
		relativePath = @"";
	}
	
	else if ([realPath isRootedInPath: self.mountPoint])
	{
		relativePath = [realPath substringFromIndex: self.mountPoint.length];
	}
	
	else
	{
		for (NSString *alias in self.pathAliases)
		{
			if ([realPath isRootedInPath: alias])
			{
				relativePath = [realPath substringFromIndex: alias.length];
				break;
			}
		}
	}
	
	//Strip any leading slash from the relative path
	if (relativePath && [relativePath hasPrefix: @"/"])
		relativePath = [relativePath substringFromIndex: 1];
	
	return relativePath;
}

- (BOOL) isInternal	{ return (self.type == BXDriveInternal); }
- (BOOL) isCDROM	{ return (self.type == BXDriveCDROM); }
- (BOOL) isFloppy	{ return (self.type == BXDriveFloppyDisk); }
- (BOOL) isHardDisk	{ return (self.type == BXDriveHardDisk); }

- (NSString *) typeDescription
{
	return [self.class descriptionForType: self.type];
}
- (NSString *) description
{
	return [NSString stringWithFormat: @"%@: %@ (%@)",
			self.letter,
			self.path,
			[self.class descriptionForType: self.type],
			nil]; 
}

- (NSString *) displayName
{
	if      (self.title) return self.title;
	else if (self.volumeLabel) return self.volumeLabel;
	else if (self.path)
	{
		NSFileManager *manager = [NSFileManager defaultManager];
		return [manager displayNameAtPath: self.path];
	}
	else
	{
		return self.typeDescription;
	}
}


#pragma mark -
#pragma mark Drive sort comparisons

//Sort by path depth
- (NSComparisonResult) pathDepthCompare: (BXDrive *)comparison
{
	return [self.path pathDepthCompare: comparison.path];
}

//Sort by drive letter
- (NSComparisonResult) letterCompare: (BXDrive *)comparison
{
	return [self.letter caseInsensitiveCompare: comparison.letter];
}

@end
