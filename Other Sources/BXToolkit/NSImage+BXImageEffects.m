/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "NSImage+BXImageEffects.h"
#import "BXGeometry.h"
#import "BXAppKitVersionHelpers.h"
#import "NSShadow+BXShadowExtensions.h"

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

- (void) drawInRect: (NSRect)drawRect
       withGradient: (NSGradient *)gradient
         dropShadow: (NSShadow *)dropShadow
        innerShadow: (NSShadow *)innerShadow
     respectFlipped: (BOOL)respectContextIsFlipped
{
    
    //Check if we're rendering into a backing intended for retina displays.
    NSSize pointSize = NSMakeSize(1, 1);
    if ([[NSView focusView] respondsToSelector: @selector(convertSizeToBacking:)])
         pointSize = [[NSView focusView] convertSizeToBacking: pointSize];
    
    NSSize contextSize = [NSView focusView].bounds.size;
    
    NSAssert(self.isTemplate, @"drawInRect:withGradient:dropShadow:innerShadow: can only be used with template images.");
    
    NSGraphicsContext *context = [NSGraphicsContext currentContext];
    CGContextRef cgContext = (CGContextRef)context.graphicsPort;
    
    BOOL drawFlipped = respectContextIsFlipped && context.isFlipped;
    
    //The total area of the context that will be affected by our drawing,
    //including our drop shadow.
    NSRect totalDirtyRect = drawRect;
    if (dropShadow)
        totalDirtyRect = [dropShadow expandedRectForShadow: drawRect flipped: drawFlipped];
    
    //First create a mask image from the alpha channel of this image. We will use this to mask our fill and drop-shadow drawing.
    CGRect maskRect = NSRectToCGRect(drawRect);
    CGImageRef imageMask = [self CGImageForProposedRect: &drawRect context: context hints: nil];
    
    //Next, create an inverted version of the mask. We will use this to mask our drawing of the drop and inner shadows.
    //Note that the inverted mask is larger than the original mask because it needs to cover the total dirty region:
    //otherwise it would inadvertently mask out parts of the drop shadow.
    CGRect invertedMaskRect = CGRectIntegral(NSRectToCGRect(totalDirtyRect));
    //Because CGBitmapContexts are not retina-aware and use device pixels,
    //we have to compensate accordingly when we're rendering for a retina backing.
    CGSize invertedMaskPixelSize = CGSizeMake(invertedMaskRect.size.width * pointSize.width,
                                              invertedMaskRect.size.height * pointSize.height);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef maskContext = CGBitmapContextCreate(NULL,
                                                     invertedMaskPixelSize.width,
                                                     invertedMaskPixelSize.height,
                                                     8,
                                                     invertedMaskPixelSize.width * 4,
                                                     colorSpace,
                                                     kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    
    //Render the inverted mask by drawing the original mask into our temporary context and then XORing the result.
    CGRect relativeMaskRect = CGRectMake((maskRect.origin.x - invertedMaskRect.origin.x) * pointSize.width,
                                         (maskRect.origin.y - invertedMaskRect.origin.y) * pointSize.height,
                                         maskRect.size.width * pointSize.width,
                                         maskRect.size.height * pointSize.height);
    
    CGContextSetBlendMode(maskContext, kCGBlendModeXOR);
    CGContextDrawImage(maskContext, relativeMaskRect, imageMask);
    CGContextSetRGBFillColor(maskContext, 1.0, 1.0, 1.0, 1.0);
    CGContextFillRect(maskContext, CGRectMake(0, 0, invertedMaskPixelSize.width, invertedMaskPixelSize.height));
    CGImageRef invertedImageMask = CGBitmapContextCreateImage(maskContext);
    
    //To draw the drop shadow, render the original mask but clipped by the inverted mask:
    //so that only the shadow around the edges is drawn and not the content of the mask image.
    if (dropShadow)
    {
        CGContextSaveGState(cgContext);
        [NSGraphicsContext saveGraphicsState];
            if (drawFlipped)
            {
                CGContextTranslateCTM(cgContext, 0.0f, contextSize.height);
                CGContextScaleCTM(cgContext, 1.0f, -1.0f);
            }
        
            [dropShadow set];
            CGContextClipToMask(cgContext, invertedMaskRect, invertedImageMask);
            CGContextDrawImage(cgContext, maskRect, imageMask);
        [NSGraphicsContext restoreGraphicsState];
        CGContextRestoreGState(cgContext);
    }
    
    //Next, render the gradient fill by clipping the drawing area to the mask.
    if (gradient)
    {
        CGContextSaveGState(cgContext);
        [NSGraphicsContext saveGraphicsState];
            if (drawFlipped)
            {
                CGContextTranslateCTM(cgContext, 0.0f, contextSize.height);
                CGContextScaleCTM(cgContext, 1.0f, -1.0f);
            }
        
            CGContextClipToMask(cgContext, maskRect, imageMask);
            [gradient drawInRect: drawRect angle: 270.0];
        [NSGraphicsContext restoreGraphicsState];
        CGContextRestoreGState(cgContext);
    }
    
    //Finally, render the inner shadow by rendering the inverted mask by clipped by the original mask:
    //again so that only the shadow around the edges is drawn, and not the mask's contents.
    if (innerShadow)
    {
        CGContextSaveGState(cgContext);
        [NSGraphicsContext saveGraphicsState];
            if (drawFlipped)
            {
                CGContextTranslateCTM(cgContext, 0.0f, contextSize.height);
                CGContextScaleCTM(cgContext, 1.0f, -1.0f);
            }
        
            [innerShadow set];
            CGContextClipToMask(cgContext, maskRect, imageMask);
            CGContextDrawImage(cgContext, invertedMaskRect, invertedImageMask);
        [NSGraphicsContext restoreGraphicsState];
        CGContextRestoreGState(cgContext);
    }
    
    CGContextRelease(maskContext);
    CGImageRelease(invertedImageMask);
}

@end
