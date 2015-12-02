/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXGameProfile.h"
#import "BXDrive.h"
#import "ADBScanOperation.h"
#import "ADBFilesystem.h"

NSString * const BXGenericProfileIdentifier = @"net.washboardabs.generic";

//Directories larger than this size (in bytes) will be treated as CD-era games by eraOfGameAtPath:
const NSUInteger BXDisketteGameSizeThreshold = 30 * 1024 * 1024;

//Directories with any files older than this will be treated as 3.5 diskette-era games by eraOfGameAtPath:
NSString * const BX35DisketteGameDateThreshold = @"1994-01-01 00:00:00 +0000";

//Directories with any files older than this will be treated as 5.25 diskette-era games by eraOfGameAtPath:
NSString * const BX525DisketteGameDateThreshold = @"1988-01-01 00:00:00 +0000";

//File timestamps older than this will be ignored as invalid.
NSString * const BXInvalidGameDateThreshold = @"1981-01-01 00:00:00 +0000";



//Internal methods which should not be called outside BXGameProfile.
@interface BXGameProfile ()

@property (strong, nonatomic) NSArray *installerPatterns;
@property (strong, nonatomic) NSArray *ignoredInstallerPatterns;
@property (strong, nonatomic) NSDictionary *driveLabelMappings;

//Loads, caches and returns the contents of GameProfiles.plist to avoid multiple hits to the filesystem.
+ (NSDictionary *) _gameProfileData;

//Generates, caches and returns a dictionary of identifier -> profile lookups.
//Used by profileWithIdentifier:
+ (NSDictionary *) _identifierIndex;

//Generates, caches and returns an array of lookup tables in order of priority.
//Used by detectedProfileForPath: to perform detection in multiple passes of the file hierarchy.
+ (NSArray *) _lookupTables;

//Generates and returns a lookup table of filename->profile mappings for the specified set of profiles.
//Used by _lookupTables.
+ (NSDictionary *) _lookupTableForProfiles: (NSArray *)profiles;

@end


@implementation BXGameProfile
@synthesize priority = _priority;
@synthesize gameName = _gameName;
@synthesize configurations = _configurations;
@synthesize identifier = _identifier;
@synthesize profileDescription = _profileDescription;
@synthesize sourceDriveType = _sourceDriveType;
@synthesize releaseMedium = _coverArtMedium;
@synthesize requiredDiskSpace = _requiredDiskSpace;
@synthesize shouldMountHelperDrivesDuringImport = _shouldMountHelperDrivesDuringImport;
@synthesize shouldMountTempDrive = _shouldMountTempDrive;
@synthesize requiresCDROM = _requiresCDROM;

@synthesize installerPatterns = _installerPatterns;
@synthesize ignoredInstallerPatterns = _ignoredInstallerPatterns;
@synthesize driveLabelMappings = _driveLabelMappings;

@synthesize shouldImportMountCommands = _shouldImportMountCommands;
@synthesize shouldImportLaunchCommands = _shouldImportLaunchCommands;
@synthesize shouldImportSettings = _shouldImportSettings;
@synthesize preferredInstallationFolderPath = _preferredInstallationFolderPath;

+ (BXReleaseMedium) mediumOfGameAtURL: (NSURL *)baseURL
{
    //TODO: check first if the base path is a disc image or an external volume,
    //and if so return a medium based on the size and type of volume/image.
    
    //Scan the size and age of the files in the folder to determine what kind of media
    //the game probably used.
    NSArray *propertyKeys = @[NSURLCreationDateKey, NSURLFileSizeKey];
	NSFileManager *manager = [NSFileManager defaultManager];
	NSDirectoryEnumerator *enumerator = [manager enumeratorAtURL: baseURL
                                      includingPropertiesForKeys: propertyKeys
                                                         options: NSDirectoryEnumerationSkipsHiddenFiles
                                                    errorHandler: NULL];
	
	NSDate *cutoffDate525       = [NSDate dateWithString: BX525DisketteGameDateThreshold];
	NSDate *cutoffDate35        = [NSDate dateWithString: BX35DisketteGameDateThreshold];
	NSDate *cutoffDateInvalid	= [NSDate dateWithString: BXInvalidGameDateThreshold];
	unsigned long long pathSize = 0;
	
	for (NSURL *URL in enumerator)
	{
        NSDictionary *attrs = [URL resourceValuesForKeys: propertyKeys error: NULL];
        if (!attrs)
            continue;
        
		NSDate *creationDate = [attrs objectForKey: NSURLCreationDateKey];
        
        //If the file timestamps suggest the game was released before CDs
        //became commonplace, treat it as a diskette game.
		if (creationDate && [creationDate timeIntervalSinceDate: cutoffDateInvalid] > 0)
		{
			if ([creationDate timeIntervalSinceDate: cutoffDate525] < 0)
                return BX525DisketteMedium;
            
			if ([creationDate timeIntervalSinceDate: cutoffDate35] < 0)
                return BX35DisketteMedium;
		}
		
        
		//If the game is too big to have been released on diskettes, treat it as a CD game
		unsigned long long fileSize = [[attrs objectForKey: NSURLFileSizeKey] unsignedLongLongValue];
        pathSize += fileSize;
		if (pathSize > BXDisketteGameSizeThreshold)
            return BXCDROMMedium;
	}
    
	//When all else fails, assume it's a 3.5 diskette game
	return BX35DisketteMedium;
}

