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
#import "NSString+BXPaths.h"

#import "BXAppController.h"


@implementation BXImport (BXImportPolicies)

#pragma mark -
#pragma mark Detecting installers

+ (NSSet *) installerPatterns
{
	static NSSet *patterns = nil;
	if (!patterns) patterns = [[NSSet alloc] initWithObjects:
							   @"inst",
							   @"setup",
							   @"config",
							   @"^origin\\.bat$",	//FIXME: should this be in a game profile?
							   nil];
	return patterns;
}

+ (NSArray *) preferredInstallerPatterns
{
	static NSArray *patterns = nil;
	if (!patterns) patterns = [[NSArray alloc] initWithObjects:
							   @"^dosinst",
							   @"^install\\.",
							   @"^hdinstal\\.",
							   @"^setup\\.",
							   nil];
	return patterns;
}

+ (BOOL) isInstallerAtPath: (NSString *)path
{	
	NSString *fileName = [[path lastPathComponent] lowercaseString];
	
	for (NSString *pattern in [self installerPatterns])
	{
		if ([fileName isMatchedByRegex: pattern]) return YES;
	}
	return NO;
}


#pragma mark -
#pragma mark Detecting files not to import

+ (NSSet *) junkFilePatterns
{
	static NSSet *patterns = nil;
	if (!patterns) patterns = [[NSSet alloc] initWithObjects:
							   @"\\.ico$",						//Windows icon files
							   @"\\.pif$",						//Windows PIF files
							   @"\\.conf$",						//DOSBox configuration files
							   @"^dosbox$",						//Anything DOSBox-related
							   @"^goggame.dll$",				//GOG launcher files
							   @"^unins000\\.",					//GOG uninstaller files
							   @"^Graphic mode setup\\.exe$",	//GOG configuration programs
							   @"^gogwrap.exe$",				//GOG only knows what this one does
							   nil];
	return patterns;
}

+ (BOOL) isJunkFileAtPath: (NSString *)path
{
	path = [[path lastPathComponent] lowercaseString];
	for (NSString *pattern in [self junkFilePatterns])
	{
		if ([path isMatchedByRegex: pattern]) return YES;
	}
	return NO;
}


#pragma mark -
#pragma mark Detecting whether a game is already installed

+ (NSSet *) playableGameTelltaleExtensions
{
	static NSSet *extensions = nil;
	if (!extensions) extensions = [[NSSet alloc] initWithObjects:
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
	if (!patterns) patterns = [[NSSet alloc] initWithObjects:
							   nil];
	return patterns;
}

+ (BOOL) isPlayableGameTelltaleAtPath: (NSString *)path
{
	path = [[path lastPathComponent] lowercaseString];
	
	//Do a quick test first using just the extension
	if ([[self playableGameTelltaleExtensions] containsObject: [path pathExtension]]) return YES;
	
	//Next, test against our filename patterns
	for (NSString *pattern in [self playableGameTelltalePatterns])
	{
		if ([path isMatchedByRegex: pattern]) return YES;
	}
	
	return NO;
}


#pragma mark -
#pragma mark Deciding how best to import a game

+ (NSArray *) executablesAtPath: (NSString *)path recurse: (BOOL)scanSubdirs
{
	NSMutableArray *executables = [NSMutableArray arrayWithCapacity: 10];
	
	NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath: path];
	
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSSet *executableTypes = [BXAppController executableTypes];
	
	for (NSString *subPath in enumerator)
	{
		if (!scanSubdirs) [enumerator skipDescendents];
		
		NSDictionary *attrs = [enumerator fileAttributes];
		
		//Skip directories
		if (![[attrs fileType] isEqualToString: NSFileTypeRegular]) continue;
		
		//Skip dot-hidden files (since these are probably just metadata for real files)
		if ([[subPath lastPathComponent] hasPrefix: @"."]) continue;
		
		NSString *fullPath = [path stringByAppendingPathComponent: subPath];
		if ([workspace file: fullPath matchesTypes: executableTypes]) [executables addObject: fullPath];
	}
	
	return executables;
}


+ (NSString *) preferredInstallerFromPaths: (NSArray *)paths
{
	//Run through each filename pattern in order of priority, returning the first matching path
	for (NSString *pattern in [self preferredInstallerPatterns])
	{
		for (NSString *path in paths)
		{
			if ([[[path lastPathComponent] lowercaseString] isMatchedByRegex: pattern]) return path;
		}
	}
	return nil;
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


+ (NSImage *) boxArtForGameAtPath: (NSString *)path
{
	//At the moment this is a very simple check for the existence of a Games For Windows
	//icon, included with GOG games
	NSString *iconPath = [path stringByAppendingPathComponent: @"gfw_high.ico"];
	if ([[NSFileManager defaultManager] fileExistsAtPath: iconPath])
	{
		NSImage *icon = [[NSImage alloc] initByReferencingFile: iconPath];
		return [icon autorelease];
	}
	return nil;
}

+ (NSString *) nameForGameAtPath: (NSString *)path
{
	NSString *filename = [path lastPathComponent];
	
	//Put a space before a set of numbers preceded by a character:
	//ULTIMA8 -> ULTIMA 8
	filename = [filename stringByReplacingOccurrencesOfRegex: @"([a-zA-Z]+)(\\d+)"
															withString: @"$1 $2"];
	
	//Convert the filename to Title Case
	//ULTIMA 8 -> Ultima 8
	filename = [filename capitalizedString];
	
	return filename;
}
@end