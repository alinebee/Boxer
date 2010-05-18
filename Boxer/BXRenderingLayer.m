//
//  BXRenderingLayer.m
//  Boxer
//
//  Created by Alun on 10/05/2010.
//  Copyright 2010 Alun Bestor and contributors. All rights reserved.
//

#import "BXRenderingLayer.h"
#import "BXRenderer.h"

@implementation BXRenderingLayer
@synthesize renderer;

- (id) init
{
	if ((self = [super init]))
	{
		//Set up our initial properties as we know them to be
		[self setNeedsDisplayOnBoundsChange: YES];
		[self setOpaque: YES];
		[self setAsynchronous: NO];	
		[self setRenderer: [[BXRenderer new] autorelease]];
	}
	return self;
}

- (void) dealloc
{
	[self setRenderer: nil], [renderer release];
	[super dealloc];
}

- (void) setBounds: (CGRect)newBounds
{
	[super setBounds: newBounds];
	[[self renderer] setCanvas: newBounds];
}


#pragma mark -
#pragma mark Preparing the rendering context

- (CGLContextObj) copyCGLContextForPixelFormat: (CGLPixelFormatObj)pixelFormat
{
	CGLContextObj cgl_ctx = [super copyCGLContextForPixelFormat: pixelFormat];
	
	[[self renderer] prepareForGLContext: cgl_ctx];
	
	return cgl_ctx;
}

- (void) releaseCGLContext: (CGLContextObj)glContext
{
	[[self renderer] tearDownGLContext: glContext];
	[super releaseCGLContext: glContext];
}


#pragma mark -
#pragma mark Actually drawing things

- (BOOL) canDrawInCGLContext: (CGLContextObj)glContext
				 pixelFormat: (CGLPixelFormatObj)pixelFormat
				forLayerTime: (CFTimeInterval)timeInterval
				 displayTime: (const CVTimeStamp *)timeStamp
{
	return [[self renderer] canRenderToGLContext: glContext];
}


- (void) drawInCGLContext: (CGLContextObj)glContext
			  pixelFormat: (CGLPixelFormatObj)pixelFormat
			 forLayerTime: (CFTimeInterval)timeInterval
			  displayTime: (const CVTimeStamp *)timeStamp
{	
	[[self renderer] renderToGLContext: glContext];
	
	[super drawInCGLContext: glContext
				pixelFormat: pixelFormat
			   forLayerTime: timeInterval
				displayTime: timeStamp];
}

@end