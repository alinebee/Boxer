/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXGameProfile.h"
#import "BXDrive.h"

NSString * const BXGenericProfileIdentifier = @"net.washboardabs.generic";

//Directories larger than this size (in bytes) will be treated as CD-era games by eraOfGameAtPath:
const NSUInteger BXDisketteGameSizeThreshold = 20 * 1024 * 1024;

//Directories with any files older than this will be treated as 3.5 diskette-era games by eraOfGameAtPath:
NSString * const BX35DisketteGameDateThreshold = @"1995-01-01 00:00:00 +0000";

//Directories with any files older than this will be treated as 5.25 diskette-era games by eraOfGameAtPath:
NSString * const BX525DisketteGameDateThreshold = @"1988-01-01 00:00:00 +0000";

//File timestamps older than this will be ignored as invalid.
NSString * const BXInvalidGameDateThreshold = @"1981-01-01 00:00:00 +0000";



//Internal methods which should not be called outside BXGameProfile.
@interface BXGameProfile ()

//Loads, caches and returns the contents of GameProfiles.plist to avoid multiple hits to the filesystem.
+ (NSDictionary *) _gameProfileData;

//Generates, caches and returns a dictionary of identifier -> profile lookups.
//Used by profileWithIdentifier:
+ (NSDictionary *) _identifierIndex;

//Generates, caches and returns an array of lookup tables in order of priority.
//Used by detectedProfileForPath: to perform detection in multiple passes of the file heirarchy.
+ (NSArray *) _lookupTables;

//Generates and returns a lookup table of filename->profile mappings for the specified set of profiles.
//Used by _lookupTables.
+ (NSDictionary *) _lookupTableForProfiles: (NSArray *)profiles;
@end


@implementation BXGameProfile

@synthesize gameName, configurations, identifier, profileDescription;
@synthesize sourceDriveType, coverArtMedium, requiredDiskSpace, mountHelperDrivesDuringImport, mountTempDrive, requiresCDROM;

+ (BXReleaseMedium) mediumOfGameAtPath: (NSString *)basePath
{
    //TODO: check first if the base path is a disc image or an external volume,
    //and if so return a medium based on the size and type of volume/image.
    
    
    //Scan the size and age of the files in the folder to determine what kind of media
    //the game probably used.
    
	NSFileManager *manager = [NSFileManager defaultManager];
	NSDirectoryEnumerator *enumerator = [manager enumeratorAtPath: basePath];
	
	NSDate *cutoffDate525       = [NSDate dateWithString: BX525DisketteGameDateThreshold];
	NSDate *cutoffDate35        = [NSDate dateWithString: BX35DisketteGameDateThreshold];
	NSDate *cutoffDateInvalid	= [NSDate dateWithString: BXInvalidGameDateThreshold];
	unsigned long long pathSize = 0;
	
	while ([enumerator nextObject])
	{
		NSDictionary *attrs = [enumerator fileAttributes];
		NSDate *creationDate = [attrs fileCreationDate];
        
        //If the file timestamps suggest the game was released before CDs
        //became commonplace, treat it as a diskette game.
		if (creationDate && [creationDate timeIntervalSinceDate: cutoffDateInvalid] > 0)
		{
			if ([creationDate timeIntervalSinceDate: cutoffDate525] < 0)	return BX525DisketteMedium;
			if ([creationDate timeIntervalSinceDate: cutoffDate35] < 0)		return BX35DisketteMedium;
		}
		
		//If the game is too big to have been released on diskettes, treat it as a CD game
		pathSize += [attrs fileSize];
		if (pathSize > BXDisketteGameSizeThreshold) return BXCDROMMedium;
	}
    
	//When all else fails, assume it's a 3.5 diskette game
	return BX35DisketteMedium;
}

+ (NSString *) catalogueVersion     { return [[self _gameProfileData] objectForKey: @"BXGameProfileCatalogueVersion"]; }
+ (NSArray *) genericProfiles		{ return [[self _gameProfileData] objectForKey: @"BXGenericProfiles"]; }
+ (NSArray *) specificGameProfiles	{ return [[self _gameProfileData] objectForKey: @"BXSpecificGameProfiles"]; }


