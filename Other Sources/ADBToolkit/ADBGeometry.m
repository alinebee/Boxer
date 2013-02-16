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

#import "ADBGeometry.h"

NSInteger fitToPowerOfTwo(NSInteger value)
{
    int shift = 0;
    while ((value >>= 1) != 0) shift++;
    return 2 << shift;
}

CGFloat aspectRatioOfSize(NSSize size)
{
	return (size.height) ? (size.width / size.height) : 0.0f;
}

NSPoint integralPoint(NSPoint point)
{
    return NSMakePoint(roundf(point.x), roundf(point.y));
}

NSSize integralSize(NSSize size)
{
	//To match behaviour of NSIntegralRect
	if (size.width <= 0 || size.height <= 0) return NSZeroSize;
	return NSMakeSize(ceilf(size.width), ceilf(size.height));
}

NSSize sizeToMatchRatio(NSSize size, CGFloat aspectRatio, BOOL preserveHeight)
{
	//Calculation is impossible - perhaps we should assert here instead
	if (aspectRatio == 0) return NSZeroSize;
	
	if (preserveHeight) return NSMakeSize(size.height * aspectRatio, size.height);
	else				return NSMakeSize(size.width, size.width / aspectRatio);
}

BOOL sizeFitsWithinSize(NSSize innerSize, NSSize outerSize)
{
	return (innerSize.width <= outerSize.width) && (innerSize.height <= outerSize.height);
}

NSSize sizeToFitSize(NSSize innerSize, NSSize outerSize)
{
	NSSize finalSize = outerSize;
	CGFloat ratioW = outerSize.width / innerSize.width;
	CGFloat ratioH = outerSize.height / innerSize.height;
	
	if (ratioW < ratioH)	finalSize.height	= (innerSize.height * ratioW);
	else					finalSize.width		= (innerSize.width * ratioH);
	return finalSize;
}

NSSize constrainToFitSize(NSSize innerSize, NSSize outerSize)
{
	if (sizeFitsWithinSize(innerSize, outerSize)) return innerSize;
	else return sizeToFitSize(innerSize, outerSize);
}

NSRect resizeRectFromPoint(NSRect theRect, NSSize newSize, NSPoint anchor)
{	
	CGFloat widthDiff	= newSize.width		- theRect.size.width;
	CGFloat heightDiff	= newSize.height	- theRect.size.height;
	
	NSRect newRect		= theRect;
	newRect.size		= newSize;
	newRect.origin.x	-= widthDiff	* anchor.x;
	newRect.origin.y	-= heightDiff	* anchor.y;
	
	return newRect;
}

NSPoint pointRelativeToRect(NSPoint thePoint, NSRect theRect)
{
	NSPoint anchorPoint = NSZeroPoint;
	anchorPoint.x = (theRect.size.width > 0.0f)		? ((thePoint.x - theRect.origin.x) / theRect.size.width)	: 0.0f;
	anchorPoint.y = (theRect.size.height > 0.0f)	? ((thePoint.y - theRect.origin.y) / theRect.size.height)	: 0.0f;
	return anchorPoint;
}

NSRect alignInRectWithAnchor(NSRect innerRect, NSRect outerRect, NSPoint anchor)
{
	NSRect alignedRect = innerRect;
	alignedRect.origin.x = outerRect.origin.x + (anchor.x * (outerRect.size.width - innerRect.size.width));
	alignedRect.origin.y = outerRect.origin.y + (anchor.y * (outerRect.size.height - innerRect.size.height));
	return alignedRect;	
}

NSRect centerInRect(NSRect innerRect, NSRect outerRect)
{
	return alignInRectWithAnchor(innerRect, outerRect, NSMakePoint(0.5f, 0.5f));
}

NSRect fitInRect(NSRect innerRect, NSRect outerRect, NSPoint anchor)
{
	NSRect fittedRect = NSZeroRect;
	fittedRect.size = sizeToFitSize(innerRect.size, outerRect.size);
	return alignInRectWithAnchor(fittedRect, outerRect, anchor);
}

NSRect constrainToRect(NSRect innerRect, NSRect outerRect, NSPoint anchor)
{
	if (sizeFitsWithinSize(innerRect.size, outerRect.size))
    {
		return alignInRectWithAnchor(innerRect, outerRect, anchor);
    }
	else
    {
        return fitInRect(innerRect, outerRect, anchor);
    }
}

NSPoint clampPointToRect(NSPoint point, NSRect rect)
{
	NSPoint clampedPoint = NSZeroPoint;
	clampedPoint.x = fmaxf(fminf(point.x, NSMaxX(rect)), NSMinX(rect));
	clampedPoint.y = fmaxf(fminf(point.y, NSMaxY(rect)), NSMinY(rect));
	return clampedPoint;
}

NSPoint deltaFromPointToPoint(NSPoint pointA, NSPoint pointB)
{
	return NSMakePoint(pointB.x - pointA.x,
					   pointB.y - pointA.y);
}

NSPoint pointWithDelta(NSPoint point, NSPoint delta)
{
	return NSMakePoint(point.x + delta.x,
					   point.y + delta.y);
}
NSPoint pointWithoutDelta(NSPoint point, NSPoint delta)
{
	return NSMakePoint(point.x - delta.x,
					   point.y - delta.y);
}


#pragma mark -
#pragma mark CG functions

BOOL CGSizeFitsWithinSize(CGSize innerSize, CGSize outerSize)
{
	return (innerSize.width <= outerSize.width) && (innerSize.height <= outerSize.height);	
}

CGSize CGSizeToFitSize(CGSize innerSize, CGSize outerSize)
{
	CGSize finalSize = outerSize;
	CGFloat ratioW = outerSize.width / innerSize.width;
	CGFloat ratioH = outerSize.height / innerSize.height;
	
	if (ratioW < ratioH)	finalSize.height	= (innerSize.height * ratioW);
	else					finalSize.width		= (innerSize.width * ratioH);
	return finalSize;
}

CGPoint CGPointIntegral(CGPoint point)
{
    return CGPointMake(round(point.x), round(point.y));
}

CGSize CGSizeIntegral(CGSize size)
{
	//To match behaviour of CGRectIntegral
	if (size.width <= 0 || size.height <= 0) return CGSizeZero;
	return CGSizeMake(ceil(size.width), ceil(size.height));
}
