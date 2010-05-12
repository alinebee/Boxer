//
//  BXRenderingLayer.m
//  Boxer
//
//  Created by Alun on 10/05/2010.
//  Copyright 2010 Alun Bestor and contributors. All rights reserved.
//

#import "BXRenderingLayer.h"
#import "BXFrameBuffer.h"


@implementation BXRenderingLayer
@synthesize currentFrame;

- (void) dealloc
{
	[self setCurrentFrame: nil], [currentFrame release];
	
	if (glIsTexture(frameTexture))	glDeleteTextures(1, &frameTexture);
	if (glIsList(frameDisplayList))	glDeleteLists(frameDisplayList, 1);
	
	[super dealloc];
}

- (void) drawFrame: (BXFrameBuffer *)frame
{
	[self setCurrentFrame: frame];
	[self setNeedsDisplay];
	[self setHidden: NO];
	needsFrameTextureUpdate = YES;
}

- (void) setCurrentFrame: (BXFrameBuffer *)frame
{
	[self willChangeValueForKey: @"currentFrame"];
	
	if (frame != currentFrame)
	{
		//If the buffers for the two frames are different, we'll need to reinitialize the texture
		//to link to the new buffer. This will be done next time we draw.
		if ([frame bytes] != [currentFrame bytes])
			 needsNewFrameTexture = YES;
		
		[currentFrame autorelease];
		currentFrame = [frame retain];
	}
	[self didChangeValueForKey: @"currentFrame"];
}


- (CGLContextObj) copyCGLContextForPixelFormat: (CGLPixelFormatObj)pixelFormat
{
	CGLContextObj cgl_ctx = [super copyCGLContextForPixelFormat: pixelFormat];
	
	frameTextureTarget = GL_TEXTURE_RECTANGLE_ARB;
	
	return cgl_ctx;
}


- (BOOL) canDrawInCGLContext: (CGLContextObj)glContext
				 pixelFormat: (CGLPixelFormatObj)pixelFormat
				forLayerTime: (CFTimeInterval)timeI
				 displayTime: (const CVTimeStamp *)timeStamp
{
	return [self currentFrame] != nil;
}


- (void) drawInCGLContext: (CGLContextObj)glContext
			  pixelFormat: (CGLPixelFormatObj)pixelFormat
			 forLayerTime: (CFTimeInterval)timeInterval
			  displayTime: (const CVTimeStamp *)timeStamp
{
	[self _renderFrameInCGLContext: glContext];
	
	[super drawInCGLContext: glContext
				pixelFormat: pixelFormat
			   forLayerTime: timeInterval
				displayTime: timeStamp];
}

- (void) _renderFrameInCGLContext: (CGLContextObj)glContext
{
	CGLContextObj cgl_ctx = glContext;

	if (!frameTexture || needsNewFrameTexture)
	{
		[self _prepareTextureForFrameBuffer: [self currentFrame] inCGLContext: glContext];
		needsNewFrameTexture = NO;
		needsFrameTextureUpdate = NO;
	}
	
	GLsizei frameWidth	= (GLsizei)[[self currentFrame] resolution].width;
	GLsizei frameHeight	= (GLsizei)[[self currentFrame] resolution].height;
	
    GLfloat texCoords[] = 
    {
        0,			0,
        frameWidth,	0,
        frameWidth,	frameHeight,
        0,			frameHeight
    };
    
    GLfloat verts[] = 
    {
        -1,	1,
        1,	1,
        1,	-1,
        -1,	-1
    };

	glPushClientAttrib(GL_CLIENT_ALL_ATTRIB_BITS);
    glPushAttrib(GL_ALL_ATTRIB_BITS);

	//Enable and disable everything we'll be doing today
	glEnable(frameTextureTarget);
	glDisable(GL_DEPTH_TEST);
	glDisable(GL_LIGHTING);
	glDisable(GL_CULL_FACE);
    glDisable(GL_BLEND);
	
    glBindTexture(frameTextureTarget, frameTexture);
	
	if (needsFrameTextureUpdate)
	{
		//Upload the new frame data into the texture if needed
		glTexSubImage2D(frameTextureTarget,
						0,
						0,
						0,
						frameWidth,
						frameHeight,
						GL_BGRA,
						GL_UNSIGNED_INT_8_8_8_8_REV,
						[[self currentFrame] bytes]);
		needsFrameTextureUpdate = NO;
	}
	
	//Create a set of texture and vertex coordinates and draw them as a unit
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    glTexCoordPointer(2, GL_FLOAT, 0, texCoords);
	
    glEnableClientState(GL_VERTEX_ARRAY);
    glVertexPointer(2, GL_FLOAT, 0, verts);
    
	glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
    glDisableClientState(GL_VERTEX_ARRAY);
	
	//Clean up the things we enabled
    glPopAttrib();
    glPopClientAttrib();
}

- (void) _prepareTextureForFrameBuffer: (BXFrameBuffer *)frame inCGLContext: (CGLContextObj)glContext
{
	CGLContextObj cgl_ctx = glContext;
	
	GLsizei frameWidth	= (GLsizei)[frame resolution].width;
	GLsizei frameHeight	= (GLsizei)[frame resolution].height;
	
    glPushAttrib(GL_ALL_ATTRIB_BITS);

	//Wipe out any existing frame texture we have
	if (frameTexture) glDeleteTextures(1, &frameTexture);
	
	//Create a new texture and bind it as the current target
	glGenTextures(1, &frameTexture);
	glBindTexture(frameTextureTarget, frameTexture);
	
	//OS X-specific voodoo for mapping the framebuffer's byte array 
	//to video memory for fast texture transfers.
	glTextureRangeAPPLE(frameTextureTarget,  frameWidth * frameHeight * (32 >> 3), [frame bytes]); 
	glTexParameteri(frameTextureTarget, GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_CACHED_APPLE);
	glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
	
	//Clamp the texture to avoid wrapping, and set the filtering mode to nearest-neighbour
	glTexParameteri(frameTextureTarget, GL_TEXTURE_WRAP_S, GL_CLAMP);
	glTexParameteri(frameTextureTarget, GL_TEXTURE_WRAP_T, GL_CLAMP);
	glTexParameteri(frameTextureTarget, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(frameTextureTarget, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	
	//Create a new empty texture of the specified size
	glTexImage2D(frameTextureTarget,			//Texture target
				 0,								//Mipmap level
				 GL_RGBA8,						//Internal texture format
				 frameWidth,					//Width
				 frameHeight,					//Height
				 0,								//Border (unused)
				 GL_BGRA,						//Byte ordering
				 GL_UNSIGNED_INT_8_8_8_8_REV,	//Byte packing
				 [frame bytes]					//Texture data
				 );
	
	glPopAttrib();
}
@end