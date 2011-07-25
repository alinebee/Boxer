/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXExecutableScan.h"
#import "NSWorkspace+BXExecutableTypes.h"
#import "NSWorkspace+BXMountedVolumes.h"
#import "BXAppController.h"

@interface BXExecutableScan ()

//The original path of the source disk image, only set when scanning a disk image
@property (copy, nonatomic) NSString *imagePath;

@end


@implementation BXExecutableScan
@synthesize imagePath;

- (void) dealloc
{
    [self setImagePath: nil], [imagePath release];
    
    [super dealloc];
}

- (BOOL) isMatchingPath: (NSString *)relativePath
{
    if ([super isMatchingPath: relativePath])
    {
        NSString *fullPath = [[self basePath] stringByAppendingPathComponent: relativePath];
        return [workspace isCompatibleExecutableAtPath: fullPath];
    }
    else
    {
        return NO;
    }
}

- (BOOL) shouldScanSubpath: (NSString *)relativePath
{
    if ([super shouldScanSubpath: relativePath])
    {
        NSString *fullPath = [[self basePath] stringByAppendingPathComponent: relativePath];
        
        //Filter out the contents of any nested drive folders
        return ![workspace file: fullPath matchesTypes: [BXAppController mountableFolderTypes]];
    }
    else return NO;
}

- (void) addMatchingPath: (NSString *)relativePath
{
    //Store the match relative to the original image path,
    //rather than to the mounted volume we're scanning
    NSString *fullPath;
    if ([self imagePath]) fullPath = [[self imagePath] stringByAppendingPathComponent: relativePath];
    else fullPath = [[self basePath] stringByAppendingPathComponent: relativePath];
    
    //Ensures KVO notifications are sent properly
	[[self mutableArrayValueForKey: @"matchingPaths"] addObject: fullPath];
}

- (void) main
{
    NSString *mountedPath = nil;
    BOOL didMountVolume = NO;
    
    //If the target path is on a disk image, then mount the image for scanning
    if ([workspace file: [self basePath] matchesTypes: [BXAppController OSXMountableImageTypes]])
    {
        [self setImagePath: [self basePath]];
        
        //First, check if the image is already mounted
        mountedPath = [workspace volumeForSourceImage: basePath];
        
        //If it's not, mount it ourselves
        if (!mountedPath)
        {
            NSError *mountError = nil;
            mountedPath = [workspace mountImageAtPath: basePath readOnly: YES invisibly: YES error: &mountError];
            
            //If we couldn't mount the image, give up in failure
            if (!mountedPath)
            {
                [self setError: mountError];
                [self setSucceeded: NO];
                return;
            }
            else didMountVolume = YES;
        }
        
        //Enumerate the mounted volume instead of the image.
        [self setBasePath: mountedPath];
    }

    //Perform the rest of the scan as usual
    [super main];
    

    //If we mounted the volume ourselves in order to scan it, unmount it once we're done
    if (didMountVolume)
    {
        [workspace unmountAndEjectDeviceAtPath: [self basePath]];
    }
}

@end
