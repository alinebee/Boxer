/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDrivePrivate.h"
#import "NSWorkspace+ADBMountedVolumes.h"
#import "NSWorkspace+ADBFileTypes.h"
#import "NSString+ADBPaths.h"
#import "RegexKitLite.h"
#import "BXFileTypes.h"
#import "NSURL+ADBFilesystemHelpers.h"
#import "ADBShadowedFilesystem.h"


#pragma mark - Implementation

@implementation BXDrive
@synthesize sourceURL = _sourceURL;
@synthesize shadowURL = _shadowURL;
@synthesize mountPointURL = _mountPointURL;
@synthesize letter = _letter;
@synthesize title = _title;
@synthesize volumeLabel = _volumeLabel;
@synthesize DOSVolumeLabel = _DOSVolumeLabel;
@synthesize type = _type;
@synthesize freeSpace = _freeSpace;
@synthesize usesCDAudio = _usesCDAudio;
@synthesize readOnly = _readOnly;
@synthesize locked = _locked;
@synthesize hidden = _hidden;
@synthesize mounted = _mounted;
@synthesize filesystem = _filesystem;


#pragma mark - Helper class methods

+ (NSSet *) mountableTypesWithExtensions
{
	static NSMutableSet *types;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        types = [[BXFileTypes mountableImageTypes] mutableCopy];
        [types unionSet: [BXFileTypes mountableFolderTypes]];
        [types addObject: BXGameboxType];
    });
	return types;
}

+ (NSSet *) mountableTypesWithEmbeddedDriveLetters
{
	static NSMutableSet *types;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        types = [[BXFileTypes mountableImageTypes] mutableCopy];
        [types unionSet: [BXFileTypes mountableFolderTypes]];
    });
	return types;
}

+ (NSString *) localizedDescriptionForType: (BXDriveType)driveType
{
	static NSArray *descriptions = nil;
	if (!descriptions) descriptions = [[NSArray alloc] initWithObjects:
		NSLocalizedString(@"hard disk",             @"Label for hard disk mounts."),				//BXDriveTypeHardDisk
		NSLocalizedString(@"floppy disk",           @"Label for floppy-disk mounts."),				//BXDriveTypeFloppyDisk
		NSLocalizedString(@"CD-ROM",                @"Label for CD-ROM drive mounts."),				//BXDriveTypeCDROM
		NSLocalizedString(@"internal system disk",	@"Label for DOSBox virtual drives (i.e. Z)."),	//BXDriveTypeInternal
	nil];
	NSAssert1(driveType >= BXDriveHardDisk && (NSUInteger)driveType < descriptions.count,
			  @"Unknown drive type supplied to BXDrive descriptionForType: %i", driveType);
	
	return [descriptions objectAtIndex: (NSUInteger)driveType];
}


+ (BXDriveType) preferredTypeForContentsOfURL: (NSURL *)URL
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    
    //First check if the file's UTI corresponds to one of our known types.
    //This catches disk images and Boxer mountable folders (.cdrom, .harddisk etc.)
    if ([URL matchingFileType: [BXFileTypes cdVolumeTypes]] != nil)
        return BXDriveCDROM;
    
    if ([URL matchingFileType: [BXFileTypes floppyVolumeTypes]] != nil)
        return BXDriveFloppyDisk;
    
    if ([URL matchingFileType: [BXFileTypes hddVolumeTypes]] != nil)
        return BXDriveHardDisk;
    
    //Failing that, check the volume type of the underlying filesystem at that location.
    NSString *volumeType = [workspace typeOfVolumeAtURL: URL];
	
	//Mount locations on data or audio CD volumes as CD-ROM drives.
	if ([volumeType isEqualToString: ADBDataCDVolumeType] || [volumeType isEqualToString: ADBAudioCDVolumeType])
		return BXDriveCDROM;
    
	//If the location is on a FAT/FAT32 volume, check if it's floppy-sized.
	if ([workspace isFloppyVolumeAtURL: URL])
        return BXDriveFloppyDisk;
	
	//In all other cases, fall back on a standard hard-disk mount.
	return BXDriveHardDisk;
}

+ (NSString *) preferredTitleForContentsOfURL: (NSURL *)URL
{
    NSString *label = [self preferredVolumeLabelForContentsOfURL: URL];
    if (label.length > 1) //Ignore labels that are just the letter of the drive
    {
        return label;
    }
	else
    {
        NSString *filename = URL.localizedName;
        if (!filename)
            filename = URL.lastPathComponent;
        
        return filename;
    }
}


