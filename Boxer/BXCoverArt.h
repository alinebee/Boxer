/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Cocoa/Cocoa.h>

/// \c BXCoverArt renders a boxed cover-art appearance from an original source image. It can return
/// an \c NSImage resource suitable for use as a file thumbnail, or draw the art directly into the
/// current graphics context.
@interface BXCoverArt : NSObject

/// The original image we will render into cover art
@property (strong, nonatomic) NSImage *sourceImage;


#pragma mark -
#pragma mark Art assets

/// Returns the drop shadow effect to be applied to icons of the specified size.
///
/// This shadow ensures the icon stands out on light backgrounds, such as a Finder folder window.
+ (NSShadow *) dropShadowForSize: (NSSize) iconSize;

/// Returns the inner glow effect to be applied to icons of the specified size.
/// This inner glow ensures the icon stands out on dark backgrounds, such as Finder's Coverflow.
+ (NSShadow *) innerGlowForSize: (NSSize) iconSize;

/// Returns a shine overlay image to be applied to icons of the specified size.
/// This overlay gives the image a stylized glossy appearance.
+ (NSImage *) shineForSize: (NSSize) iconSize;


#pragma mark -
#pragma mark Rendering methods

/// Draws the source image as cover art into the specified frame in the current graphics context.
- (void) drawInRect: (NSRect)frame;

/// Returns a cover art image representation from the source image rendered at the specified size.
- (NSImageRep *) representationForSize: (NSSize)iconSize;

/// Default initializer: returns a BXCoverArt object initialized with the specified original image.
- (instancetype) initWithSourceImage: (NSImage *)image;

/// Returns a cover art image rendered from the source image to 512, 256, 128 and 32x32 sizes,
//suitable for use as an OS X icon.
- (NSImage *) coverArt;

/// Returns a cover art image rendered from the specified image to 512, 256, 128 and 32x32 sizes,
/// suitable for use as an OS X icon.
/// Note that this returns an NSImage directly, not a BXCoverArt instance.
+ (NSImage *) coverArtWithImage: (NSImage *)image;

/// Returns whether the specified image appears to contain actual transparent/translucent pixels.
/// This is distinct from whether it has an alpha channel, as the alpha channel may go unused
/// (e.g. in an opaque image saved as 32-bit PNG.)
+ (BOOL) imageHasTransparency: (NSImage *)image;
@end