+ (NSString *) catalogueVersion
{
    return [[self _gameProfileData] objectForKey: @"BXGameProfileCatalogueVersion"];
}
+ (NSArray *) genericProfiles
{
    return [[self _gameProfileData] objectForKey: @"BXGenericProfiles"];
}
+ (NSArray *) specificGameProfiles
{
    return [[self _gameProfileData] objectForKey: @"BXSpecificGameProfiles"];
}


#pragma mark -
#pragma mark Initializers

+ (id) genericProfile
{
    return [[self alloc] init];
}

+ (id) profileWithIdentifier: (NSString *)identifier
{
    if ([identifier isEqualToString: BXGenericProfileIdentifier])
    {
        return [[self alloc] init];
    }
    else
    {
        NSDictionary *profileData = [[self _identifierIndex] objectForKey: identifier];
        if (profileData) return [[self alloc] initWithDictionary: profileData];
        else return nil;
    }
}

+ (id) detectedProfileForPath: (NSString *)basePath
             searchSubfolders: (BOOL)searchSubfolders
{
	NSFileManager *manager	= [NSFileManager defaultManager];
	NSDictionary *matchingProfile;
	
	//lookupTables is divided into separate sets of profiles in order of priority: game-specific
	//profiles followed by generic profiles.
	
	//We check the entire filesystem for one set of profiles first, before starting on the next:
	//This allows game-specific profiles to override generic ones that would otherwise match sooner.
	for (NSDictionary *lookups in [self _lookupTables])
	{
		NSDirectoryEnumerator *enumerator = [manager enumeratorAtPath: basePath];
		for (NSString *path in enumerator)
		{
			//Don't descend into any subfolders if not asked to
			if (!searchSubfolders) [enumerator skipDescendents];
			
			//First check for an exact filename match
			NSString *fileName	= path.lastPathComponent.lowercaseString;
			if ((matchingProfile = [lookups objectForKey: fileName]))
				return [[self alloc] initWithDictionary: matchingProfile];
			
			//Next, check if the base filename (sans extension) matches anything
			//TODO: eliminate this branch, and just use explicit filenames in the profile telltales.
			NSString *baseName	= [fileName.stringByDeletingPathExtension stringByAppendingString: @".*"];
			if ((matchingProfile = [lookups objectForKey: baseName]))
				return [[self alloc] initWithDictionary: matchingProfile];
		}
	}
	
	return nil;
}

+ (BXGameProfile *) profileMatchingPath: (NSString *)path
                           inFilesystem: (id<ADBFilesystemPathAccess>)filesystem
{
    NSArray *lookupTables = [self _lookupTables];
    NSUInteger numLookups = lookupTables.count;
    
    NSString *filename = path.lastPathComponent.lowercaseString;
    NSString *wildcardFilename = [filename.stringByDeletingPathExtension stringByAppendingString: @".*"];
    
    for (NSUInteger i=0; i<numLookups; i++)
    {
        NSDictionary *lookups = [lookupTables objectAtIndex: i];
        NSDictionary *matchingProfile = [lookups objectForKey: filename];
        if (!matchingProfile)
            matchingProfile = [lookups objectForKey: wildcardFilename];
        
        if (matchingProfile)
        {
            //Give earlier lookup tables higher priority than later ones:
            //our lookup tables are ordered from most specific to most generic.
            NSUInteger priorityMultiplier = numLookups - i;
            
            BXGameProfile *profile = [[self alloc] initWithDictionary: matchingProfile];
            profile.priority *= priorityMultiplier;
            
            return profile;
        }
    }
    return nil;
}

