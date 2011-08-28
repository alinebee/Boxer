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
@synthesize mountedVolumePath, ejectAfterScanning, didMountVolume;

- (id) init
{
    if ((self = [super init]))
    {
        [self setEjectAfterScanning: BXFileScanAutoEject];
    }
    return self;
}

- (void) dealloc
{
    [self setMountedVolumePath: nil], [mountedVolumePath release];
    
    [super dealloc];
}

- (NSString *) fullPathFromRelativePath: (NSString *)relativePath
{
    //Return paths relative to the mounted volume instead, if available.
    NSString *filesystemRoot = ([self mountedVolumePath]) ? [self mountedVolumePath] : [self basePath];
    return [filesystemRoot stringByAppendingPathComponent: relativePath];
}

//If we have a mounted volume path for an image, enumerate that instead of the original base path
- (id <BXFilesystemEnumeration>) enumerator
{
    if ([self mountedVolumePath])
        return (id <BXFilesystemEnumeration>)[manager enumeratorAtPath: [self mountedVolumePath]];
    else return [super enumerator];
}

- (void) willPerformOperation
{
    NSString *volumePath = nil;
    didMountVolume = NO;
    
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
                return;
            }
            else didMountVolume = YES;
        }
        
        [self setMountedVolumePath: volumePath];
    }    
}

- (void) didPerformOperation
{
    //If we mounted a volume ourselves in order to scan it,
    //or we've been told to always eject, then unmount the volume
    //once we're done
    if ([self mountedVolumePath])
    {
        if (([self ejectAfterScanning] == BXFileScanAlwaysEject) ||
            (didMountVolume && [self ejectAfterScanning] == BXFileScanAutoEject))
        {
            [workspace unmountAndEjectDeviceAtPath: [self mountedVolumePath]];
            [self setMountedVolumePath: nil];
        }
    }    
}

@end
