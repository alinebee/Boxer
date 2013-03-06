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
    NSAssert(self.isTemplate, @"drawInRect:withGradient:dropShadow:innerShadow: can only be used with template images.");
    
    //Check if we're rendering into a backing intended for retina displays.
    NSSize pointSize = NSMakeSize(1, 1);
    if ([[NSView focusView] respondsToSelector: @selector(convertSizeToBacking:)])
         pointSize = [[NSView focusView] convertSizeToBacking: pointSize];
    
    NSSize contextSize = [NSView focusView].bounds.size;
    
    NSGraphicsContext *context = [NSGraphicsContext currentContext];
    CGContextRef cgContext = (CGContextRef)context.graphicsPort;
    
    BOOL drawFlipped = respectContextIsFlipped && context.isFlipped;
    
    //Now calculate the total area of the context that will be affected by our drawing,
    //including our drop shadow. Our mask images will be created at this size to ensure
    //that the whole canvas is properly masked.
    
    NSRect totalDirtyRect = drawRect;
    if (dropShadow)
    {
        totalDirtyRect = NSUnionRect(totalDirtyRect, [dropShadow shadowedRect: drawRect flipped: NO]);
    }
    
    //TWEAK: also expand the dirty rect to encompass our *inner* shadow as well.
    //Because the resulting mask is used to draw the inner shadow, it needs to have enough
    //padding around all relevant edges that the inner shadow appears 'solid' and doesn't
    //get cut off.
    if (innerShadow)
    {
        totalDirtyRect = NSUnionRect(totalDirtyRect, [dropShadow rectToCastInnerShadow: drawRect flipped: NO]);
    }
    
    CGRect maskRect = CGRectIntegral(NSRectToCGRect(totalDirtyRect));
    
    
    //First get a representation of the image suitable for drawing into the destination.
    CGRect imageRect = NSRectToCGRect(drawRect);
    CGImageRef baseImage = [self CGImageForProposedRect: &drawRect context: context hints: nil];
    
    //Next, render it into a new bitmap context sized to cover the whole dirty area.
    //We then grab regular and inverted CGImages from that context to use as masks.
    
    //NOTE: Because CGBitmapContexts are not retina-aware and use device pixels,
    //we have to compensate accordingly when we're rendering for a retina backing.
    CGSize maskPixelSize = CGSizeMake(maskRect.size.width * pointSize.width,
                                      maskRect.size.height * pointSize.height);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef maskContext = CGBitmapContextCreate(NULL,
                                                     maskPixelSize.width,
                                                     maskPixelSize.height,
                                                     8,
                                                     maskPixelSize.width * 4,
                                                     colorSpace,
                                                     kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    
    CGRect relativeMaskRect = CGRectMake((imageRect.origin.x - maskRect.origin.x) * pointSize.width,
                                         (imageRect.origin.y - maskRect.origin.y) * pointSize.height,
                                         imageRect.size.width * pointSize.width,
                                         imageRect.size.height * pointSize.height);
    
    CGContextDrawImage(maskContext, relativeMaskRect, baseImage);
    //Grab our first mask image, which is just the original image with padding.
    CGImageRef imageMask = CGBitmapContextCreateImage(maskContext);
    
    //Now invert the colors in the context and grab another image, which will be our inverse mask.
    CGContextSetBlendMode(maskContext, kCGBlendModeXOR);
    CGContextSetRGBFillColor(maskContext, 1.0, 1.0, 1.0, 1.0);
    CGContextFillRect(maskContext, CGRectMake(0, 0, maskPixelSize.width, maskPixelSize.height));
    CGImageRef invertedImageMask = CGBitmapContextCreateImage(maskContext);
    

    //To render the drop shadow, draw the original mask but clipped by the inverted mask:
    //so that the shadow is only drawn around the edges, and not within the inside of the image.
    //(IMPLEMENTATION NOTE: we draw the drop shadow in a separate pass instead of just setting the
    //drop shadow when we draw the fill gradient, because otherwise a semi-transparent gradient would
    //render a drop shadow underneath the translucent parts: making the result appear muddy.)
    if (dropShadow)
    {
        CGContextSaveGState(cgContext);
            if (drawFlipped)
            {
                CGContextTranslateCTM(cgContext, 0.0f, contextSize.height);
                CGContextScaleCTM(cgContext, 1.0f, -1.0f);
            }
        
            //IMPLEMENTATION NOTE: we want to draw the drop shadow but not the image that's 'causing' the shadow.
            //So, we draw that image wayyy off the top of the canvas, and offset the shadow far enough that
            //it lands in the expected position.
            
            CGRect imageOffset = CGRectOffset(maskRect, 0, maskRect.size.height);
            CGSize shadowOffset = CGSizeMake(dropShadow.shadowOffset.width,
                                             dropShadow.shadowOffset.height - maskRect.size.height);
            
            CGFloat components[dropShadow.shadowColor.numberOfComponents];
            [dropShadow.shadowColor getComponents: components];
            CGColorRef shadowColor = CGColorCreate(dropShadow.shadowColor.colorSpace.CGColorSpace, components);
            
            CGContextClipToMask(cgContext, maskRect, invertedImageMask);
            CGContextSetShadowWithColor(cgContext, shadowOffset, dropShadow.shadowBlurRadius, shadowColor);
            CGContextDrawImage(cgContext, imageOffset, imageMask);
            
            CGColorRelease(shadowColor);
        
        CGContextRestoreGState(cgContext);
    }
    
    //Finally, render the inner region with the gradient and inner shadow (if any)
    //by clipping the drawing area to the regular mask.
    if (gradient || innerShadow)
    {
        CGContextSaveGState(cgContext);
            if (drawFlipped)
            {
                CGContextTranslateCTM(cgContext, 0.0f, contextSize.height);
                CGContextScaleCTM(cgContext, 1.0f, -1.0f);
            }
            CGContextClipToMask(cgContext, maskRect, imageMask);
        
            if (gradient)
            {
                [gradient drawInRect: drawRect angle: 270.0];
            }
            
            if (innerShadow)
            {
                //See dropShadow note above about offsets.
                CGRect imageOffset = CGRectOffset(maskRect, 0, maskRect.size.height);
                CGSize shadowOffset = CGSizeMake(innerShadow.shadowOffset.width,
                                                 innerShadow.shadowOffset.height - maskRect.size.height);
                
                CGFloat components[innerShadow.shadowColor.numberOfComponents];
                [innerShadow.shadowColor getComponents: components];
                CGColorRef shadowColor = CGColorCreate(innerShadow.shadowColor.colorSpace.CGColorSpace, components);
                
                CGContextSetShadowWithColor(cgContext, shadowOffset, innerShadow.shadowBlurRadius, shadowColor);
                CGContextDrawImage(cgContext, imageOffset, invertedImageMask);
                
                CGColorRelease(shadowColor);
            }
        CGContextRestoreGState(cgContext);
    }
    
    CGContextRelease(maskContext);
    CGImageRelease(imageMask);
    CGImageRelease(invertedImageMask);
}

@end
