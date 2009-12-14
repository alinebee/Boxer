/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXIconFamily extends IconFamily to add some helpful constructors and icon introspection methods.

#import <Cocoa/Cocoa.h>
#import "IconFamily.h"

@interface IconFamily (BXIconFamily)

//Returns a nonretained IconFamily built out of the NSBitmapImageRep representations in the specified NSImage.
//This differs from iconFamilyWithThumbnailsFromImage: in that it does not perform any resampling, instead using
//only what it finds in the NSImage (making it the complement of IconFamily's imageWithAllReps.)
+ (IconFamily *) iconFamilyWithRepresentationsFromImage: (NSImage *)image;

//Returns whether the file at the specified path has its own custom icon resource.
+ (BOOL) fileHasCustomIcon: (NSString *)path;
@end