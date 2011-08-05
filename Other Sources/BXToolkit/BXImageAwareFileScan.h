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


@interface BXImageAwareFileScan : BXFileScan
{
    NSString *mountedPath;
}

//The path at which the original source disk image is mounted.
//Only valid while scanning a disk image.
@property (copy, nonatomic) NSString *mountedPath;

@end