+ (NSString *) preferredVolumeLabelForContentsOfURL: (NSURL *)URL
{
    //Dots in DOS volume labels are acceptable, but may be confused with file extensions which
    //we do want to remove. So, we strip off the extensions for our known image/folder types.
    BOOL shouldStripExtension = ([URL matchingFileType: [self mountableTypesWithExtensions]] != nil);
    
    NSString *baseName = URL.lastPathComponent;
    if (shouldStripExtension)
        baseName = baseName.stringByDeletingPathExtension;
	
    //Imported drives may have an increment on the end to avoid filename collisions, so parse that off too.
    NSString *incrementSuffix = [baseName stringByMatching: @" (\\(\\d+\\))$"];
    if (incrementSuffix)
        baseName = [baseName substringToIndex: baseName.length - incrementSuffix.length];
    
	//Bundled drives can include a letter prefix preceding the label with a space,
    //so if there's both then parse out the letter prefix.
    //(If the name is only a single letter without anything following it, then we treat that
    //letter as the label, to avoid false negatives for single-letter game titles like "Z".)
    NSString *letterPrefix = [baseName stringByMatching: @"^([a-xA-X] )?(.+)$" capture: 1];
    if (letterPrefix)
        baseName = [baseName substringFromIndex: letterPrefix.length];
    
    //TODO: should we trim leading and trailing whitespace? Are spaces meaningful in DOS volume labels?
	return baseName;
}

+ (NSString *) preferredDriveLetterForContentsOfURL: (NSURL *)URL
{
    //If the URL represents a Boxer mountable folder or a disk image,
    //try to parse the drive letter from the name.
    if ([URL matchingFileType: [self mountableTypesWithEmbeddedDriveLetters]] != nil)
	{
		NSString *baseName          = URL.lastPathComponent.stringByDeletingPathExtension;
		NSString *detectedLetter	= [baseName stringByMatching: @"^([a-xA-X])( .*)?$" capture: 1];
		return detectedLetter;	//will be nil if no match was found
	}
	return nil;
}

+ (NSURL *) mountPointForContentsOfURL: (NSURL *)URL
{
    if ([URL conformsToFileType: BXCDROMImageBundleType])
    {
        return [URL URLByAppendingPathComponent: @"tracks.cue" isDirectory: NO];
    }
    else return URL;
}


#pragma mark - Initialization and cleanup

- (id) init
{
    self = [super init];
	if (self)
	{
		//Initialise properties to sensible defaults
        self.type = BXDriveHardDisk;
        self.freeSpace = BXDefaultFreeSpace;
        self.usesCDAudio = YES;
	}
    
	return self;
}

+ (id) driveWithContentsOfURL: (NSURL *)sourceURL
                       letter: (NSString *)driveLetter
                         type: (BXDriveType)driveType
{
    return [[self alloc] initWithContentsOfURL: sourceURL letter: driveLetter type: driveType];
}

- (id) initWithContentsOfURL: (NSURL *)sourceURL
                      letter: (NSString *)driveLetter
                        type: (BXDriveType)driveType
{
    NSAssert(!(sourceURL == nil && driveType != BXDriveVirtual),
             @"A source URL must be provided for drives of all types except BXDriveVirtual.");
    
    self = [self init];
	if (self)
	{
		if (driveLetter)
            self.letter = driveLetter;
        
		if (sourceURL)
            self.sourceURL = sourceURL;
        
		//Detect the appropriate type for the specified source
		if (driveType == BXDriveAutodetect)
        {
            self.type = [self.class preferredTypeForContentsOfURL: sourceURL];
            _hasAutodetectedType = YES;
		}
		else
        {
            self.type = driveType;
        }
	}
	return self;
}

+ (id) virtualDriveWithLetter: (NSString *)driveLetter
{
    return [self driveWithContentsOfURL: nil letter: driveLetter type: BXDriveVirtual];
}

#pragma mark - Setters and getters

//Pretty much all our properties depend on our source URL, so we add it here
+ (NSSet *) keyPathsForValuesAffectingValueForKey: (NSString *)key
{
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey: key];
	if (![key isEqualToString: @"sourceURL"])
        keyPaths = [keyPaths setByAddingObject: @"sourceURL"];
    
	return keyPaths;
}

- (void) setSourceURL: (NSURL *)sourceURL
{
    sourceURL = sourceURL.URLByStandardizingPath;
	if (![_sourceURL isEqual: sourceURL])
	{
		_sourceURL = [sourceURL copy];
		
		if (_sourceURL)
		{
			if (!self.mountPointURL)
            {
				self.mountPointURL = [self.class mountPointForContentsOfURL: _sourceURL];
                _hasAutodetectedMountPoint = YES;
            }
			
			//Automatically parse the drive letter, title and volume label from the name of the drive
			if (!self.letter)
            {
                self.letter = [self.class preferredDriveLetterForContentsOfURL: _sourceURL];
                _hasAutodetectedLetter = YES;
            }
            
			if (!self.volumeLabel)
            {
                self.volumeLabel = [self.class preferredVolumeLabelForContentsOfURL: _sourceURL];
                _hasAutodetectedVolumeLabel = YES;
            }
            
			if (!self.title)
            {
                self.title = [self.class preferredTitleForContentsOfURL: _sourceURL];
                _hasAutodetectedTitle = YES;
            }
		}
	}
}

