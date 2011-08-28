/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <AppKit/AppKit.h>

@interface NSImage (BXImageEffects)

//Returns an image filled with the specified color at the specified size,
//using the current image as a mask. The resulting image will be a bitmap.
//Pass NSZeroSize as the size to use the size of the original image.
//Intended for use with black-and-transparent template images,
//although it will work with any image.
- (NSImage *) maskedImageWithColor: (NSColor *)color atSize: (NSSize)targetSize;

//A partial implementation of 10.6's drawInRect:fromRect:operation:fraction:respectFlipped:hints
//for 10.5. This does not support rendering hints but will correctly respect the graphics
//context's flipped status.
- (void) drawInRect: (NSRect)dstSpacePortionRect
           fromRect: (NSRect)srcSpacePortionRect
          operation: (NSCompositingOperation)op 
           fraction: (CGFloat)requestedAlpha
     respectFlipped: (BOOL)respectContextIsFlipped;

@end
