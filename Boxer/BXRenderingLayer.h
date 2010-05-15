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
	
	BOOL supportsFBO;
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
	
	NSTimeInterval lastFrameTime;
	NSTimeInterval renderingTime;
	CGFloat frameRate;
}
@property (retain) BXFrameBuffer *currentFrame;
@property (assign) CGFloat frameRate;
@property (assign) NSTimeInterval renderingTime;

- (void) updateWithFrame: (BXFrameBuffer *)frame;

- (CGRect) viewportForFrame: (BXFrameBuffer *)frame;
@end