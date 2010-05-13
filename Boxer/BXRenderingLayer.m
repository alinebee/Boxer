//
//  BXRenderingLayer.m
//  Boxer
//
//  Created by Alun on 10/05/2010.
//  Copyright 2010 Alun Bestor and contributors. All rights reserved.
//

#import "BXRenderingLayer.h"
#import "BXFrameBuffer.h"
#import <OpenGL/CGLMacro.h>


@implementation BXRenderingLayer
@synthesize currentFrame;

- (void) dealloc
{
	[self setCurrentFrame: nil], [currentFrame release];
	[super dealloc];
}

- (void) drawFrame: (BXFrameBuffer *)frame
{
	[self setCurrentFrame: frame];
	[self setNeedsDisplay];
	[self setHidden: NO];
	needsFrameTextureUpdate = YES;
}

- (void) setBounds: (CGRect)newBounds
{
	[super setBounds: newBounds];
	//We need to recalculate our scaling buffer size 
	recalculateScalingBuffer = YES;
}

- (void) setCurrentFrame: (BXFrameBuffer *)frame
{
	[self willChangeValueForKey: @"currentFrame"];
	
	if (frame != currentFrame)
	{
		//If the buffer memory locations for the two frames are different, we'll need to reinitialize
		//the texture to link to the new buffer. This will be done next time we draw.
		if ([frame bytes] != [currentFrame bytes])
			 needsNewFrameTexture = YES;
		
		//If the buffers for the two frames are a different size, we'll need to recreate the scaling buffer too
		if (!NSEqualSizes([frame resolution], [currentFrame resolution]))
			recalculateScalingBuffer = YES;
			
		
		[currentFrame autorelease];
		currentFrame = [frame retain];
	}
	[self didChangeValueForKey: @"currentFrame"];
}


#pragma mark -
#pragma mark Preparing the rendering context

- (CGLContextObj) copyCGLContextForPixelFormat: (CGLPixelFormatObj)pixelFormat
{
	CGLContextObj cgl_ctx = [super copyCGLContextForPixelFormat: pixelFormat];
	
	//TODO: we'll load and compile our shaders here
	
	//Check for FBO support and enable/disable the scaling buffer accordingly
	useScalingBuffer = (BOOL)gluCheckExtension((const GLubyte *)"GL_EXT_framebuffer_object", glGetString(GL_EXTENSIONS));
	useScalingBuffer = NO;
	
	return cgl_ctx;
}

- (void) releaseCGLContext: (CGLContextObj)glContext
{
	CGLContextObj cgl_ctx = glContext;

	if (glIsTexture(frameTexture))			glDeleteTextures(1, &frameTexture);
	if (glIsTexture(scalingBufferTexture))	glDeleteTextures(1, &scalingBufferTexture);
	if (glIsFramebufferEXT(scalingBuffer))	glDeleteFramebuffersEXT(1, &scalingBuffer);
	frameTexture			= 0;
	scalingBufferTexture	= 0;
	scalingBuffer			= 0;

	[super releaseCGLContext: glContext];
}


#pragma mark -
#pragma mark Actually drawing things

- (BOOL) canDrawInCGLContext: (CGLContextObj)glContext
				 pixelFormat: (CGLPixelFormatObj)pixelFormat
				forLayerTime: (CFTimeInterval)timeInterval
				 displayTime: (const CVTimeStamp *)timeStamp
{
	return [self currentFrame] != nil;
}


- (void) drawInCGLContext: (CGLContextObj)glContext
			  pixelFormat: (CGLPixelFormatObj)pixelFormat
			 forLayerTime: (CFTimeInterval)timeInterval
			  displayTime: (const CVTimeStamp *)timeStamp
{
	CGLContextObj cgl_ctx = glContext;
	
    CGLLockContext(cgl_ctx);
	
	[self _prepareFrameTextureForCurrentFrameInCGLContext: glContext];
	[self _prepareScalingBufferForCurrentFrameInCGLContext: glContext];
	
	[self _renderCurrentFrameInCGLContext: glContext];
	
    CGLUnlockContext(cgl_ctx);
	
	[super drawInCGLContext: glContext
				pixelFormat: pixelFormat
			   forLayerTime: timeInterval
				displayTime: timeStamp];
}

