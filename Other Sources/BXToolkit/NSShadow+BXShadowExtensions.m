//
//  NSShadow+BXShadowExtensions.m
//  Boxer
//
//  Created by Alun Bestor on 24/07/2011.
//  Copyright 2011 Alun Bestor and contributors. All rights reserved.
//

#import "NSShadow+BXShadowExtensions.h"


@implementation NSShadow (NSShadow_BXShadowExtensions)

+ (id) shadow
{
    return [[[self alloc] init] autorelease];
}

+ (id) shadowWithBlurRadius: (CGFloat)blurRadius
                     offset: (NSSize)offset
{
    NSShadow *theShadow = [[self alloc] init];
    [theShadow setShadowBlurRadius: blurRadius];
    [theShadow setShadowOffset: offset];
    
    return [theShadow autorelease];
}

+ (id) shadowWithBlurRadius: (CGFloat)blurRadius
                     offset: (NSSize)offset
                      color: (NSColor *)color
{
    NSShadow *theShadow = [[self alloc] init];
    [theShadow setShadowBlurRadius: blurRadius];
    [theShadow setShadowOffset: offset];
    [theShadow setShadowColor: color];
    
    return [theShadow autorelease];
}

- (NSRect) insetRectForShadow: (NSRect)origRect
{
    CGFloat radius  = [self shadowBlurRadius];
    NSSize offset   = [self shadowOffset];
    
    NSRect insetRect  = NSInsetRect(origRect, radius, radius);
    insetRect.origin.x -= offset.width;
    insetRect.origin.y -= offset.height;
    
    return insetRect;
}

- (NSRect) expandedRectForShadow: (NSRect)origRect
{
    CGFloat radius  = [self shadowBlurRadius];
    NSSize offset   = [self shadowOffset];
    
    NSRect expandedRect  = NSInsetRect(origRect, -radius, -radius);
    expandedRect.origin.x += offset.width;
    expandedRect.origin.y += offset.height;
    
    return expandedRect;
}

@end