#pragma mark -
#pragma mark Initializers

+ (id) genericProfile
{
    return [[[self alloc] init] autorelease];
}

+ (id) profileWithIdentifier: (NSString *)identifier
{
    if ([identifier isEqualToString: BXGenericProfileIdentifier])
    {
        return [[[self alloc] init] autorelease];
    }
    else
    {
        NSDictionary *profileData = [[self _identifierIndex] objectForKey: identifier];
        if (profileData) return [[[self alloc] initWithDictionary: profileData] autorelease];
        else return nil;
    }
}

+ (id) detectedProfileForPath: (NSString *)basePath
						  searchSubfolders: (BOOL)searchSubfolders
{
	NSFileManager *manager	= [NSFileManager defaultManager];
	NSDictionary *matchingProfile;
	
	//_lookupTables is divided into separate sets of profiles in order of priority: game-specific
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
			NSString *fileName	= [[path lastPathComponent] lowercaseString];
			if ((matchingProfile = [lookups objectForKey: fileName]))
				return [[[self alloc] initWithDictionary: matchingProfile] autorelease];
			
			//Next, check if the base filename (sans extension) matches anything
			//TODO: eliminate this branch, and just use explicit filenames in the profile telltales.
			NSString *baseName	= [[fileName stringByDeletingPathExtension] stringByAppendingString: @".*"];
			if ((matchingProfile = [lookups objectForKey: baseName]))
				return [[[self alloc] initWithDictionary: matchingProfile] autorelease];
		}		
	}
	
	return nil;
}

- (id) init
{
	if ((self = [super init]))
	{
		//Set our standard defaults
		[self setSourceDriveType: BXDriveAutodetect];
		[self setRequiredDiskSpace: BXDefaultFreeSpace];
		[self setMountHelperDrivesDuringImport: YES];
        [self setMountTempDrive: YES];
		[self setCoverArtMedium: BXUnknownMedium];
        [self setIdentifier: BXGenericProfileIdentifier];
	}
	return self;
}

- (id) initWithDictionary: (NSDictionary *)profileDict
{
	if ((self = [self init]))
	{
        [self setIdentifier:            [profileDict objectForKey: @"BXProfileIdentifier"]];
		[self setGameName:              [profileDict objectForKey: @"BXProfileGameName"]];
		[self setProfileDescription:    [profileDict objectForKey: @"BXProfileDescription"]];
		[self setConfigurations:        [profileDict objectForKey: @"BXProfileConfigurations"]];
		
		//Leave these at their default values if a particular key wasn't specified
		NSNumber *medium = [profileDict objectForKey: @"BXSourceDriveType"];
		if (medium)
        {
            [self setSourceDriveType: [medium integerValue]];
            //If the profile mandates that the game must be installed from CD-ROM, use that for cover art too;
            //otherwise, let the upstream context decide, since the source drive type doesn't distinguish
            //between 3.5" and 3.25" floppies.
            if ([medium integerValue] == BXDriveCDROM)
                [self setCoverArtMedium: BXCDROMMedium];
        }
		
		NSNumber *requiredSpace = [profileDict objectForKey: @"BXRequiredDiskSpace"];
		if (requiredSpace) [self setRequiredDiskSpace: [requiredSpace integerValue]];
		
		NSNumber *mountHelperDrives = [profileDict objectForKey: @"BXMountHelperDrivesDuringImport"];
		if (mountHelperDrives) [self setMountHelperDrivesDuringImport: [mountHelperDrives boolValue]];
        
		NSNumber *mountTemporaryDrive = [profileDict objectForKey: @"BXMountTempDrive"];
		if (mountTemporaryDrive) [self setMountTempDrive: [mountTemporaryDrive boolValue]];
        
		NSNumber *needsCDROM = [profileDict objectForKey: @"BXRequiresCDROM"];
		if (needsCDROM) [self setRequiresCDROM: [needsCDROM boolValue]];
		
		NSNumber *era = [profileDict objectForKey: @"BXProfileGameEra"];
		if (era) [self setCoverArtMedium: [era unsignedIntegerValue]];
		
		//Used by isDesignatedInstallerAtPath:
		installerPatterns	= [[profileDict objectForKey: @"BXDesignatedInstallers"] retain];
        
        //Used by isIgnoredInstallerAtPath:
        ignoredInstallerPatterns = [[profileDict objectForKey: @"BXIgnoredInstallers"] retain];
		
		//Used by volumeLabelForDrive:
		driveLabelMappings	= [[profileDict objectForKey: @"BXProfileDriveLabels"] retain];
	}
	return self;
}

