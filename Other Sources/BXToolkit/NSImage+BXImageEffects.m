/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "NSImage+BXImageEffects.h"

@implementation NSImage (BXImageEffects)

- (NSImage *) imageFilledWithColor: (NSColor *)color atSize: (NSSize)targetSize
{
    if (NSEqualSizes(targetSize, NSZeroSize)) targetSize = [self size];
    
    NSImage *maskedImage = [[NSImage alloc] init];
    [maskedImage setSize: targetSize];
    
    NSRect imageRect = NSMakeRect(0.0f, 0.0f, targetSize.width, targetSize.height);
    
    [maskedImage lockFocus];
        [color set];
        NSRectFillUsingOperation(imageRect, NSCompositeSourceOver);
        [self drawInRect: imageRect
                fromRect: NSZeroRect
               operation: NSCompositeDestinationIn 
                fraction: 1.0f];
    [maskedImage unlockFocus];
    
    return [maskedImage autorelease];
}

- (NSImage *) imageMaskedByImage: (NSImage *)image atSize: (NSSize)targetSize
{
    if (NSEqualSizes(targetSize, NSZeroSize)) targetSize = [self size];
    
    NSImage *maskedImage = [self copy];
    [maskedImage setSize: targetSize];
    
    NSRect imageRect = NSMakeRect(0.0f, 0.0f, targetSize.width, targetSize.height);
    
    [maskedImage lockFocus];
        [image drawInRect: imageRect
                 fromRect: NSZeroRect
                operation: NSCompositeDestinationIn 
                 fraction: 1.0f];
    [maskedImage unlockFocus];
    
    return [maskedImage autorelease];
}


- (void) drawInRect: (NSRect)dstSpacePortionRect
           fromRect: (NSRect)srcSpacePortionRect
          operation: (NSCompositingOperation)op 
           fraction: (CGFloat)requestedAlpha
     respectFlipped: (BOOL)respectContextIsFlipped
{
    //Use 10.6's method if it's available
    if ([self respondsToSelector: @selector(drawInRect:fromRect:operation:fraction:respectFlipped:hints:)])
    {
        [self drawInRect: dstSpacePortionRect
                fromRect: srcSpacePortionRect
               operation: op
                fraction: requestedAlpha
          respectFlipped: respectContextIsFlipped
                   hints: nil];
    }
    else
    {
        NSGraphicsContext *context = [NSGraphicsContext currentContext];
    
        //Otherwise, if we need to adjust for the context being flipped,
        //then perform a coordinate transform ourselves.
        if (respectContextIsFlipped && [context isFlipped])
        {
            //This code was adapted from NSImage+FlippedDrawing by Paul Kim:
            //http://www.noodlesoft.com/blog/2009/02/02/understanding-flipped-coordinate-systems/
            //Full copyright statement can be found in Boxer's acknowledgements.
            
            [context saveGraphicsState];
                NSAffineTransform *transform = [NSAffineTransform transform];
                [transform translateXBy: 0.0f
                                    yBy: NSMaxY(dstSpacePortionRect)];
                [transform scaleXBy: 1.0f
                                yBy: -1.0f];
                [transform concat];
                
                // The transform above places the y-origin right where the image should be drawn.
                dstSpacePortionRect.origin.y = 0.0f;
                
                [self drawInRect: dstSpacePortionRect
                        fromRect: srcSpacePortionRect
                       operation: op
                        fraction: requestedAlpha];
            [context restoreGraphicsState];
        }
        //Otherwise, just draw ourselves normally
        else
        {
            [self drawInRect: dstSpacePortionRect
                    fromRect: srcSpacePortionRect
                   operation: op
                    fraction: requestedAlpha];
        }   
    }
}
@end
