/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXGameProfile.h"
#import "BXDrive.h"


//Directories larger than this size (in bytes) will be treated as CD-era games by eraOfGameAtPath:
const NSUInteger BXDisketteGameSizeThreshold = 20 * 1024 * 1024;

//Directories with any files older than this will be treated as 3.5 diskette-era games by eraOfGameAtPath:
NSString * const BX35DisketteGameDateThreshold = @"1995-01-01 00:00:00 +0000";

//Directories with any files older than this will be treated as 5.25 diskette-era games by eraOfGameAtPath:
NSString * const BX525DisketteGameDateThreshold = @"1988-01-01 00:00:00 +0000";



//Internal methods which should not be called outside BXGameProfile.
@interface BXGameProfile ()

//Loads, caches and returns the contents of GameProfiles.plist to avoid multiple hits to the filesystem.
+ (NSDictionary *) _gameProfileData;

//Generates, caches and returns an array of lookup tables in order of priority.
//Used by detectedProfileForPath: to perform detection in multiple passes of the file heirarchy.
+ (NSArray *) _lookupTables;

//Generates and returns a lookup table of filename->profile mappings for the specified set of profiles.
//Used by _lookupTables.
+ (NSDictionary *) _lookupTableForProfiles: (NSArray *)profiles;
@end



@implementation BXGameProfile
@synthesize gameName, confName, profileDescription;
@synthesize installMedium, gameEra, requiredDiskSpace, mountHelperDrivesDuringImport;

+ (BXGameEra) eraOfGameAtPath: (NSString *)basePath
{
	NSFileManager *manager = [NSFileManager defaultManager];
	NSDirectoryEnumerator *enumerator = [manager enumeratorAtPath: basePath];
	
	NSDate *cutoffDate525	= [NSDate dateWithString: BX525DisketteGameDateThreshold];
	NSDate *cutoffDate35	= [NSDate dateWithString: BX35DisketteGameDateThreshold];
	unsigned long long pathSize = 0;
	
	while ([enumerator nextObject])
	{
		NSDictionary *attrs = [enumerator fileAttributes];
		
		//The game was released before CDs became commonplace, treat it as a diskette game
		NSDate *creationDate = [attrs fileCreationDate];
		//TWEAK: if the date is 1970, then ignore it - this indicates a missing creation date
		if (creationDate && [creationDate timeIntervalSince1970] > 0)
		{
			if ([creationDate timeIntervalSinceDate: cutoffDate525] < 0)	return BX525DisketteEra;
			if ([creationDate timeIntervalSinceDate: cutoffDate35] < 0)		return BX35DisketteEra;
		}
		
		//The game is too big to have been released on diskettes, treat it as a CD game
		pathSize += [attrs fileSize];
		if (pathSize > BXDisketteGameSizeThreshold) return BXCDROMEra;
	}
	//When all else fails, assume it's a 3.5 diskette game
	return BX35DisketteEra;
}


+ (NSArray *) genericProfiles		{ return [[self _gameProfileData] objectForKey: @"BXGenericProfiles"]; }
+ (NSArray *) specificGameProfiles	{ return [[self _gameProfileData] objectForKey: @"BXSpecificGameProfiles"]; }


#pragma mark -
#pragma mark Initializers

+ (BXGameProfile *)detectedProfileForPath: (NSString *)basePath
						 searchSubfolders: (BOOL)searchSubfolders
{
	NSFileManager *manager	= [NSFileManager defaultManager];
	NSDictionary *matchingProfile;
	
	//_lookupTables is divided into separate sets of profiles in order of priority: game-specific
	//profiles followed by generic profiles.
	
	//We check the entire filesystem for one set of profiles first, before starting on the next:
	//This allows game-specific profiles to override generic ones that would otherwise match sooner.
	
	//FIXME: this approach may still be too näive and could return false positives when we have a
	//more specific game profile that is matched earlier by a less specific one. This could be fixed
	//by matching all profiles and then sorting them by 'relevance', at a cost of scanning the entire
	//file heirarchy for each profile (which is a big cost).
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
		[self setInstallMedium: BXDriveAutodetect];
		[self setRequiredDiskSpace: BXDefaultFreeSpace];
		[self setMountHelperDrivesDuringImport: YES];
		[self setGameEra: BXUnknownEra];
	}
	return self;
}

- (id) initWithDictionary: (NSDictionary *)profileDict
{
	if ((self = [self init]))
	{
		[self setGameName: [profileDict objectForKey: @"BXProfileName"]];
		[self setConfName: [profileDict objectForKey: @"BXProfileConf"]];
		[self setProfileDescription: [profileDict objectForKey: @"BXProfileDescription"]];
		
		//Leave these at their default values if a particular key wasn't specified
		NSNumber *medium = [profileDict objectForKey: @"BXInstallMedium"];
		if (medium) [self setInstallMedium: [medium integerValue]];
		
		NSNumber *requiredSpace = [profileDict objectForKey: @"BXRequiredDiskSpace"];
		if (requiredSpace) [self setRequiredDiskSpace: [requiredSpace integerValue]];
		
		NSNumber *mountHelperDrives = [profileDict objectForKey: @"BXMountHelperDrivesDuringImport"];
		if (mountHelperDrives) [self setMountHelperDrivesDuringImport: [mountHelperDrives boolValue]];
		
		NSNumber *era = [profileDict objectForKey: @"BXProfileGameEra"];
		if (era) [self setGameEra: [era unsignedIntegerValue]];
		
		//Used by isDesignatedInstallerAtPath:
		installerPatterns	= [[profileDict objectForKey: @"BXDesignatedInstallers"] retain];
		
		//Used by customDriveLabelForPath
		driveLabelMappings	= [[profileDict objectForKey: @"BXProfileDriveLabels"] retain];
	}
	return self;
}

- (void) dealloc
{
	[self setGameName: nil], [gameName release];
	[self setConfName: nil], [confName release];
	[self setProfileDescription: nil], [profileDescription release];
	
	[driveLabelMappings release], driveLabelMappings = nil;
	[installerPatterns release], installerPatterns = nil;
	
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

- (NSString *) labelForDrive: (BXDrive *)drive
{
	NSString *defaultLabel = [drive label];
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


#pragma mark -
#pragma mark Private methods
							   
+ (NSDictionary *) _gameProfileData
{
	//Cache the data in a static variable, since it will not change over the lifetime of the application
	//Todo: check if this caching is necessary, or if there's behind-the-scenes caching.
	static NSDictionary *dict = nil;
	if (!dict)
	{
		NSString *profilePath = [[NSBundle mainBundle] pathForResource: @"GameProfiles" ofType: @"plist"];
		dict = [[NSDictionary alloc] initWithContentsOfFile: profilePath]; 
	}
	return dict;
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
		for (NSString *telltale in [profile objectForKey: @"BXProfileTelltales"]) [lookups setObject: profile forKey: telltale]; 
	}
	return [lookups autorelease];
}

@end
