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

#import "NSShadow+ADBShadowExtensions.h"

@implementation NSShadow (ADBShadowExtensions)

+ (id) shadow
{
    return [[[self alloc] init] autorelease];
}

+ (id) shadowWithBlurRadius: (CGFloat)blurRadius
                     offset: (NSSize)offset
{
    NSShadow *theShadow = [[self alloc] init];
    theShadow.shadowBlurRadius = blurRadius;
    theShadow.shadowOffset = offset;
    return [theShadow autorelease];
}

+ (id) shadowWithBlurRadius: (CGFloat)blurRadius
                     offset: (NSSize)offset
                      color: (NSColor *)color
{
    NSShadow *theShadow = [[self alloc] init];
    theShadow.shadowBlurRadius = blurRadius;
    theShadow.shadowOffset = offset;
    theShadow.shadowColor = color;
    return [theShadow autorelease];
}

- (NSRect) insetRectForShadow: (NSRect)origRect flipped: (BOOL)flipped
{
    CGFloat radius  = self.shadowBlurRadius;
    NSSize offset   = self.shadowOffset;
    
    if (flipped)
        offset.height = -offset.height;
    
    NSRect insetRect = NSInsetRect(origRect, radius, radius);
    //FIXME: this is not totally correct, after offsetting we need to clip to the original rectangle.
    //But that raises questions about how we should deal with aspect ratios.
    insetRect = NSOffsetRect(insetRect, -offset.width, -offset.height);
    
    return insetRect;
}

- (NSRect) expandedRectForShadow: (NSRect)origRect flipped: (BOOL)flipped
{
    NSRect shadowRect = [self shadowedRect: origRect flipped: flipped];
    return NSUnionRect(origRect, shadowRect);
}

- (NSRect) shadowedRect: (NSRect)origRect flipped: (BOOL)flipped
{
    CGFloat radius  = self.shadowBlurRadius;
    NSSize offset   = self.shadowOffset;
    
    if (flipped)
        offset.height = -offset.height;
    
    NSRect shadowRect = NSInsetRect(origRect, -radius, -radius);
    return NSOffsetRect(shadowRect, offset.width, offset.height);
}

- (NSRect) rectToCastShadow: (NSRect)origRect flipped: (BOOL)flipped
{
    CGFloat radius  = self.shadowBlurRadius;
    NSSize offset   = self.shadowOffset;
    
    if (flipped)
        offset.height = -offset.height;
    
    NSRect shadowRect = NSInsetRect(origRect, radius, radius);
    return NSOffsetRect(shadowRect, -offset.width, -offset.height);
}

- (NSRect) rectToCastInnerShadow: (NSRect)origRect flipped: (BOOL)flipped
{
    CGFloat radius  = self.shadowBlurRadius;
    NSSize offset   = self.shadowOffset;
    
    if (flipped)
        offset.height = -offset.height;
    
    NSRect shadowRect = NSInsetRect(origRect, -radius, -radius);
    return NSOffsetRect(shadowRect, -offset.width, -offset.height);
}

@end
