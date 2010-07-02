/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXGameProfile.h"



//Directories larger than this size (in bytes) will be treated as CD-era games by eraOfGameAtPath:
const NSInteger BXDisketteGameSizeThreshold = 20 * 1024 * 1024;

//Directories with any files older than this will be treated as 3.5 diskette-era games by eraOfGameAtPath:
NSString * const BX35DisketteGameDateThreshold = @"1995-01-01 00:00:00 +0000";

//Directories with any files older than this will be treated as 5.25 diskette-era games by eraOfGameAtPath:
NSString * const BX525DisketteGameDateThreshold = @"1988-01-01 00:00:00 +0000";


@implementation BXGameProfile

+ (NSArray *) genericProfiles		{ return [[self _gameProfileData] objectForKey: @"BXGenericProfiles"]; }
+ (NSArray *) specificGameProfiles	{ return [[self _gameProfileData] objectForKey: @"BXSpecificGameProfiles"]; }

+ (NSDictionary *)detectedProfileForPath: (NSString *)basePath
{
	NSFileManager *manager	= [NSFileManager defaultManager];
	NSDictionary *matchingProfile;
	
	//_lookupTables is divided into separate sets of profiles in order of priority: game-specific
	//profiles followed by generic profiles.
	//We check the entire filesystem for one set of profiles first, before starting on the next:
	//This allows game-specific profiles to override generic ones that would otherwise match sooner.
	for (NSDictionary *lookups in [self _lookupTables])
	{
		for (NSString *path in [manager enumeratorAtPath: basePath])
		{
			//First check for an exact filename match
			NSString *fileName	= [[path lastPathComponent] lowercaseString];
			if (matchingProfile = [lookups objectForKey: fileName]) return matchingProfile;
			
			//Next, check if the base filename (sans extension) matches anything
			NSString *baseName	= [[fileName stringByDeletingPathExtension] stringByAppendingString: @"."];
			if (matchingProfile = [lookups objectForKey: baseName]) return matchingProfile;
		}		
	}
	//If we got this far, we couldn't find anything
	return nil;
}

+ (BXGameEra) eraOfGameAtPath: (NSString *)basePath
{
	NSFileManager *manager = [NSFileManager defaultManager];
	NSDirectoryEnumerator *enumerator = [manager enumeratorAtPath: basePath];
	
	NSDate *cutoffDate525	= [NSDate dateWithString: BX525DisketteGameDateThreshold];
	NSDate *cutoffDate35	= [NSDate dateWithString: BX35DisketteGameDateThreshold];
	NSInteger pathSize = 0;
	
	for (NSString *filePath in enumerator)
	{
		NSDictionary *attrs = [enumerator fileAttributes];
		
		//The game was released before CDs became commonplace, treat it as a diskette game
		NSDate *creationDate = [attrs fileCreationDate];
		if ([creationDate timeIntervalSinceDate: cutoffDate525] < 0)	return BX525DisketteEra;
		if ([creationDate timeIntervalSinceDate: cutoffDate35] < 0)		return BX35DisketteEra;
		
		//The game is too big to have been released on diskettes, treat it as a CD game
		pathSize += [attrs fileSize];
		if (pathSize > BXDisketteGameSizeThreshold) return BXCDROMEra;
	}
	//When all else fails, assume it's a 3.5 diskette game
	return BX35DisketteEra;
}


@end

@implementation BXGameProfile (BXGameProfileInternals)
							   
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