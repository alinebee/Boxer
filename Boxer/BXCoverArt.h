/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXCoverArt is a holding class for a set of class methods to convert images into game cover art.
//This class has no instance methods and is not meant to be instantiated.

#import <Cocoa/Cocoa.h>

@interface BXCoverArt : NSObject

//Returns the drop shadow effect to be applied to icons of the specified size.
//This shadow ensures the icon stands out on light backgrounds, such as a Finder folder window.
+ (NSShadow *) dropShadowForSize: (NSSize) iconSize;

//Returns the inner glow effect to be applied to icons of the specified size.
//This inner glow ensures the icon stands out on dark backgrounds, such as Finder's Coverflow.
+ (NSShadow *) innerGlowForSize: (NSSize) iconSize;

//Returns a shine overlay image to be applied to icons of the specified size.
//This overlay gives the image a stylized glossy appearance.
+ (NSImage *) shineForSize: (NSSize) iconSize;

//Returns a cover art image representation rendered from the specified image at the specified size.
+ (NSImageRep *) representationFromImage: (NSImage *)originalImage forSize: (NSSize) iconSize;

//Returns a cover art image rendered from the specified image to 512, 256, 128 and 32x32 sizes,
//suitable for use as an OSX icon resource.
+ (NSImage *) coverArtFromImage: (NSImage *)image;

@end
