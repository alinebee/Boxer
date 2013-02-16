/*
 *  Copyright (c) 2013, Alun Bestor (alun.bestor@gmail.com)
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *		Redistributions of source code must retain the above copyright notice, this
 *	    list of conditions and the following disclaimer.
 *
 *		Redistributions in binary form must reproduce the above copyright notice,
 *	    this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 *	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 */

#import "NSImage+ADBImageEffects.h"
#import "ADBGeometry.h"
#import "ADBAppKitVersionHelpers.h"
#import "NSShadow+ADBShadowExtensions.h"

@implementation NSImage (ADBImageEffects)

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
	
    [maskedImage lockFocus];
        [color set];
        NSRectFillUsingOperation(imageRect, NSCompositeSourceOver);
        [sourceImage drawInRect: imageRect
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
