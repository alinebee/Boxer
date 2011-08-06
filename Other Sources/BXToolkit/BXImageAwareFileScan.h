/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXImageAwareFileScan is a BXFileScan subclass that can also scan the
//contents of any disk image supported by OS X's hdiutil. File matches
//will be returned as a relative path appended to the original image path.

#import "BXFileScan.h"


enum {
    BXFileScanAutoEject = -1,
    BXFileScanNeverEject = 0,
    BXFileScanAlwaysEject = 1
};
typedef NSInteger BXFileScanEjectionBehaviour;

    
@interface BXImageAwareFileScan : BXFileScan
{
    NSString *mountedVolumePath;
    BXFileScanEjectionBehaviour ejectAfterScanning;
    BOOL didMountVolume;
}

//The volume path at which the original source disk image is mounted.
//Only valid while scanning a disk image.
@property (copy, nonatomic) NSString *mountedVolumePath;

//Whether to automatically unmount any mounted path after the scan is complete.
//By default. this will only unmount if the scan itself was responsible for mounting
//the path.
@property (assign, nonatomic) BXFileScanEjectionBehaviour ejectAfterScanning;

@end
