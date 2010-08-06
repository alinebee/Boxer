/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXImport+BXImportPolicies.h"
#import "NSWorkspace+BXMountedVolumes.h"
#import "NSWorkspace+BXFileTypes.h"
#import "RegexKitLite.h"

#import "BXAppController.h"


@implementation BXImport (BXImportPolicies)

#pragma mark -
#pragma mark Helper class methods

+ (NSSet *) playableGameTelltaleExtensions
{
	static NSSet *extensions = nil;
	if (!extensions) extensions = [NSSet setWithObjects:
								   @"conf",		//DOSBox conf files indicate an already-installed game
								   @"iso",		//Likewise with mountable disc images
								   @"cue",
								   @"cdr",
								   @"inst",
								   @"harddisk",	//Boxer drive folders indicate a former Boxer gamebox
								   @"cdrom",
								   @"floppy",
								   nil];
	return extensions;
}

+ (NSSet *) playableGameTelltalePatterns
{
	static NSSet *patterns = nil;
	if (!patterns) patterns = [NSSet setWithObjects:
							   nil];
	return patterns;
}

+ (NSSet *) installerPatterns
{
	static NSSet *patterns = nil;
	if (!patterns) patterns = [NSSet setWithObjects:
							   @"inst",
							   @"setup",
							   @"config",
							   @"^origin.bat$",
							   @"^initial.exe$",
							   nil];
	return patterns;
}

+ (NSArray *) preferredInstallerPatterns
{
	static NSArray *patterns = nil;
	if (!patterns) patterns = [NSArray arrayWithObjects:
							   @"^dosinst\\.",
							   @"^install\\.",
							   @"^hdinstal\\.",
							   @"setup\\.",
							   @"inst",
							   nil];
	return patterns;
}

+ (BOOL) isInstallerAtPath: (NSString *)path
{
	path = [path lowercaseString];
	for (NSString *pattern in [self installerPatterns])
	{
		if ([path isMatchedByRegex: pattern]) return YES;
	}
	return NO;
}

+ (BOOL) isPlayableGameTelltaleAtPath: (NSString *)path
{
	path = [path lowercaseString];
	
	//Do a quick test first using just the extension
	if ([[self playableGameTelltaleExtensions] containsObject: [path pathExtension]]) return YES;
	
	//Next, test for filename patterns
	for (NSString *pattern in [self playableGameTelltalePatterns])
	{
		if ([path isMatchedByRegex: pattern]) return YES;
	}
	
	return NO;
}


+ (BXInstallStatus) installStatusOfGameAtPath: (NSString *)path
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSFileManager *manager = [NSFileManager defaultManager];
	
	path = [path stringByStandardizingPath];
	
	//If the game is on CD, then it's definitely not installed
	if ([workspace volumeTypeForPath: path] == dataCDVolumeType) return BXInstallStatusNotInstalled;
	
	BOOL hasInstallers = NO;
	NSDirectoryEnumerator *enumerator = [manager enumeratorAtPath: path];
	for (NSString *subPath in enumerator)
	{
		NSString *fullPath = [path stringByAppendingPathComponent: subPath];
		
		//If the path contains any playable-game telltale files, it's definitely installed
		if ([self isPlayableGameTelltaleAtPath: fullPath]) return BXInstallStatusInstalled;
		
		//Check if the source path contains any known installers.
		//(We stop checking after we've found the first one, but keep scanning the other files
		//in case we get a more authoritative result from other checks)
		if (!hasInstallers) hasInstallers = [self isInstallerAtPath: fullPath];
	}
	
	//If the source path has no installers in it, then assume that it's probably already installed
	//(it may not be - we may just not recognise the installer - so we can't be sure)
	if (!hasInstallers) return BXInstallStatusProbablyInstalled;
	
	//If all else fails, assume the game is probably not installed
	return BXInstallStatusProbablyNotInstalled;
}

+ (BOOL) shouldImportSourceFilesFromPath: (NSString *)path
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	
	//If the source path is a mountable image, it should be imported
	if ([workspace file: path matchesTypes: [BXAppController mountableImageTypes]]) return YES;
	
	//If the source path is on a CD, it should be imported
	if ([workspace volumeTypeForPath: path] == dataCDVolumeType) return YES;
	
	//If the source path looks CD-sized, it should be imported
	unsigned long long pathSize = 0;
	NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath: path];
	while ([enumerator nextObject])
	{
		NSDictionary *attrs = [enumerator fileAttributes];
		pathSize += [attrs fileSize];
		
		if (pathSize > BXCDROMSizeThreshold) return YES;
	}
	
	return NO;
}

@end