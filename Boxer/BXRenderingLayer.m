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
#import "BXGeometry.h"

//When scaling up beyond this we won't bother with the scaling buffer
const CGFloat BXScalingBufferScaleCutoff = 2.5;

//The maximum feasible width and height to use for a scaling buffer based on a modest GPU (i.e. my white Macbook).
//In future, this should be determined from the characteristics of the actual GPU.
const CGFloat BXMaxFeasibleScalingBufferWidth = 1280;
const CGFloat BXMaxFeasibleScalingBufferHeight = 960;



@interface BXRenderingLayer (BXRenderingLayerInternals)

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


@implementation BXRenderingLayer
@synthesize currentFrame, frameRate, lastFrameRenderTime;

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

+ (NSSet *) keyPathsForValuesAffectingFrameRateInfo	{ return [NSSet setWithObject: @"frameRate"]; }

- (NSString *)frameRateInfo
{
	if ([self lastFrameRenderTime])
	{
		return [NSString stringWithFormat: @"%.01f fps (%.02f ms)", [self frameRate], [self lastFrameRenderTime] * 1000, nil];
	}
	else return @"";
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
	
	//Check for FBO support to see if we can use a scaling buffer
	FBOAvailable = (BOOL)gluCheckExtension((const GLubyte *)"GL_EXT_framebuffer_object", glGetString(GL_EXTENSIONS));
	useScalingBuffer = FBOAvailable;
	
	//Check what the largest texture size we can support is
	GLint maxTextureDims;
	glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureDims);
	
	maxTextureSize = CGSizeMake((CGFloat)maxTextureDims, (CGFloat)maxTextureDims);
	
	CGSize maxFeasibleScalingBufferSize = CGSizeMake(BXMaxFeasibleScalingBufferWidth, BXMaxFeasibleScalingBufferHeight);
	maxScalingBufferSize = BXCGSmallerSize(maxTextureSize, maxFeasibleScalingBufferSize);
	
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
	NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
	
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
	
	NSTimeInterval endTime = [NSDate timeIntervalSinceReferenceDate];
	
	[self setLastFrameRenderTime: endTime - startTime];
	
	if (lastFrameEndTime) [self setFrameRate: 1 / (endTime - lastFrameEndTime)];
	lastFrameEndTime = endTime;
}

- (void) _renderCurrentFrameInCGLContext: (CGLContextObj)glContext
{
	CGLContextObj cgl_ctx = glContext;
	
	CGRect frameRegion, scalingRegion;

	GLint contextFramebuffer;
	glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &contextFramebuffer);
	
	glPushClientAttrib(GL_CLIENT_ALL_ATTRIB_BITS);
    glPushAttrib(GL_ALL_ATTRIB_BITS);
	
	//Enable and disable everything we'll be doing today
	glDisable(GL_DEPTH_TEST);
	glDisable(GL_SCISSOR_TEST);
	glDisable(GL_LIGHTING);
	glDisable(GL_CULL_FACE);
    glDisable(GL_BLEND);
    glEnable(GL_TEXTURE_RECTANGLE_ARB);
	
	
	//Activate our scaling buffer, which we'll draw the frame into first
	if (useScalingBuffer)
	{
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, scalingBuffer);
		
		//Set the viewport to match the size of the scaling buffer (rather than the layer size)
		glPushAttrib(GL_VIEWPORT_BIT);
		glViewport(0, 0, (GLsizei)scalingBufferSize.width, (GLsizei)scalingBufferSize.height);
	}
	
	//Draw the frame texture as a quad filling the viewport/framebuffer
	//-----------
	frameRegion.size = NSSizeToCGSize([[self currentFrame] resolution]);
	GLfloat frameVerts[] = {
		-1,	1,
		1,	1,
		1,	-1,
		-1,	-1
	};

	[self _renderTexture: frameTexture
			  fromRegion: frameRegion
				toPoints: frameVerts
			inCGLContext: glContext];
	
	
	if (useScalingBuffer)
	{
		//Revert the GL viewport to match the layer size (as set by our calling context)
		glPopAttrib();
		
		//...and now for some reason we need to set it explicitly again here
		//FIXME: work out why this is getting screwed up.
		glViewport((GLint)[self bounds].origin.x,
				   (GLint)[self bounds].origin.y,
				   (GLsizei)[self bounds].size.width,
				   (GLsizei)[self bounds].size.height);
		
		//Revert the framebuffer to what it was in the context, so that drawing goes to
		//the proper place from now on
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, contextFramebuffer);

		
		//Finally, take the scaling buffer texture and draw that into the original viewport
		//--------
		scalingRegion = CGRectMake(0, 0, scalingBufferSize.width, scalingBufferSize.height);
		
		//Note that this is flipped vertically from the coordinates we use for rendering the frame texture
		GLfloat scalingVerts[] = {
			-1,	-1,
			1,	-1,
			1,	1,
			-1,	1
		};
		
		[self _renderTexture: scalingBufferTexture
				  fromRegion: scalingRegion
					toPoints: scalingVerts
				inCGLContext: glContext];
	}
	
	//Clean up the things we enabled
    glPopAttrib();
    glPopClientAttrib();
}

