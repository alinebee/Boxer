/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "NSImage+BXImageEffects.h"
#import "BXGeometry.h"
#import "BXAppKitVersionHelpers.h"

@implementation NSImage (BXImageEffects)

+ (NSPoint) anchorForImageAlignment: (NSImageAlignment)alignment
{
    switch (alignment)
    {
        case NSImageAlignCenter:
            return NSMakePoint(0.5f, 0.5f);
            
        case NSImageAlignBottom:
            return NSMakePoint(0.5f, 0.0f);
            
        case NSImageAlignTop:
            return NSMakePoint(0.5f, 1.0f);
            
        case NSImageAlignLeft:
            return NSMakePoint(0.0f, 0.5f);
            
        case NSImageAlignRight:
            return NSMakePoint(1.0f, 0.5f);
            
        case NSImageAlignBottomLeft:
            return NSMakePoint(0.0f, 0.0f);
            
        case NSImageAlignBottomRight:
            return NSMakePoint(1.0f, 0.0f);
            
        case NSImageAlignTopLeft:
            return NSMakePoint(0.0f, 1.0f);
            
        case NSImageAlignTopRight:
            return NSMakePoint(1.0f, 1.0f);
            
        default:
            return NSZeroPoint;
    }
}

- (NSRect) imageRectAlignedInRect: (NSRect)outerRect
                       alignment: (NSImageAlignment)alignment
                         scaling: (NSImageScaling)scaling
{
    NSRect drawRect = NSZeroRect;
    drawRect.size = self.size;
    NSPoint anchor = [[self class] anchorForImageAlignment: alignment];
    
    switch (scaling)
    {
        case NSImageScaleProportionallyDown:
            drawRect = constrainToRect(drawRect, outerRect, anchor);
            break;
        case NSImageScaleProportionallyUpOrDown:
            drawRect = fitInRect(drawRect, outerRect, anchor);
            break;
        case NSImageScaleAxesIndependently:
            drawRect = outerRect;
            break;
        case NSImageScaleNone:
        default:
            drawRect = alignInRectWithAnchor(drawRect, outerRect, anchor);
            break;
    }
    return drawRect;
}

- (NSImage *) imageFilledWithColor: (NSColor *)color atSize: (NSSize)targetSize
{
    if (NSEqualSizes(targetSize, NSZeroSize)) targetSize = [self size];
    
    NSRect imageRect = NSMakeRect(0, 0, targetSize.width, targetSize.height);
    
	NSImage *maskedImage = [[NSImage alloc] initWithSize: targetSize];
    NSImage *sourceImage = self;
	
	//NOTE: drawInRect:fromRect:operation:fraction: misbehaves on 10.5 in that
	//it caches what it draws and may use that for future draw operations
	//instead of other, more suitable representations of that image.
	//To work around this, we draw a copy of the image instead of the original.
	//Fuck 10.5.
	if (isRunningOnLeopard())
		sourceImage = [[sourceImage copy] autorelease];
	
    [maskedImage lockFocus];
        [color set];
        NSRectFillUsingOperation(imageRect, NSCompositeSourceOver);
        [sourceImage drawInRect: imageRect
					   fromRect: NSZeroRect
					  operation: NSCompositeDestinationIn 
					   fraction: 1.0f];
    [maskedImage unlockFocus];
    
	if (isRunningOnLeopard())
		[self recache];
	
    return [maskedImage autorelease];
}

- (NSImage *) imageMaskedByImage: (NSImage *)image atSize: (NSSize)targetSize
{
    if (NSEqualSizes(targetSize, NSZeroSize)) targetSize = [self size];
    
    NSImage *maskedImage = [self copy];
    [maskedImage setSize: targetSize];
    
    NSRect imageRect = NSMakeRect(0.0f, 0.0f, targetSize.width, targetSize.height);
    
	//NOTE: drawInRect:fromRect:operation:fraction: misbehaves on 10.5 in that
	//it caches the what it draws and may use that for future draw operations
	//instead of other, more suitable representations of that image.
	//To work around this, we draw a copy of the image instead of the original.
	//Fuck 10.5.
	if (isRunningOnLeopard())
		image = [[image copy] autorelease];
	
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

- (void) drawInRect: (NSRect)drawRect
       withGradient: (NSGradient *)gradient
         dropShadow: (NSShadow *)dropShadow
        innerShadow: (NSShadow *)innerShadow
{
    NSAssert(self.isTemplate, @"drawInRect:withGradient:dropShadow:innerShadow: can only be used with template images.");
    
    NSSize size = drawRect.size;
    
    NSGraphicsContext *context = [NSGraphicsContext currentContext];
    CGContextRef cgContext = (CGContextRef)context.graphicsPort;
    
    //First create a mask image
    CGRect maskRect = NSRectToCGRect(drawRect);
    CGImageRef imageMask = [self CGImageForProposedRect: &drawRect context: context hints: nil];
    
    //Create an inverted version of the mask
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef maskContext = CGBitmapContextCreate(NULL, size.width, size.height, 8, size.width * 4, colorSpace, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    CGContextSetBlendMode(maskContext, kCGBlendModeXOR);
    CGContextDrawImage(maskContext, CGRectMake(0, 0, size.width, size.height), imageMask);
    CGContextSetRGBFillColor(maskContext, 1.0, 1.0, 1.0, 1.0);
    CGContextFillRect(maskContext, CGRectMake(0, 0, size.width, size.height));
    CGImageRef invertedImageMask = CGBitmapContextCreateImage(maskContext);
    
    //Fill image area with gradient
    if (gradient)
    {
        [NSGraphicsContext saveGraphicsState];
        CGContextSaveGState(cgContext);
            CGContextClipToMask(cgContext, maskRect, imageMask);
            [gradient drawInRect: drawRect angle: 270.0];
        CGContextRestoreGState(cgContext);
        [NSGraphicsContext restoreGraphicsState];
    }
    
    //Render the drop shadow
    if (dropShadow)
    {
        [NSGraphicsContext saveGraphicsState];
        CGContextSaveGState(cgContext);
            [dropShadow set];
            CGContextClipToMask(cgContext, maskRect, invertedImageMask);
            CGContextDrawImage(cgContext, maskRect, imageMask);
        CGContextRestoreGState(cgContext);
        [NSGraphicsContext restoreGraphicsState];
    }
    
    //Render the inner shadow
    if (innerShadow)
    {
        [NSGraphicsContext saveGraphicsState];
        CGContextSaveGState(cgContext);
            [innerShadow set];
            CGContextClipToMask(cgContext, maskRect, imageMask);
            CGContextDrawImage(cgContext, maskRect, invertedImageMask);
        CGContextRestoreGState(cgContext);
        [NSGraphicsContext restoreGraphicsState];
    }
    
    CGContextRelease(maskContext);
    CGImageRelease(invertedImageMask);
}

@end