+ (NSEnumerator *) profilesDetectedInContentsOfEnumerator: (id <ADBFilesystemPathEnumeration>)enumerator
{
    ADBScanCallback callback = ^id(NSString *path, BOOL *outStop) {
        return [self profileMatchingPath: path inFilesystem: enumerator.filesystem];
    };
    
    return [ADBScanningEnumerator enumeratorWithEnumerator: enumerator usingBlock: callback];
}

+ (ADBScanOperation *) profileScanWithEnumerator: (id <ADBFilesystemPathEnumeration>)enumerator
{
    ADBScanCallback callback = ^id(NSString *path, BOOL *outStop) {
        return [self profileMatchingPath: path inFilesystem: enumerator.filesystem];
    };
    
    return [ADBScanOperation scanWithEnumerator: enumerator usingBlock: callback];
}

- (id) init
{
	if ((self = [super init]))
	{
		//Set our standard defaults
        self.priority = 1;
        self.identifier = BXGenericProfileIdentifier;
        
        self.sourceDriveType = BXDriveAutodetect;
        self.requiredDiskSpace = BXDefaultFreeSpace;
        self.shouldMountHelperDrivesDuringImport = YES;
        self.shouldMountTempDrive = YES;
        self.releaseMedium = BXUnknownMedium;
        
        self.shouldImportMountCommands = YES;
        self.shouldImportLaunchCommands = YES;
        self.shouldImportSettings = YES;
	}
	return self;
}

- (id) initWithDictionary: (NSDictionary *)profileDict
{
	if ((self = [self init]))
	{
        self.identifier         = [profileDict objectForKey: @"BXProfileIdentifier"];
        self.gameName           = [profileDict objectForKey: @"BXProfileGameName"];
        self.profileDescription = [profileDict objectForKey: @"BXProfileDescription"];
        self.configurations     = [profileDict objectForKey: @"BXProfileConfigurations"];
		
		//Leave these at their default values if a particular key wasn't specified
		NSNumber *medium = [profileDict objectForKey: @"BXSourceDriveType"];
		if (medium)
        {
            self.sourceDriveType = medium.integerValue;
            
            //If the profile mandates that the game must be installed from CD-ROM, use that for cover art too;
            //otherwise, let the upstream context decide, since the source drive type doesn't distinguish
            //between 3.5" and 3.25" floppies.
            if (self.sourceDriveType == BXDriveCDROM)
                self.releaseMedium = BXCDROMMedium;
        }
		
		NSNumber *requiredSpace = [profileDict objectForKey: @"BXRequiredDiskSpace"];
		if (requiredSpace)
            self.requiredDiskSpace = requiredSpace.integerValue;
		
		NSNumber *mountHelperDrives = [profileDict objectForKey: @"BXMountHelperDrivesDuringImport"];
		if (mountHelperDrives)
            self.shouldMountHelperDrivesDuringImport = mountHelperDrives.boolValue;
        
		NSNumber *mountTemporaryDrive = [profileDict objectForKey: @"BXMountTempDrive"];
		if (mountTemporaryDrive)
            self.shouldMountTempDrive = mountTemporaryDrive.boolValue;
        
		NSNumber *needsCDROM = [profileDict objectForKey: @"BXRequiresCDROM"];
		if (needsCDROM)
            self.requiresCDROM = needsCDROM.boolValue;
		
		NSNumber *era = [profileDict objectForKey: @"BXProfileGameEra"];
		if (era)
            self.releaseMedium = era.unsignedIntegerValue;
        
		NSNumber *importMountCommands = [profileDict objectForKey: @"BXShouldImportMountCommands"];
		if (importMountCommands)
            self.shouldImportMountCommands = importMountCommands.boolValue;
        
		NSNumber *importLaunchCommands = [profileDict objectForKey: @"BXShouldImportLaunchCommands"];
		if (importLaunchCommands)
            self.shouldImportLaunchCommands = importLaunchCommands.boolValue;
        
		NSNumber *importSettings = [profileDict objectForKey: @"BXShouldImportSettings"];
		if (importSettings)
            self.shouldImportSettings = importSettings.boolValue;
		
		NSNumber *priorityLevel = [profileDict objectForKey: @"BXPriority"];
		if (priorityLevel)
            self.priority = priorityLevel.unsignedIntegerValue;
        
        self.preferredInstallationFolderPath = [profileDict objectForKey: @"BXPreferredInstallationFolderPath"];
        
		//Used by isDesignatedInstallerAtPath:
		self.installerPatterns	= [profileDict objectForKey: @"BXDesignatedInstallers"];
        
        //Used by isIgnoredInstallerAtPath:
        self.ignoredInstallerPatterns = [profileDict objectForKey: @"BXIgnoredInstallers"];
		
		//Used by volumeLabelForDrive:
		self.driveLabelMappings	= [profileDict objectForKey: @"BXProfileDriveLabels"];
	}
	return self;
}

