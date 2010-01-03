/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXBootlegCoverArt classes behave like BXCoverArt but create generic cover art based on a title
//rather than a box image. These are designed to look like bootleg floppy disks, CD-ROMs etc.

#import <Cocoa/Cocoa.h>

@protocol BXBootlegCoverArt

+ (NSImageRep *) representationWithTitle: (NSString *)title forSize: (NSSize)iconSize;
+ (NSImage *) coverArtWithTitle: (NSString *)title;

@end

@interface BXJewelCase : NSObject <BXBootlegCoverArt>

+ (NSString *) fontName;
+ (NSColor *) textColor;
+ (NSDictionary *) textAttributesForSize: (NSSize)size;

+ (CGFloat) lineHeightForSize:	(NSSize)size;
+ (CGFloat) fontSizeForSize:	(NSSize)size;

+ (NSImage *) baseLayerForSize:	(NSSize)size;
+ (NSImage *) topLayerForSize:	(NSSize)size;
+ (NSRect) textRegionForSize:	(NSSize)size;

@end

@interface BXDiskette : BXJewelCase
@end