- (void) _renderCurrentFrameInCGLContext: (CGLContextObj)glContext
{
	CGLContextObj cgl_ctx = glContext;
		
	glPushClientAttrib(GL_CLIENT_ALL_ATTRIB_BITS);
    glPushAttrib(GL_ALL_ATTRIB_BITS);
	
	//Enable and disable everything we'll be doing today
	glDisable(GL_DEPTH_TEST);
	glDisable(GL_LIGHTING);
	glDisable(GL_CULL_FACE);
    glDisable(GL_BLEND);
    glEnable(GL_TEXTURE_RECTANGLE_ARB);
	
	CGRect bufferRegion;
	
	//Activate our scaling buffer, which we'll draw the frame into first
	if (useScalingBuffer)
	{
		CGRect bufferRegion = CGRectMake(0, 0, scalingBufferSize.width, scalingBufferSize.height);
		
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, scalingBuffer);
	}
	
	//Now, draw the frame texture as a quad filling the 'viewport' (at this point, the framebuffer)
	CGRect textureRegion;
	textureRegion.size = NSSizeToCGSize([[self currentFrame] resolution]);

	glBindTexture(GL_TEXTURE_RECTANGLE_ARB, frameTexture);
	[self _renderTextureFromRegion: textureRegion inCGLContext: glContext];
	
	//Now, take the scaling buffer and draw that to our final viewport
	if (useScalingBuffer)
	{
		//Disable the scaling buffer, so that drawing goes to the screen from now on
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);

		glBindTexture(GL_TEXTURE_RECTANGLE_ARB, scalingBufferTexture);
		[self _renderTextureFromRegion: bufferRegion inCGLContext: glContext];
	}
	
	glBindTexture(GL_TEXTURE_RECTANGLE_ARB, 0);
	
	//Clean up the things we enabled
	glDisable(GL_TEXTURE_RECTANGLE_ARB);
    glPopAttrib();
    glPopClientAttrib();
}

- (void) _renderTextureFromRegion: (CGRect)textureRegion inCGLContext: (CGLContextObj)glContext
{
	CGLContextObj cgl_ctx = glContext;

    GLfloat texCoords[] = {
        CGRectGetMinX(textureRegion),	CGRectGetMinY(textureRegion),
        CGRectGetMaxX(textureRegion),	CGRectGetMinY(textureRegion),
        CGRectGetMaxX(textureRegion),	CGRectGetMaxY(textureRegion),
		CGRectGetMinX(textureRegion),	CGRectGetMaxY(textureRegion)
    };
    
	//Set the quad to fill the viewport
    GLfloat verts[] = {
		-1,	1,
		1,	1,
		1,	-1,
		-1,	-1
	};

	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    glTexCoordPointer(2, GL_FLOAT, 0, texCoords);
	
    glEnableClientState(GL_VERTEX_ARRAY);
    glVertexPointer(2, GL_FLOAT, 0, verts);
    
	glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
    glDisableClientState(GL_VERTEX_ARRAY);	
}


#pragma mark -
#pragma mark Preparing resources for drawing

- (void) _prepareScalingBufferForCurrentFrameInCGLContext: (CGLContextObj)glContext
{
	if (useScalingBuffer && (!scalingBuffer || recalculateScalingBuffer))
	{
		CGLContextObj cgl_ctx = glContext;
		
		CGSize newBufferSize = [self _idealScalingBufferSizeForFrame: [self currentFrame] toViewportSize: [self bounds].size];

		//If the old scaling buffer doesn't fit the new ideal size, recreate it
		if (!scalingBuffer || !CGSizeEqualToSize(scalingBufferSize, newBufferSize))
		{
			//Recreate the scaling buffer texture and the buffer itself
			if (scalingBufferTexture) glDeleteTextures(1, &scalingBufferTexture);
			scalingBufferTexture = [self _createTextureForScalingBufferOfSize: newBufferSize inCGLContext: glContext];
			
			if (scalingBuffer) glDeleteFramebuffersEXT(1, &scalingBuffer);
			scalingBuffer = [self _createScalingBufferWithTexture: scalingBufferTexture inCGLContext: glContext];
			
			scalingBufferSize = newBufferSize;			
		}
		recalculateScalingBuffer = NO;
	}
}

