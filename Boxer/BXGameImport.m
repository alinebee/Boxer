/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXGameImport.h"
#import "RegexKitLite.h"
#import "NSWorkspace+BXMountedVolumes.h"
#import "NSWorkspace+BXFileTypes.h"
#import "BXUninstalledGameImport.h"

@interface BXGameImport ()
@property (readwrite, copy, nonatomic) NSString *sourcePath;
@property (readwrite, nonatomic) BXImportStage stage;
@end

@implementation BXGameImport
@synthesize sourcePath, destinationPath, gameProfile, gameIcon, stage;

#pragma mark -
#pragma mark Initialization and deallocation

- (void) dealloc
{
	[self setSourcePath: nil],		[sourcePath release];
	[self setDestinationPath: nil],	[destinationPath release];
	[self setGameProfile: nil],		[gameProfile release];
	[self setGameIcon: nil],		[gameIcon release];
	[super dealloc];
}


#pragma mark -
#pragma mark Helper class methods


+ (BXInstallStatus) installStatusOfGameAtPath: (NSString *)path
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSFileManager *manager = [NSFileManager defaultManager];
	
	path = [path stringByStandardizingPath];
	
	//If the game is on CD or floppy, it's definitely not installed
	if ([workspace volumeTypeForPath: path] == dataCDVolumeType || [workspace isFloppyVolumeAtPath: path])
		return BXInstallStatusNotInstalled;
	
	//Otherwise, we'll need to go through its one by one
	
	NSSet *telltaleTypes = [NSSet setWithObjects:
							@"net.washboardabs.boxer-mountable-folder",
							@"gnu.org.configuration-file",
							@"com.gog.gog-disk-image",
							nil];

	NSArray *installerPatterns = [BXUninstalledGameImport preferredInstallerPatterns];
	
	NSDirectoryEnumerator *enumerator = [manager enumeratorAtPath: path];
	for (NSString *subPath in enumerator)
	{
		NSString *fullPath = [path stringByAppendingPathComponent: subPath];
		
		//If the path contains any telltale filetypes, it's definitely installed
		if ([workspace file: fullPath matchesTypes: telltaleTypes]) return BXInstallStatusInstalled;

		//If we can find any likely-looking installers, then assume it's probably not installed yet
		NSString *filename = [subPath lastPathComponent];
		for (NSString *pattern in installerPatterns)
		{
			if ([filename isMatchedByRegex: pattern]) return BXInstallStatusProbablyNotInstalled;
		}
	}
	//Otherwise, assume the game is probably already installed
	return BXInstallStatusProbablyInstalled;
}
@end