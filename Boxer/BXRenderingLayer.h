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
	
	BOOL useScalingBuffer;
	
	GLuint frameTexture;
	GLuint scalingBufferTexture;
	GLuint scalingBuffer;
	CGSize scalingBufferSize;
	
	BOOL needsNewFrameTexture;
	BOOL needsFrameTextureUpdate;
	BOOL recalculateScalingBuffer;
}
@property (retain) BXFrameBuffer *currentFrame;

- (void) drawFrame: (BXFrameBuffer *)frame;

//Ensure our framebuffer and scaling buffers are prepared for rendering the current frame. Called when the layer is about to be drawn.
- (void) _prepareScalingBufferForCurrentFrameInCGLContext: (CGLContextObj)glContext;
- (void) _prepareFrameTextureForCurrentFrameInCGLContext: (CGLContextObj)glContext;

//Render the current frame. Called when the layer is drawn.
- (void) _renderCurrentFrameInCGLContext: (CGLContextObj)glContext;

//Draw a region of the currently active GL texture to a quad made from the specified points.
- (void) _renderTexture: (GLuint)texture fromRegion: (CGRect)textureRegion toPoints: (GLfloat *)vertices inCGLContext: (CGLContextObj)glContext;

//Create/update an OpenGL texture with the contents of the specified framebuffer in the specified context.
- (GLuint) _createTextureForFrameBuffer: (BXFrameBuffer *)frame inCGLContext: (CGLContextObj)glContext;
- (void) _fillTexture: (GLuint)texture withFrameBuffer: (BXFrameBuffer *)frame inCGLContext: (CGLContextObj)glContext;

//Create a new empty scaling buffer texture of the specified size in the specified context.
- (GLuint) _createTextureForScalingBuffer: (GLuint)buffer withSize: (CGSize)size inCGLContext: (CGLContextObj)glContext;

//Calculate the appropriate scaling buffer size for the specified frame to the specified viewport dimensions.
//This will be the nearest even multiple of the frame's resolution which covers the entire viewport size.
- (CGSize) _idealScalingBufferSizeForFrame: (BXFrameBuffer *)frame toViewportSize: (CGSize)viewportSize;
@end