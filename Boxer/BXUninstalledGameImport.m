/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXUninstalledGameImport.h"
#import "BXAppController.h"
#import "NSWorkspace+BXMountedVolumes.h"
#import "NSWorkspace+BXFileTypes.h"

//Source paths whose filesize is larger than this in bytes will be treated as CD-sized
//for the purposes of shouldImportSourceFilesFromPath:
#define BXCDROMSizeThreshold 100 * 1024 * 1024


@implementation BXUninstalledGameImport
@synthesize installerPath, detectedInstallers, importSourceFiles;

- (void) dealloc
{
	[detectedInstallers release], detectedInstallers = nil;
	[self setInstallerPath: nil], [installerPath release];
	
	[super dealloc];
}


#pragma mark -
#pragma mark Helper class methods

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
							   @"^dosinst\.",
							   @"^install\.",
							   @"^hdinstal\.",
							   @"setup\.",
							   @"inst",
							   nil];
	return patterns;
}

+ (BOOL) shouldImportSourceFilesFromPath: (NSString *)path
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	
	//If the source path is a mountable image, it should be imported
	if ([workspace file: path matchesTypes: [BXAppController mountableImageTypes]]) return YES;
	
	//If the source path is a CD, it should be imported
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