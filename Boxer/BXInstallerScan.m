/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXInstallerScan.h"
#import "BXImportSession+BXImportPolicies.h"

#import "NSWorkspace+BXFileTypes.h"
#import "NSWorkspace+BXExecutableTypes.h"
#import "BXAppController.h"
#import "BXSessionError.h"


@implementation BXInstallerScan
@synthesize windowsExecutables, DOSExecutables, isAlreadyInstalled, detectedProfile;

- (id) init
{
    if ((self = [super init]))
    {
        windowsExecutables  = [[NSMutableArray alloc] initWithCapacity: 10];
        DOSExecutables      = [[NSMutableArray alloc] initWithCapacity: 10];
    }
    return self;
}

- (void) dealloc
{
    [windowsExecutables release], windowsExecutables = nil;
    [DOSExecutables release], DOSExecutables = nil;
    [self setDetectedProfile: nil], [detectedProfile release];
    
    [super dealloc];
}

//Overridden to gather additional data besides just matching installers.
- (BOOL) matchAgainstPath: (NSString *)relativePath
{
    //Filter out files that don't match BXFileScan’s basic tests
    //(Basically this just filters out hidden files.)
    if ([self isMatchingPath: relativePath])
    {
        if ([BXImportSession isIgnoredFileAtPath: relativePath]) return YES;
        
        //Check for telltales that indicate an already-installed game, but keep scanning even if we find one.
        if (!isAlreadyInstalled && [BXImportSession isPlayableGameTelltaleAtPath: relativePath])
        {
            isAlreadyInstalled = YES;
        }
        
        NSString *fullPath = [self fullPathFromRelativePath: relativePath];
        NSSet *executableTypes = [BXAppController executableTypes];
        
        if ([workspace file: fullPath matchesTypes: executableTypes])
        {
            if ([workspace isCompatibleExecutableAtPath: fullPath error: NULL])
            {
                [self addDOSExecutable: relativePath];
                
                //If this looks like an installer to us, finally add it into our list of matches
                if ([BXImportSession isInstallerAtPath: relativePath] && ![[self detectedProfile] isIgnoredInstallerAtPath: relativePath])
                {
                    [self addMatchingPath: relativePath];
                    
                    NSDictionary *userInfo = [NSDictionary dictionaryWithObject: [self lastMatch]
                                                                         forKey: BXFileScanLastMatchKey];
                    
                    [self _sendInProgressNotificationWithInfo: userInfo];
                }
            }
            //Skip windows executables, but keep a record of the ones we do find
            else
            {
                [self addWindowsExecutable: relativePath];
            }
        }
    }
    
    return YES;
}

- (void) addWindowsExecutable: (NSString *)relativePath
{
    [[self mutableArrayValueForKey: @"windowsExecutables"] addObject: relativePath];
}

- (void) addDOSExecutable: (NSString *)relativePath
{
    [[self mutableArrayValueForKey: @"DOSExecutables"] addObject: relativePath];
}

//Overridden to scan the folder structure to determine a game profile before
//we start scanning for actual installers.
//Implementation note: 
- (void) willPerformOperation
{
    //Allow the superclass to mount any volume we need for scanning
    [super willPerformOperation];
    
    if (![self detectedProfile])
    {
        //If we are scanning a mounted image, scan the mounted volume path for the game profile
        //instead of the base image path. 
        NSString *profileScanPath = ([self mountedVolumePath]) ? [self mountedVolumePath] : [self basePath];
        
        //IMPLEMENTATION NOTE: detectedProfileForPath:searchSubfolders: trawls the same
        //directory structure as our own installer scan, so it would be more efficient
        //to do profile detection in the same loop as installer detection.
        //However, profile detection relies on iterating the same file structure multiple
        //times in order to scan for different profile 'priorities' so this isn't an option.
        //Also, it appears OS X's directory enumerator caches the result of a directory
        //scan so that subsequent reiterations do not do disk I/O.
        BXGameProfile *profile = [BXGameProfile detectedProfileForPath: profileScanPath
                                                  searchSubfolders: YES];
    
        [self setDetectedProfile: profile];
    }
}

- (void) didPerformOperation
{
    if (![self error])
    {
        //Determine a preferred installer from among those discovered in the scan.
        if ([[self DOSExecutables] count])
        {
            NSString *preferredInstallerPath = nil;
            
            if ([self detectedProfile])
            {
                //Check through all the DOS executables in order of path depth, to see
                //if any of them match the game profile's idea of a preferred installer:
                //if so, we'll add it to the list of installers (if it's not already there)
                //and use it as the preferred one.
                for (NSString *relativePath in [DOSExecutables sortedArrayUsingSelector: @selector(pathDepthCompare:)])
                {
                    if ([[self detectedProfile] isDesignatedInstallerAtPath: relativePath])
                    {
                        preferredInstallerPath = relativePath;
                        break;
                    }
                }
            }
            
            [self willChangeValueForKey: @"matchingPaths"];
            
            //Sort the installers we found by depth, to prioritise the ones in the root directory.
            [matchingPaths sortUsingSelector: @selector(pathDepthCompare:)];
            
            //If the game profile didn't suggest a preferred installer,
            //then pick one from the set of discovered installers
            if (!preferredInstallerPath)
            {
                preferredInstallerPath = [BXImportSession preferredInstallerFromPaths: matchingPaths];
            }
            
            //Bump the preferred installer up to the first entry in the list of installers.
            if (preferredInstallerPath)
            {
                [matchingPaths removeObject: preferredInstallerPath];
                [matchingPaths insertObject: preferredInstallerPath atIndex: 0];
            }
            
            [self didChangeValueForKey: @"matchingPaths"];
        }
        
        //If we didn't find any executables and couldn't identify this as a known game,
        //then this isn't a game we can import and we should treat it as a failure.
        
        //IMPLEMENTATION NOTE: if we didn't find any DOS executables, but *did*
        //identify a profile for the game, then we give it the benefit of the doubt.
        //This case usually means that the game is preinstalled and the game
        //files are buried away on a disc image inside the source folder.
        //(e.g. GOG releases of Wing Commander 3 and Ultima Underworld 1 & 2)
        
        else if (!([self isAlreadyInstalled] && [self detectedProfile]))
        {   
            //If there were windows executables present, this is probably a Windows-only game.
            if ([[self windowsExecutables] count] > 0)
            {
                [self setError: [BXImportWindowsOnlyError errorWithSourcePath: [self basePath]
                                                                     userInfo: nil]];
            }    
            //Otherwise, the folder may be empty or contains something other than a DOS game.
            //TODO: additional logic to detect Classic Mac games.
            else
            {
                [self setError: [BXImportNoExecutablesError errorWithSourcePath: [self basePath]
                                                                       userInfo: nil]];
            }
        }
    }
    
    //Let our superclass unmount any volumes that were mounted in the course of the scan,
    //now that we no longer need access to the filesystem.
    [super didPerformOperation];
}

@end