- (NSString *) description
{
	if (self.gameName)
        return self.gameName;
	
    else if (self.profileDescription)
        return self.profileDescription;
    
    else
        return super.description;
}

#pragma mark -
#pragma mark Methods affecting emulation behaviour

- (NSString *) volumeLabelForDrive: (BXDrive *)drive
{
	NSString *defaultLabel = drive.volumeLabel;
	//If we don't have any label overrides, just use its original label
	if (!self.driveLabelMappings.count) return defaultLabel;
	
	NSString *customLabel			= [self.driveLabelMappings objectForKey: defaultLabel];
	if (!customLabel) customLabel	= [self.driveLabelMappings objectForKey: @"BXProfileDriveLabelAny"];
	
	if (customLabel) return customLabel;
	else return defaultLabel;
}

- (BOOL) isDesignatedInstallerAtPath: (NSString *)path
{
	if (!self.installerPatterns.count) return NO;
    
	path = path.lowercaseString;
	for (NSString *pattern in self.installerPatterns)
	{
		if ([path hasSuffix: pattern]) return YES;
	}
	return NO;
}

- (BOOL) isIgnoredInstallerAtPath: (NSString *)path
{
	if (!self.ignoredInstallerPatterns.count) return NO;
    
	path = path.lowercaseString;
	for (NSString *pattern in self.ignoredInstallerPatterns)
	{
		if ([path hasSuffix: pattern]) return YES;
	}
	return NO;
}

#pragma mark - Private methods
							   
+ (NSDictionary *) _gameProfileData
{
	static NSDictionary *dict;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURL *profileURL = [[NSBundle mainBundle] URLForResource: @"GameProfiles" withExtension: @"plist"];
        dict = [[NSDictionary alloc] initWithContentsOfURL: profileURL];
    });
	return dict;
}

+ (NSDictionary *) _identifierIndex
{
    static NSMutableDictionary *lookups;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lookups = [[NSMutableDictionary alloc] initWithCapacity: 200];
        for (NSDictionary *profile in [self specificGameProfiles])
        {
            NSString *identifier = [profile objectForKey: @"BXProfileIdentifier"];
            if (identifier)
            {
                NSAssert1([lookups objectForKey: identifier] == nil, @"Duplicate profile identifier: %@", identifier);
                [lookups setObject: profile forKey: identifier];
            }
        }
        
        for (NSDictionary *profile in [self genericProfiles])
        {
            NSString *identifier = [profile objectForKey: @"BXProfileIdentifier"];
            if (identifier)
            {
                NSAssert1([lookups objectForKey: identifier] == nil, @"Duplicate profile identifier: %@", identifier);
                [lookups setObject: profile forKey: identifier];
            }
        }
    });
    return lookups;
}

+ (NSArray *) _lookupTables
{
	static NSArray *lookupTables;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
		lookupTables = [[NSArray alloc] initWithObjects:
						[self _lookupTableForProfiles: [self specificGameProfiles]],
						[self _lookupTableForProfiles: [self genericProfiles]],
						nil];
	});
	return lookupTables;
}
							   
+ (NSDictionary *) _lookupTableForProfiles: (NSArray *)profiles
{
	NSMutableDictionary *lookups = [[NSMutableDictionary alloc] initWithCapacity: 200];
	for (NSDictionary *profile in profiles)
	{
		for (NSString *telltale in [profile objectForKey: @"BXProfileTelltales"])
        {
            NSAssert1([lookups objectForKey: telltale] == nil, @"Duplicate profile telltale: %@", telltale);
            [lookups setObject: profile forKey: telltale];
        }
	}
	return lookups;
}

@end