- (void) setMountPointURL: (NSURL *)mountPointURL
{
    mountPointURL = mountPointURL.URLByStandardizingPath;
    if (![_mountPointURL isEqual: mountPointURL])
	{
		_mountPointURL = [mountPointURL copy];
		
        _hasAutodetectedMountPoint = NO;
        
        //Clear our old filesystem whenever the source changes: it will be recreated when needed.
        self.filesystem = nil;
	}
}

- (void) setShadowURL: (NSURL *)shadowURL
{
    shadowURL = shadowURL.URLByStandardizingPath;
    if (![_shadowURL isEqual: shadowURL])
	{
		_shadowURL = [shadowURL copy];
        
        //Clear our old filesystem, if it was shadowed: it will be recreated when needed.
        if (_shadowURL && [_filesystem isKindOfClass: [ADBShadowedFilesystem class]])
        {
            self.filesystem = nil;
        }
	}
}


- (void) setLetter: (NSString *)driveLetter
{
	driveLetter = driveLetter.uppercaseString;
	
	if (![self.letter isEqualToString: driveLetter])
	{
		_letter = [driveLetter copy];
        
        _hasAutodetectedLetter = NO;
	}
}

- (void) setVolumeLabel: (NSString *)newLabel
{
	if (![_volumeLabel isEqualToString: newLabel])
	{
		_volumeLabel = [newLabel copy];
		
        _hasAutodetectedVolumeLabel = NO;
	}
}

- (void) setTitle: (NSString *)title
{
    if (![_title isEqualToString: title])
	{
		_title = [title copy];
		
        _hasAutodetectedTitle = NO;
	}
}


- (id <ADBFilesystemPathAccess>) filesystem
{
    if (!_filesystem && self.mountPointURL)
    {
        //TODO: support filesystem shadowing for image-based filesystems
        if (self.shadowURL)
        {
            self.filesystem = [ADBShadowedFilesystem filesystemWithBaseURL: self.mountPointURL
                                                                 shadowURL: self.shadowURL];
        }
        else
        {
            self.filesystem = [BXFileTypes filesystemWithContentsOfURL: self.mountPointURL
                                                                 error: NULL];
        }
        
        NSAssert1(self.filesystem != nil, @"No suitable filesystem could be found for mount point %@", self.mountPointURL);
        
        if (![self.sourceURL isEqual: self.mountPointURL])
            [self.filesystem addRepresentedURL: self.sourceURL];
        
    }
    return _filesystem;
}


#pragma mark - Drive descriptions

- (BOOL) isVirtual	{ return (self.type == BXDriveVirtual); }
- (BOOL) isCDROM	{ return (self.type == BXDriveCDROM); }
- (BOOL) isFloppy	{ return (self.type == BXDriveFloppyDisk); }
- (BOOL) isHardDisk	{ return (self.type == BXDriveHardDisk); }
- (BOOL) isReadOnly { return _readOnly || self.isCDROM || self.isVirtual; }

- (NSString *) localizedTypeDescription
{
	return [self.class localizedDescriptionForType: self.type];
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"%@: %@ (%@)", self.letter, self.sourceURL, self.localizedTypeDescription];
}


#pragma mark - File location lookups

- (BOOL) representsLogicalURL: (NSURL *)URL
{
	if (self.isVirtual) return NO;
    
    URL = URL.URLByStandardizingPath;
    return [self.filesystem representsLogicalURL: URL];
}

- (BOOL) exposesLogicalURL: (NSURL *)URL
{
	if (self.isVirtual) return NO;
    
    URL = URL.URLByStandardizingPath;
    return [self.filesystem exposesLogicalURL: URL];
}

- (NSURL *) logicalURLForDOSPath: (NSString *)dosPath
{
    NSString *posixPath = [dosPath stringByReplacingOccurrencesOfString: @"\\" withString: @"/"];
    
    //Strip off any leading drive letter
    if (posixPath.length >= 2 && [posixPath characterAtIndex: 1] == (unichar)':')
    {
        posixPath = [posixPath substringFromIndex: 2];
    }
    
    return [self.filesystem logicalURLForPath: posixPath];
}

- (NSString *) relativeLocationOfLogicalURL: (NSURL *)URL
{
	if (self.isVirtual)
        return nil;
    
    URL = URL.URLByStandardizingPath;
    NSString *path = [self.filesystem pathForLogicalURL: URL];
    
    //Normalize path to be relative by trimming off leading suffix.
    if ([path hasPrefix: @"/"])
        path = [path substringFromIndex: 1];
    
    return path;
}

- (void) addEquivalentURL: (NSURL *)URL
{
    [self.filesystem addRepresentedURL: URL];
}

- (void) removeEquivalentURL: (NSURL *)URL
{
    [self.filesystem removeRepresentedURL: URL];
}


#pragma mark - Drive sort comparisons

- (NSComparisonResult) sourceDepthCompare: (BXDrive *)comparison
{
    //TODO: reimplement this with a URL-centric solution.
	return [self.mountPointURL.path pathDepthCompare: comparison.mountPointURL.path];
}

- (NSComparisonResult) letterCompare: (BXDrive *)comparison
{
	return [self.letter caseInsensitiveCompare: comparison.letter];
}

@end