- (void) dealloc
{
    [self setIdentifier: nil], [identifier release];
	[self setGameName: nil], [gameName release];
	[self setConfigurations: nil], [configurations release];
	[self setProfileDescription: nil], [profileDescription release];
	
	[driveLabelMappings release], driveLabelMappings = nil;
	[installerPatterns release], installerPatterns = nil;
    [ignoredInstallerPatterns release], ignoredInstallerPatterns = nil;
	
	[super dealloc];
}

- (NSString *) description
{
	if ([self gameName]) return [self gameName];
	if ([self profileDescription]) return [self profileDescription];
	return [super description];
}

#pragma mark -
#pragma mark Methods affecting emulation behaviour

- (NSString *) volumeLabelForDrive: (BXDrive *)drive
{
	NSString *defaultLabel = [drive volumeLabel];
	//If we don't have any label overrides, just use its original label
	if (![driveLabelMappings count]) return defaultLabel;
	
	NSString *customLabel			= [driveLabelMappings objectForKey: defaultLabel];
	if (!customLabel) customLabel	= [driveLabelMappings objectForKey: @"BXProfileDriveLabelAny"];
	
	if (customLabel) return customLabel;
	return defaultLabel;
}

- (BOOL) isDesignatedInstallerAtPath: (NSString *)path
{
	if (!installerPatterns) return NO;
	path = [path lowercaseString];
	for (NSString *pattern in installerPatterns)
	{
		if ([path hasSuffix: pattern]) return YES;
	}
	return NO;
}

- (BOOL) isIgnoredInstallerAtPath: (NSString *)path
{
	if (!ignoredInstallerPatterns) return NO;
	path = [path lowercaseString];
	for (NSString *pattern in ignoredInstallerPatterns)
	{
		if ([path hasSuffix: pattern]) return YES;
	}
	return NO;
}

#pragma mark -
#pragma mark Private methods
							   
+ (NSDictionary *) _gameProfileData
{
	static NSDictionary *dict = nil;
	if (!dict)
	{
		NSString *profilePath = [[NSBundle mainBundle] pathForResource: @"GameProfiles" ofType: @"plist"];
		dict = [[NSDictionary alloc] initWithContentsOfFile: profilePath];
	}
	return dict;
}

+ (NSDictionary *) _identifierIndex
{
    static NSMutableDictionary *lookups = nil;
    if (!lookups)
    {
        lookups = [[NSMutableDictionary alloc] initWithCapacity: 200];
        NSArray *allProfiles = [[self specificGameProfiles] arrayByAddingObjectsFromArray: [self genericProfiles]];
        
        for (NSDictionary *profile in allProfiles)
        {
            NSString *identifier = [profile objectForKey: @"BXProfileIdentifier"];
            if (identifier) [lookups setObject: profile forKey: identifier];
        }
    }
    return lookups;
}

+ (NSArray *) _lookupTables
{
	static NSArray *lookupTables = nil;
	if (!lookupTables)
	{
		lookupTables = [[NSArray alloc] initWithObjects:
						[self _lookupTableForProfiles: [self specificGameProfiles]],
						[self _lookupTableForProfiles: [self genericProfiles]],
						nil];
	}
	return lookupTables;
}
							   
+ (NSDictionary *) _lookupTableForProfiles: (NSArray *)profiles
{
	NSMutableDictionary *lookups = [[NSMutableDictionary alloc] initWithCapacity: 200];
	for (NSDictionary *profile in profiles)
	{
		for (NSString *telltale in [profile objectForKey: @"BXProfileTelltales"])
            [lookups setObject: profile forKey: telltale]; 
	}
	return [lookups autorelease];
}

@end
