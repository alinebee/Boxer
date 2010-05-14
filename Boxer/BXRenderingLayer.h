//
//  BXRenderingLayer.h
//  Boxer
//
//  Created by Alun on 10/05/2010.
//  Copyright 2010 Alun Bestor and contributors. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

@class BXFrameBuffer;

@interface BXRenderingLayer : CAOpenGLLayer
{
	BXFrameBuffer *currentFrame;
	
	BOOL FBOAvailable;
	BOOL useScalingBuffer;
	
	GLuint frameTexture;
	GLuint scalingBufferTexture;
	GLuint scalingBuffer;
	CGSize scalingBufferSize;
	
	CGSize maxTextureSize;
	CGSize maxScalingBufferSize;
	
	BOOL needsNewFrameTexture;
	BOOL needsFrameTextureUpdate;
	BOOL recalculateScalingBuffer;
	
	//The absolute time of the previous frame - stored internally for calculating framerate
	NSTimeInterval lastFrameEndTime;
	
	//The time it took to render the last frame - exposed as property
	NSTimeInterval lastFrameRenderTime;
	//The current framerate we are producing - exposed as property
	NSTimeInterval frameRate;
}
@property (retain) BXFrameBuffer *currentFrame;

@property (assign) NSTimeInterval lastFrameRenderTime;
@property (assign) NSTimeInterval frameRate;

- (void) drawFrame: (BXFrameBuffer *)frame;

@end