//
//  BXDOSWindowLoadingSpinner.m
//  Boxer
//
//  Created by Alun Bestor on 14/08/2012.
//  Copyright (c) 2012 Alun Bestor and contributors. All rights reserved.
//

#import "BXDOSWindowLoadingSpinner.h"
#import "NSShadow+BXShadowExtensions.h"

@implementation BXDOSWindowLoadingSpinner

- (void) awakeFromNib
{
    self.color = [NSColor whiteColor];
    self.drawsBackground = NO;
    self.lineWidth = 2.0f;
    _dropShadow = [NSShadow shadowWithBlurRadius: 4.0f
                                          offset: NSMakeSize(0, -1.0f)
                                           color: [NSColor blackColor]];
    [_dropShadow retain];
}

- (void) dealloc
{
    [_dropShadow release], _dropShadow = nil;
    [super dealloc];
}

- (void) drawRect: (NSRect)dirtyRect
{	
    [_dropShadow set];
    [super drawRect: dirtyRect];
}
@end
