//
//  BXDOSWindowLoadingSpinner.m
//  Boxer
//
//  Created by Alun Bestor on 14/08/2012.
//  Copyright (c) 2012 Alun Bestor and contributors. All rights reserved.
//

#import "BXDOSWindowLoadingSpinner.h"
#import "NSShadow+BXShadowExtensions.h"

@interface BXDOSWindowLoadingSpinner ()
@property (retain, nonatomic) NSShadow *dropShadow;

@end

@implementation BXDOSWindowLoadingSpinner
@synthesize dropShadow = _dropShadow;

- (void) awakeFromNib
{
    self.color = [NSColor whiteColor];
    self.drawsBackground = NO;
    self.lineWidth = 2.0f;
    self.dropShadow = [NSShadow shadowWithBlurRadius: 4.0f
                                              offset: NSMakeSize(0, -1.0f)
                                               color: [NSColor blackColor]];
}

- (void) dealloc
{
    self.dropShadow = nil;
    [super dealloc];
}

- (void) drawRect: (NSRect)dirtyRect
{
    [NSGraphicsContext saveGraphicsState];
        [self.dropShadow set];
        [super drawRect: dirtyRect];
    [NSGraphicsContext restoreGraphicsState];
}

@end
