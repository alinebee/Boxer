/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXRenderingLayer.h"
#import "BXRenderer.h"

@implementation BXRenderingLayer
@synthesize renderer;

- (id) init
{
	if ((self = [super init]))
	{
		[self setNeedsDisplayOnBoundsChange: YES];
		[self setOpaque: YES];
		[self setAsynchronous: NO];	
		[self setRenderer: [[[BXRenderer alloc] init] autorelease]];
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