- (void) _prepareFrameTextureForCurrentFrameInCGLContext: (CGLContextObj)glContext
{
	CGLContextObj cgl_ctx = glContext;
	
	if (!frameTexture || needsNewFrameTexture)
	{
		//Wipe out any existing frame texture we have before replacing it
		if (frameTexture) glDeleteTextures(1, &frameTexture);
		frameTexture = [self _createTextureForFrameBuffer: [self currentFrame] inCGLContext: glContext];
		
		needsNewFrameTexture = NO;
		needsFrameTextureUpdate = NO;
	}
	else if (needsFrameTextureUpdate)
	{
		[self _fillTexture: frameTexture withFrameBuffer: [self currentFrame] inCGLContext: glContext];
		needsFrameTextureUpdate = NO;
	}
}


#pragma mark -
#pragma mark Generating and updating OpenGL resources

- (GLuint) _createTextureForFrameBuffer: (BXFrameBuffer *)frame inCGLContext: (CGLContextObj)glContext
{
	CGLContextObj cgl_ctx = glContext;

	GLuint texture;
	
	GLsizei texWidth	= (GLsizei)[frame resolution].width;
	GLsizei texHeight	= (GLsizei)[frame resolution].height;
	
	glEnable(GL_TEXTURE_RECTANGLE_ARB);
	
	//Create a new texture and bind it as the current target
	glGenTextures(1, &texture);
	glBindTexture(GL_TEXTURE_RECTANGLE_ARB, texture);
	
	//OS X-specific voodoo for mapping the framebuffer's byte array 
	//to video memory for fast texture transfers.
	
	//These are disabled for now as they produce very apparent frame tearing and shimmering
	//TODO: look into Apple Fence functions?
	//glTextureRangeAPPLE(GL_TEXTURE_RECTANGLE_ARB,  texWidth * texHeight * (32 >> 3), [frame bytes]);
	//glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_CACHED_APPLE);
	
	glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
	
	
	//Clamp the texture to avoid wrapping, and set the filtering mode to nearest-neighbour
	glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_S, GL_CLAMP);
	glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_T, GL_CLAMP);
	glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	
	//Create a new texture for the framebuffer's resolution using the framebuffer's data
	glTexImage2D(GL_TEXTURE_RECTANGLE_ARB,		//Texture target
				 0,								//Mipmap level
				 GL_RGBA8,						//Internal texture format
				 texWidth,						//Width
				 texHeight,						//Height
				 0,								//Border (unused)
				 GL_BGRA,						//Byte ordering
				 GL_UNSIGNED_INT_8_8_8_8_REV,	//Byte packing
				 [frame bytes]);				//Texture data
	
	GLenum status = glGetError();
    if (status)
    {
        NSLog(@"[BXRenderingLayer _createTextureForFrameBuffer:inCGLContext:] Could not create texture for frame buffer of size: %@ (OpenGL error %04X)", NSStringFromSize([frame resolution]), status);
		glDeleteTextures(1, &texture);
		texture = 0;
	}
	
    glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_FALSE);
	glDisable(GL_TEXTURE_RECTANGLE_ARB);

	return texture;
}