- (void) _renderTexture: (GLuint)texture fromRegion: (CGRect)textureRegion toPoints: (GLfloat *)vertices inCGLContext: (CGLContextObj)glContext
{
	CGLContextObj cgl_ctx = glContext;

    GLfloat texCoords[] = {
        CGRectGetMinX(textureRegion),	CGRectGetMinY(textureRegion),
        CGRectGetMaxX(textureRegion),	CGRectGetMinY(textureRegion),
        CGRectGetMaxX(textureRegion),	CGRectGetMaxY(textureRegion),
		CGRectGetMinX(textureRegion),	CGRectGetMaxY(textureRegion)
    };

	glEnable(GL_TEXTURE_RECTANGLE_ARB);
	glBindTexture(GL_TEXTURE_RECTANGLE_ARB, texture);
	
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    glTexCoordPointer(2, GL_FLOAT, 0, texCoords);
	
    glEnableClientState(GL_VERTEX_ARRAY);
    glVertexPointer(2, GL_FLOAT, 0, vertices);
    
	glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
    glDisableClientState(GL_VERTEX_ARRAY);
	
	glBindTexture(GL_TEXTURE_RECTANGLE_ARB, 0);
	glDisable(GL_TEXTURE_RECTANGLE_ARB);
}


#pragma mark -
#pragma mark Preparing resources for drawing

- (void) _prepareScalingBufferForCurrentFrameInCGLContext: (CGLContextObj)glContext
{
	if (FBOAvailable && (!scalingBuffer || recalculateScalingBuffer))
	{
		CGLContextObj cgl_ctx = glContext;
		
		CGSize newBufferSize = [self _idealScalingBufferSizeForFrame: [self currentFrame] toViewportSize: [self bounds].size];
		
		//If the old scaling buffer doesn't fit the new ideal size, recreate it
		if (!scalingBuffer || !CGSizeEqualToSize(scalingBufferSize, newBufferSize))
		{
			//Create the scaling buffer if it is missing
			if (!scalingBuffer) glGenFramebuffersEXT(1, &scalingBuffer);
			
			//A zero suggested size means the scaling buffer is not necessary, so disable it
			if (CGSizeEqualToSize(newBufferSize, CGSizeZero))
			{
				useScalingBuffer = NO;
			}
			else
			{
				//(Re)create the scaling buffer texture
				if (scalingBufferTexture) glDeleteTextures(1, &scalingBufferTexture);
				scalingBufferTexture = [self _createTextureForScalingBuffer: scalingBuffer withSize: newBufferSize inCGLContext: glContext];
							
				useScalingBuffer = YES;
			}
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
	
	
	//Clamp the texture to avoid wrapping, and set the filtering mode to use nearest-neighbour when scaling up
	glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_S, GL_CLAMP);
	glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_T, GL_CLAMP);
	glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
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


- (GLuint) _createTextureForScalingBuffer: (GLuint)buffer withSize: (CGSize)size inCGLContext: (CGLContextObj)glContext
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
        NSLog(@"[BXRenderingLayer _createTextureForScalingBuffer:withSize:inCGLContext:] Could not create texture for scaling buffer of size: %@ (OpenGL error %04X)", NSStringFromSize(NSSizeFromCGSize(size)), status);
		glDeleteTextures(1, &texture);
		texture = 0;
	}
	
	//Now bind it to the specified buffer
	if (texture)
	{
		GLint contextFramebuffer;
		glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &contextFramebuffer);
		
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, buffer);
		glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_RECTANGLE_ARB, texture, 0);
		
		status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
		if (status != GL_FRAMEBUFFER_COMPLETE_EXT)
		{
			NSLog(@"[BXRenderingLayer _createTextureForScalingBuffer:withSize:inCGLContext:] Could not bind to scaling buffer (OpenGL error %04X)", status);
			glDeleteTextures(1, &texture);
			texture = 0;
		}
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, contextFramebuffer);
	}
	
	glDisable(GL_TEXTURE_RECTANGLE_ARB);
	
	return texture;	
}

- (CGSize) _idealScalingBufferSizeForFrame: (BXFrameBuffer *)frame toViewportSize: (CGSize)viewportSize
{
	CGSize frameSize		= NSSizeToCGSize([frame resolution]);
	CGSize scalingFactor	= CGSizeMake(viewportSize.width / frameSize.width,
										 viewportSize.height / frameSize.height);
	
	//TODO: once we get the additional rendering styles reimplemented, the optimisations below
	//should be specific to the Original style.

	//We disable the scaling buffer for scales over a certain limit, where (we assume) stretching
	//artifacts won't be visible.
	if (scalingFactor.height > BXScalingBufferScaleCutoff) return CGSizeZero;
	
	//If the viewport is an even multiple of the initial resolution then we don't need to scale either.
	if (!((NSInteger)viewportSize.width % (NSInteger)frameSize.width) && 
		!((NSInteger)viewportSize.height % (NSInteger)frameSize.height)) return CGSizeZero;
	
	//Our ideal scaling buffer size is the closest integer multiple of the
	//base resolution to the viewport size: rounding up, so that we're always
	//scaling down to maintain sharpness.
	NSInteger nearestScale = ceilf(scalingFactor.height);
	
	//Work our way down from that to the largest scale that will still fit into our maximum allowable size.
	CGSize idealBufferSize;
	do
	{		
		//If we're not scaling up at all in the end, then disable the scaling buffer altogether.
		if (nearestScale <= 1) return CGSizeZero;
		
		idealBufferSize = CGSizeMake(frameSize.width * nearestScale,
									 frameSize.height * nearestScale);
		nearestScale--;
	}
	while (!BXCGSizeFitsWithinSize(idealBufferSize, maxScalingBufferSize));
	
	return idealBufferSize;
}
@end