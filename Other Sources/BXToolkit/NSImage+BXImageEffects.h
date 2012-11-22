/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <AppKit/AppKit.h>

@interface NSImage (BXImageEffects)

//Returns the relative anchor point (from {0.0, 0.0} to {1.0, 1.0})
//that's equivalent to the specified image alignment constant.
+ (NSPoint) anchorForImageAlignment: (NSImageAlignment)alignment;

//Returns a rect suitable for drawing this image into,
//given the specified alignment and scaling mode. Intended
//for NSCell/NSControl subclasses.
- (NSRect) imageRectAlignedInRect: (NSRect)outerRect
                        alignment: (NSImageAlignment)alignment
                          scaling: (NSImageScaling)scaling;

//Returns a new version of the image filled with the specified color at the
//specified size, using the current image's alpha channel. The resulting image
//will be a bitmap.
//Pass NSZeroSize as the size to use the size of the original image.
//Intended for use with black-and-transparent template images,
//although it will work with any image.
- (NSImage *) imageFilledWithColor: (NSColor *)color atSize: (NSSize)targetSize;

//Returns a new version of the image masked by the specified image, at the
//specified size. The resulting image will be a bitmap.
- (NSImage *) imageMaskedByImage: (NSImage *)mask atSize: (NSSize)targetSize;


//A partial implementation of 10.6's drawInRect:fromRect:operation:fraction:respectFlipped:hints
//for 10.5. This does not support rendering hints but will correctly respect the graphics
//context's flipped status.
- (void) drawInRect: (NSRect)dstSpacePortionRect
           fromRect: (NSRect)srcSpacePortionRect
          operation: (NSCompositingOperation)op 
           fraction: (CGFloat)requestedAlpha
     respectFlipped: (BOOL)respectContextIsFlipped;

//Draw a template image filled with the specified gradient and rendered
//with the specified inner and drop shadows.
- (void) drawInRect: (NSRect)drawRect
       withGradient: (NSGradient *)fillGradient
         dropShadow: (NSShadow *)dropShadow
        innerShadow: (NSShadow *)innerShadow
     respectFlipped: (BOOL)respectContextIsFlipped;
@end
