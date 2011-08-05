/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXImageAwareFileScan.h"
#import "NSWorkspace+BXMountedVolumes.h"
#import "NSWorkspace+BXFileTypes.h"
#import "BXAppController.h"


@implementation BXImageAwareFileScan
@synthesize mountedPath;

- (void) dealloc
{
    [self setMountedPath: nil], [mountedPath release];
    
    [super dealloc];
}

//If we have a mounted volume path for an image, enumerate that instead of the original base path
- (id <BXFilesystemEnumeration>) enumerator
{
    if ([self mountedPath])
        return (id <BXFilesystemEnumeration>)[manager enumeratorAtPath: [self mountedPath]];
    else return [super enumerator];
}

- (void) main
{
    NSString *volumePath = nil;
    BOOL didMountVolume = NO;
    
    //If the target path is on a disk image, then mount the image for scanning
    if ([workspace file: [self basePath] matchesTypes: [NSSet setWithObject: @"public.disk-image"]])
    {
        //First, check if the image is already mounted
        volumePath = [workspace volumeForSourceImage: basePath];
        
        //If it's not mounted yet, mount it ourselves
        if (!volumePath)
        {
            NSError *mountError = nil;
            volumePath = [workspace mountImageAtPath: [self basePath]
                                            readOnly: YES
                                           invisibly: YES
                                               error: &mountError];
            
            //If we couldn't mount the image, give up in failure
            if (!volumePath)
            {
                [self setError: mountError];
                [self setSucceeded: NO];
                return;
            }
            else didMountVolume = YES;
        }
        
        [self setMountedPath: volumePath];
    }
    
    //Perform the rest of the scan as usual
    [super main];
    
    //If we mounted a volume ourselves in order to scan it, unmount it once we're done
    if (didMountVolume)
    {
        [workspace unmountAndEjectDeviceAtPath: [self mountedPath]];
    }
}

@end