- (void) _fillTexture: (GLuint)texture withFrameBuffer: (BXFrameBuffer *)frame inCGLContext: (CGLContextObj)glContext
{
	CGLContextObj cgl_ctx = glContext;
	
	GLsizei frameWidth	= (GLsizei)[frame resolution].width;
	GLsizei frameHeight	= (GLsizei)[frame resolution].height;
	
	glEnable(GL_TEXTURE_RECTANGLE_ARB);
	glBindTexture(GL_TEXTURE_RECTANGLE_ARB, texture);
	glTexSubImage2D(GL_TEXTURE_RECTANGLE_ARB,
					0,				//Mipmap level
					0,				//X offset
					0,				//Y offset
					frameWidth,		//Width
					frameHeight,	//Height
					GL_BGRA,		//Byte ordering
					GL_UNSIGNED_INT_8_8_8_8_REV,	//Byte packing
					[frame bytes]);					//Texture data

	GLenum status = glGetError();
    if (status)
    {
        NSLog(@"[BXRenderingLayer _fillTexture:withFrameBuffer:inCGLContext:] Could not update texture for frame buffer of size: %@ (OpenGL error %04X)", NSStringFromSize([frame resolution]), status);
	}
	
	glDisable(GL_TEXTURE_RECTANGLE_ARB);
}


- (GLuint) _createTextureForScalingBufferOfSize: (CGSize)size inCGLContext: (CGLContextObj)glContext
{
	CGLContextObj cgl_ctx = glContext;

	GLuint texture;
	
	GLsizei texWidth	= (GLsizei)size.width;
	GLsizei texHeight	= (GLsizei)size.height;
	
	glEnable(GL_TEXTURE_RECTANGLE_ARB);
	
	//Create a new texture and bind it as the current target
	glGenTextures(1, &texture);
	glBindTexture(GL_TEXTURE_RECTANGLE_ARB, texture);	
	
	//Clamp the texture to avoid wrapping, and set the filtering mode to bilinear filtering
	glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_S, GL_CLAMP);
	glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_T, GL_CLAMP);
	glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	
	//Create a new empty texture of the specified size
	glTexImage2D(GL_TEXTURE_RECTANGLE_ARB,		//Texture target
				 0,								//Mipmap level
				 GL_RGBA8,						//Internal texture format
				 texWidth,						//Width
				 texHeight,						//Height
				 0,								//Border (unused)
				 GL_BGRA,						//Byte ordering
				 GL_UNSIGNED_INT_8_8_8_8_REV,	//Byte packing
				 NULL);							//Empty data
				 
	GLenum status = glGetError();
    if (status)
    {
        NSLog(@"[BXRenderingLayer _createTextureForScalingBufferOfSize:inCGLContext:] Could not create texture for scaling buffer of size: %@ (OpenGL error %04X)", NSStringFromSize(NSSizeFromCGSize(size)), status);
		glDeleteTextures(1, &texture);
		texture = 0;
	}
	
	glDisable(GL_TEXTURE_RECTANGLE_ARB);
	
	return texture;	
}

- (GLuint) _createScalingBufferWithTexture: (GLuint)texture inCGLContext: (CGLContextObj)glContext
{
	CGLContextObj cgl_ctx = glContext;
	
	GLuint newBuffer;
	
	glGenFramebuffersEXT(1, &newBuffer);
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, newBuffer);
	glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_RECTANGLE_ARB, texture, 0);

	GLenum status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
    if (status != GL_FRAMEBUFFER_COMPLETE_EXT)
    {
        NSLog(@"[BXRenderingLayer createScalingBufferWithTexture:inCGLContext:] Could not create scaling buffer (OpenGL error %04X)", status);
		glDeleteFramebuffersEXT(1, &newBuffer);
		newBuffer = 0;
	}

	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
	
	return newBuffer;
}

- (CGSize) _idealScalingBufferSizeForFrame: (BXFrameBuffer *)frame toViewportSize: (CGSize)viewportSize
{
	CGSize frameSize		= NSSizeToCGSize([frame resolution]);
	CGSize scalingFactor	= CGSizeMake(viewportSize.width / frameSize.width,
										 viewportSize.height / frameSize.height);

	//Our ideal scaling buffer size is the closest integer multiple of the
	//base resolution to the viewport size: rounding up, so that we're always
	//scaling down to maintain sharpness.
	NSInteger nearestScale = ceil(scalingFactor.height);
	
	CGSize idealBufferSize = CGSizeMake(frameSize.width * nearestScale,
										frameSize.height * nearestScale);
	
	return idealBufferSize;
}
@end