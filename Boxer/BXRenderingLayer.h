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
	GLuint frameTexture;
	GLuint frameDisplayList;
	GLenum frameTextureTarget;
	
	BXFrameBuffer *currentFrame;
	
	BOOL needsNewFrameTexture;
	BOOL needsFrameTextureUpdate;
}
@property (retain) BXFrameBuffer *currentFrame;

- (void) drawFrame: (BXFrameBuffer *)frame;

- (void) _prepareTextureForFrameBuffer: (BXFrameBuffer *)frame inCGLContext: (CGLContextObj)glContext;
- (void) _renderFrameInCGLContext: (CGLContextObj)glContext;

@end