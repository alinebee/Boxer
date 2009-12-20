/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXGameProfile.h"


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
		NSString *baseName	= [fileName stringByDeletingPathExtension];
		if (matchingProfile = [lookups objectForKey: baseName]) return matchingProfile;
	}
	//If we got this far, we couldn't find anything
	return nil;
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