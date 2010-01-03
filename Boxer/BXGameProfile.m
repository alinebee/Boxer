/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXGameProfile.h"



//Directories larger than this size (in bytes) will be treated as CD games by isDisketteGameAtPath:
const NSInteger BXDisketteGameSizeThreshold = 20 * 1024 * 1024;

//Directories with any files older than this will be treated as diskette games by isDisketteGameAtPath:
NSString *BXDisketteGameDateThreshold = @"1995-01-01 00:00:00 +0000";


@implementation BXGameProfile

+ (NSArray *) genericProfiles		{ return [[self _gameProfileData] objectForKey: @"BXGenericProfiles"]; }
+ (NSArray *) specificGameProfiles	{ return [[self _gameProfileData] objectForKey: @"BXSpecificGameProfiles"]; }

+ (NSDictionary *)detectedProfileForPath: (NSString *)basePath
{
	NSFileManager *manager	= [NSFileManager defaultManager];
	NSDictionary *lookups	= [self _detectionLookups];
	NSDictionary *matchingProfile;
	
	for (NSString *path in [manager enumeratorAtPath: basePath])
	{
		//First check for an exact filename match
		NSString *fileName	= [[path lastPathComponent] lowercaseString];
		if (matchingProfile = [lookups objectForKey: fileName]) return matchingProfile;
		
		//Next, check if the base filename (sans extension) matches anything
		NSString *baseName	= [[fileName stringByDeletingPathExtension] stringByAppendingString: @"."];
		if (matchingProfile = [lookups objectForKey: baseName]) return matchingProfile;
	}
	//If we got this far, we couldn't find anything
	return nil;
}

+ (BOOL) isDisketteGameAtPath: (NSString *)basePath
{
	NSFileManager *manager = [NSFileManager defaultManager];
	NSDirectoryEnumerator *enumerator = [manager enumeratorAtPath: basePath];
	
	NSDate *cutoffDate = [NSDate dateWithString: BXDisketteGameDateThreshold];
	NSInteger pathSize = 0;
	
	for (NSString *filePath in enumerator)
	{
		NSDictionary *attrs = [enumerator fileAttributes];
		
		//The game was released before CDs became commonplace, treat it as a diskette game
		NSDate *creationDate = [attrs fileCreationDate];
		if ([creationDate timeIntervalSinceDate: cutoffDate] < 0) return YES;
		
		//The game is too big to have been released on diskettes, treat it as a CD game
		pathSize += [attrs fileSize];
		if (pathSize > BXDisketteGameSizeThreshold) return NO;
	}
	//When all else fails, let's call it a diskette game
	return YES;
}


@end

@implementation BXGameProfile (BXGameProfileInternals)
//Cache the data in a static variable, since it will not change over the lifetime of the application
//Todo: check if this caching is necessary, or if there's behind-the-scenes caching.
+ (NSDictionary *) _gameProfileData
{
	static NSDictionary *dict = nil;
	if (!dict)
	{
		NSString *profilePath = [[NSBundle mainBundle] pathForResource: @"GameProfiles" ofType:@"plist"];
		dict = [[NSDictionary alloc] initWithContentsOfFile: profilePath]; 
	}
	return dict;
}

+ (NSDictionary *) _detectionLookups
{
	static NSMutableDictionary *lookups = nil;
	if (!lookups)
	{
		lookups = [[NSMutableDictionary alloc] initWithCapacity: 200];
		NSArray *profiles = [[self specificGameProfiles] arrayByAddingObjectsFromArray: [self genericProfiles]];
		for (NSDictionary *profile in profiles)
		{
			for (NSString *telltale in [profile objectForKey: @"BXProfileTelltales"]) [lookups setObject: profile forKey: telltale]; 
		}
	}
	return lookups;
}
@end