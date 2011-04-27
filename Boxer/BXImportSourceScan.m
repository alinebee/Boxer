/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXImportSourceScan.h"
#import "BXPathEnumerator.h"
#import "BXImportSession+BXImportPolicies.h"
#import "BXAppController.h"
#import "NSWorkspace+BXFileTypes.h"
#import "NSWorkspace+BXExecutableTypes.h"


@implementation BXImportSourceScan
@synthesize sourcePath;
@synthesize executables, windowsExecutables, installers;
@synthesize preInstalledGame;

- (id) init
{
	if ((self = [super init]))
	{
		executables			= [[NSMutableArray alloc] initWithCapacity: 10];
		windowsExecutables	= [[NSMutableArray alloc] initWithCapacity: 10];
		installers			= [[NSMutableArray alloc] initWithCapacity: 10];
		
		manager = [[NSFileManager alloc] init];
		workspace = [[NSWorkspace alloc] init];
	}
}

- (id) initWithSourcePath: (NSString *)source
{
	if ((self = [self init]))
	{
		[self setSourcePath: source];
	}
	return self;
}

- (void) dealloc
{
	[self setSourcePath: nil], [sourcePath release];
	
	[executables release], executables = nil;
	[windowsExecutables release], windowsExecutables = nil;
	[installers release], installers = nil;
	
	[manager release], manager = nil;
	[workspace release], workspace = nil;
	
	[super dealloc];
}

- (void) main
{
	if ([self isCancelled] || !sourcePath) return;
	
	NSSet *executableTypes = [BXAppController executableTypes];
	
	//Clear any state variables from a previous execution before we begin.
	//A moot point since NSOperations aren't meant to be relaunched, but still.
	preInstalledGame = NO;
	[executables removeAllObjects];
	[windowsExecutables removeAllObjects];
	[installers removeAllObjects];
	
	BXPathEnumerator *enumerator = [BXPathEnumerator enumeratorAtPath: sourcePath];
	
	for (NSString *path in enumerator)
	{
		BOOL isWindowsExecutable = NO;
		
		//Grab the relative path to use for heuristic filename-pattern checks,
		//so that the base path doesn't get involved in the heuristic.
		NSString *relativePath = [enumerator relativePath];
	
		//Skip the file altogether if we know it's irrelevant (see [BXImportPolicies +ignoredFilePatterns])
		if ([BXImportSession isIgnoredFileAtPath: relativePath]) continue;
		
		//If we find an indication that this is an already-installed game, then we won't bother recording any installers.
		//However, we'll still keep looking for executables: but only so that we can make sure the user really is
		//importing a proper DOS game and not a Windows-only game.
		if ([BXImportSession isPlayableGameTelltaleAtPath: relativePath])
		{
			[installers removeAllObjects];
			preferredInstaller = nil;
			preInstalledGame = YES;
		}
		
		if ([workspace file: path matchesTypes: executableTypes])
		{
			[executables addObject: path];
			
			//Exclude windows-only programs, but note how many we've found
			if (![workspace isCompatibleExecutableAtPath: path])
			{
				isWindowsExecutable = YES;
				[windowsExecutables addObject: path];
			}
			
			//As described above, only bother recording installers if the game isn't already installed
			//Also ignore non-DOS executables, even if they look like installers
			if (!isWindowsExecutable && !preInstalledGame)
			{
				//If this was the designated installer for this game profile, add it to the installer list
				if (!preferredInstaller && [detectedProfile isDesignatedInstallerAtPath: relativePath])
				{
					[installers addObject: path];
					preferredInstaller = path;
				}
				
				//Otherwise if it looks like an installer to us, add it to the installer list
				else if ([BXImportSession isInstallerAtPath: relativePath])
				{
					[installers addObject: path];
				}
			}
		}
	}
}

- (BOOL) compatibleWithBoxer
{
	return [executables count] > 0;
}

- (BOOL) isWindowsOnly
{
	NSUInteger numExecutables = [executables count];
	NSUInteger numWindowsExecutables = [windowsExecutables count];
	
	return (numExecutables > 0 && numExecutables == numWindowsExecutables);
}

@end
