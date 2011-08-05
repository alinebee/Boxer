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


@implementation BXInstallerScan
@synthesize windowsExecutables, DOSExecutables, isAlreadyInstalled;

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
        
        NSString *absolutePath = [[self basePath] stringByAppendingPathComponent: relativePath];
        NSSet *executableTypes = [BXAppController executableTypes];
        
        if ([workspace file: absolutePath matchesTypes: executableTypes])
        {
            if ([workspace isCompatibleExecutableAtPath: absolutePath])
            {
                [self addDOSExecutable: relativePath];
                
                //If this looks like an installer to us, finally add it into our list of matches
                if ([BXImportSession isInstallerAtPath: relativePath])
                {
                    [self addMatchingPath: relativePath];
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

@end
