/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXRenderer.h"
#import <OpenGL/CGLMacro.h>
#import <OpenGL/glu.h>
#import <OpenGL/CGLRenderers.h>
#import "BXShader.h"
#import "BXFrameBuffer.h"
#import "BXGeometry.h"

//Documented but for some reason not present in OpenGL headers
#ifndef kCGLRendererIDMatchingMask
#define kCGLRendererIDMatchingMask 0x00FE7F00
#endif

//When scaling up beyond this we won't bother with the scaling buffer
#define BXScalingBufferScaleCutoff 4.0f

@interface BXRenderer ()

@property (readwrite, retain) BXFrameBuffer *currentFrame;

//Ensure our framebuffer and scaling buffers are prepared for rendering the current frame. Called when the layer is about to be drawn.
- (void) _prepareScalingBufferForFrame: (BXFrameBuffer *)frame
                          inCGLContext: (CGLContextObj)glContext;
- (void) _prepareFrameTextureForFrame: (BXFrameBuffer *)frame
                         inCGLContext: (CGLContextObj)glContext;

//Render the specified frame into the specified GL context.
- (void) _renderFrame: (BXFrameBuffer *)frame
         inCGLContext: (CGLContextObj)glContext;

//Draw a region of the currently active GL texture to a quad made from the specified points.
- (void) _renderTexture: (GLuint)texture
             fromRegion: (CGRect)textureRegion
               toPoints: (GLfloat *)vertices
           inCGLContext: (CGLContextObj)glContext;

//Create/update an OpenGL texture with the contents of the specified framebuffer in the specified context.
- (GLuint) _createTextureForFrameBuffer: (BXFrameBuffer *)frame
                           inCGLContext: (CGLContextObj)glContext;

- (void) _fillTexture: (GLuint)texture
      withFrameBuffer: (BXFrameBuffer *)frame
         inCGLContext: (CGLContextObj)glContext;

//Create a new empty scaling buffer texture of the specified size in the specified context.
- (GLuint) _createTextureForScalingBuffer: (GLuint)buffer
                                 withSize: (CGSize)size
                             inCGLContext: (CGLContextObj)glContext;

//Calculate the appropriate scaling buffer size for the specified frame to the specified viewport dimensions.
//This will be the nearest even multiple of the frame's resolution which covers the entire viewport size.
- (CGSize) _idealScalingBufferSizeForFrame: (BXFrameBuffer *)frame
                            toViewportSize: (CGSize)viewportSize;

@end


@implementation BXRenderer
@synthesize currentFrame = _currentFrame;
@synthesize currentShader = _currentShader;
@synthesize frameRate = _frameRate;
@synthesize renderingTime = _renderingTime;
@synthesize canvas = _canvas;
@synthesize maintainsAspectRatio = _maintainsAspectRatio;

- (void) dealloc
{
    self.currentFrame = nil;
    self.currentShader = nil;
    
	[super dealloc];
}


#pragma mark -
#pragma mark Handling frame updates

- (void) updateWithFrame: (BXFrameBuffer *)frame inGLContext: (CGLContextObj)context
{
    if (frame != self.currentFrame)
	{
		//If the buffer memory locations for the two frames are different,
        //we'll need to reinitialize the texture to link to the new buffer.
        //This will be done next time we render.
		if (frame.bytes != self.currentFrame.bytes)
			_needsNewFrameTexture = YES;
		
		//If the buffers for the two frames are a different size,
        //we'll need to recreate the scaling buffer when we next render too.
		if (!NSEqualSizes(frame.size, self.currentFrame.size))
			_recalculateScalingBuffer = YES;
        
        self.currentFrame = frame;
	}
    
    //Even if the frame hasn't changed, it may contain new data:
    //flag that we're dirty and need re-rendering.
    _needsFrameTextureUpdate = YES;
    
    //TWEAK: update our frame texture immediately with the new frame, while we know
    //we have a complete frame in the buffer. (If we defer the update until it's time
    //to render to the screen, then we may do it while DOS is in the middle of writing
    //to the framebuffer: resulting in a 'torn' frame.)
    [self _prepareFrameTextureForFrame: frame inCGLContext: context];
}

- (CGSize) maxFrameSize
{
	return _maxTextureSize;
}

- (void) setCanvas: (CGRect)newCanvas
{
    if (!CGRectEqualToRect(_canvas, newCanvas))
    {
        _canvas = newCanvas;
    }
	//We need to recalculate the scaling buffer size if our canvas changes.
	_recalculateScalingBuffer = YES;
}

- (void) setMaintainsAspectRatio: (BOOL)flag
{
    if (_maintainsAspectRatio != flag)
    {
        _maintainsAspectRatio = flag;
    }
}


#pragma mark -
#pragma mark Preparing and tearing down the GL context

- (void) prepareForGLContext: (CGLContextObj)glContext
{
	CGLContextObj cgl_ctx = glContext;
    
    CGLLockContext(cgl_ctx);
	
	//Check what the largest texture size we can support is
	GLint maxTextureDims = 0;
	glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureDims);
	_maxTextureSize = CGSizeMake((CGFloat)maxTextureDims, (CGFloat)maxTextureDims);
	
	//Check for FBO support to see if we can use a scaling buffer
	_supportsFBO = (BOOL)gluCheckExtension((const GLubyte *)"GL_EXT_framebuffer_object",
                                           glGetString(GL_EXTENSIONS));
	
	if (_supportsFBO)
	{
		glGenFramebuffersEXT(1, &_scalingBuffer);
		_maxScalingBufferSize = _maxTextureSize;
	}
	
    /*
    NSError *loadError = nil;
    self.currentShader = [BXShader shaderNamed: @"Scale4xHQ" inSubdirectory: @"Shaders" error: &loadError];
    */
    
	//Disable everything we don't need
	glDisable(GL_DEPTH_TEST);
	glDisable(GL_SCISSOR_TEST);
    glDisable(GL_ALPHA_TEST);
    glDisable(GL_STENCIL_TEST);
	glDisable(GL_LIGHTING);
	glDisable(GL_CULL_FACE);
    glDisable(GL_BLEND);
    glDisable(GL_DITHER);
    glDisable(GL_FOG);
    glPixelZoom(1.0f, 1.0f);
    
    CGLUnlockContext(cgl_ctx);
}

- (void) tearDownGLContext: (CGLContextObj)glContext
{
	CGLContextObj cgl_ctx = glContext;
	
    CGLLockContext(cgl_ctx);
    
    //Clean up all the assets we were using.
	if (glIsTexture(_frameTexture))			glDeleteTextures(1, &_frameTexture);
	if (glIsTexture(_scalingBufferTexture))	glDeleteTextures(1, &_scalingBufferTexture);
	if (glIsFramebufferEXT(_scalingBuffer))	glDeleteFramebuffersEXT(1, &_scalingBuffer);
	_frameTexture			= 0;
	_scalingBufferTexture	= 0;
	_scalingBuffer			= 0;	
    
    CGLUnlockContext(cgl_ctx);
}

- (BOOL) canRenderToGLContext: (CGLContextObj)glContext
{
	return self.currentFrame != nil;
}

- (void) renderToGLContext: (CGLContextObj)glContext
{
    CGLContextObj cgl_ctx = glContext;
    
    CGLLockContext(cgl_ctx);
    
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    
    BXFrameBuffer *frame = self.currentFrame;
    
    [self _prepareFrameTextureForFrame: frame inCGLContext: cgl_ctx];
    [self _prepareScalingBufferForFrame: frame inCGLContext: cgl_ctx];
    [self _renderFrame: frame inCGLContext: cgl_ctx];
    
    CFAbsoluteTime endTime = CFAbsoluteTimeGetCurrent();
    
    self.renderingTime = endTime - startTime;
    
    if (_lastFrameTime)
    {
        CFTimeInterval timeSinceEndOfLastFrame = endTime - _lastFrameTime;
        if (timeSinceEndOfLastFrame > 0)
            self.frameRate = (CGFloat)(1.0 / timeSinceEndOfLastFrame);
    }
    
    _lastFrameTime = endTime;
    
    CGLUnlockContext(cgl_ctx);
}

- (void) flushToGLContext: (CGLContextObj)glContext
{
    CGLContextObj cgl_ctx = glContext;
    
    CGLLockContext(cgl_ctx);
    
    CGLFlushDrawable(cgl_ctx);
    
    CGLUnlockContext(cgl_ctx);
}

- (CGRect) viewportForFrame: (BXFrameBuffer *)frame
{
	if (self.maintainsAspectRatio)
	{
		NSSize frameSize = frame.scaledSize;
		NSRect frameRect = NSMakeRect(0.0f, 0.0f, frameSize.width, frameSize.height);
		NSRect bounds = NSRectFromCGRect(self.canvas);
		
		return NSRectToCGRect(fitInRect(frameRect, bounds, NSMakePoint(0.5f, 0.5f)));
	}
	else
    {
        return self.canvas;
    }
}


#pragma mark -
#pragma mark Private methods

- (void) _renderFrame: (BXFrameBuffer *)frame
         inCGLContext: (CGLContextObj)glContext
{
	CGLContextObj cgl_ctx = glContext;
	
	GLint contextFramebuffer = 0;
	if (_useScalingBuffer)
    {
        glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &contextFramebuffer);
    }
	
	//Set the viewport to match the aspect ratio of our frame
	CGRect viewportRect = CGRectIntegral([self viewportForFrame: frame]);
	
	glViewport((GLint)viewportRect.origin.x,
			   (GLint)viewportRect.origin.y,
			   (GLsizei)viewportRect.size.width,
			   (GLsizei)viewportRect.size.height);
	
    //Fill the areas outside our viewport with black
	if (!CGRectEqualToRect(viewportRect, self.canvas))
	{
		glClearColor(0, 0, 0, 1);
		glClear(GL_COLOR_BUFFER_BIT);
	}
	
	//Activate our scaling buffer, which we'll draw the frame into first
	if (_useScalingBuffer)
	{
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _scalingBuffer);
		
		//Set the viewport to match the size of the scaling buffer (rather than the viewport size)
		glViewport(0, 0, (GLsizei)_scalingBufferSize.width, (GLsizei)_scalingBufferSize.height);
	}
	
	//Draw the frame texture as a quad filling the viewport/framebuffer
	//-----------

	NSSize frameSize = self.currentFrame.size;
	CGRect frameRegion = CGRectIntegral(CGRectMake(0, 0, frameSize.width, frameSize.height));
	GLfloat frameVerts[] = {
		-1,	1,
		1,	1,
		1,	-1,
		-1,	-1
	};
	
	if (self.currentShader)
	{
		glUseProgramObjectARB(self.currentShader.shaderProgram);
		glUniform1iARB([self.currentShader locationOfUniform: "OGL2Texture"], 0);
	}
	
	[self _renderTexture: _frameTexture
			  fromRegion: frameRegion
				toPoints: frameVerts
			inCGLContext: cgl_ctx];
	
	if (self.currentShader)
    {
        glUseProgramObjectARB(NULL);
    }
	
	if (_useScalingBuffer)
	{
		//Revert the GL viewport to match the viewport again
		glViewport((GLint)viewportRect.origin.x,
				   (GLint)viewportRect.origin.y,
				   (GLsizei)viewportRect.size.width,
				   (GLsizei)viewportRect.size.height);
		
		//Revert the framebuffer to the context's original target,
		//so that drawing goes to the proper buffer from now on
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, contextFramebuffer);
		
		
		//Finally, take the scaling buffer texture and draw that into the original viewport
		//--------
		CGRect scalingRegion = CGRectMake(0, 0, _scalingBufferSize.width, _scalingBufferSize.height);
		//Note that this is flipped vertically from the coordinates we use for rendering the frame texture
		GLfloat scalingVerts[] = {
			-1,	-1,
			1,	-1,
			1,	1,
			-1,	1
		};
		
		[self _renderTexture: _scalingBufferTexture
				  fromRegion: scalingRegion
					toPoints: scalingVerts
				inCGLContext: cgl_ctx];
	}
}

- (void) _renderTexture: (GLuint)texture
             fromRegion: (CGRect)textureRegion
               toPoints: (GLfloat *)vertices
           inCGLContext: (CGLContextObj)glContext
{
	CGLContextObj cgl_ctx = glContext;
	
	GLfloat minX = CGRectGetMinX(textureRegion),
			minY = CGRectGetMinY(textureRegion),
			maxX = CGRectGetMaxX(textureRegion),
			maxY = CGRectGetMaxY(textureRegion);
	
    GLfloat texCoords[] = {
        minX,	minY,
        maxX,	minY,
        maxX,	maxY,
		minX,	maxY
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

- (void) _prepareScalingBufferForFrame: (BXFrameBuffer *)frame
                          inCGLContext: (CGLContextObj)glContext
{
	if (_scalingBuffer && _recalculateScalingBuffer)
	{
		CGLContextObj cgl_ctx = glContext;
		
        CGSize viewportSize = [self viewportForFrame: frame].size;
		CGSize newBufferSize = [self _idealScalingBufferSizeForFrame: frame
													  toViewportSize: viewportSize];
		
		//If the old scaling buffer doesn't fit the new ideal size, recreate it
		if (!CGSizeEqualToSize(_scalingBufferSize, newBufferSize))
		{
			//A zero suggested size means the scaling buffer is not necessary
			_useScalingBuffer = !CGSizeEqualToSize(newBufferSize, CGSizeZero);
			
			if (_useScalingBuffer)
			{
				//(Re)create the scaling buffer texture in the new dimensions
				if (_scalingBufferTexture) glDeleteTextures(1, &_scalingBufferTexture);
				_scalingBufferTexture = [self _createTextureForScalingBuffer: _scalingBuffer
                                                                    withSize: newBufferSize
                                                                inCGLContext: cgl_ctx];
			}
			_scalingBufferSize = newBufferSize;
		}
		_recalculateScalingBuffer = NO;
	}
}

- (void) _prepareFrameTextureForFrame: (BXFrameBuffer *)frame
                         inCGLContext: (CGLContextObj)glContext
{
	CGLContextObj cgl_ctx = glContext;
    
    CGLLockContext(cgl_ctx);
    
	if (!_frameTexture || _needsNewFrameTexture)
	{
		//Wipe out any existing frame texture we have before replacing it
		if (_frameTexture) glDeleteTextures(1, &_frameTexture);
		_frameTexture = [self _createTextureForFrameBuffer: frame inCGLContext: cgl_ctx];
		
		_needsNewFrameTexture = NO;
		_needsFrameTextureUpdate = NO;
	}
	else if (_needsFrameTextureUpdate)
	{
		[self _fillTexture: _frameTexture withFrameBuffer: frame inCGLContext: cgl_ctx];
		_needsFrameTextureUpdate = NO;
	}
    
    CGLUnlockContext(cgl_ctx);
}


#pragma mark -
#pragma mark Generating and updating OpenGL resources

- (GLuint) _createTextureForFrameBuffer: (BXFrameBuffer *)frame
                           inCGLContext: (CGLContextObj)glContext
{
	CGLContextObj cgl_ctx = glContext;
	
	GLuint texture;
	
	GLsizei texWidth	= (GLsizei)frame.size.width;
	GLsizei texHeight	= (GLsizei)frame.size.height;
	
	glEnable(GL_TEXTURE_RECTANGLE_ARB);
	
	//Create a new texture and bind it as the current target
	glGenTextures(1, &texture);
	glBindTexture(GL_TEXTURE_RECTANGLE_ARB, texture);
	
	//Clamp the texture to avoid wrapping, and set the filtering mode to use nearest-neighbour when scaling up
	glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
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
				 frame.bytes);                  //Texture data

#ifdef BOXER_DEBUG
	GLenum status = glGetError();
    if (status)
    {
        NSLog(@"[BXRenderingLayer _createTextureForFrameBuffer:inCGLContext:] Could not create texture for frame buffer of size: %@ (OpenGL error %04X)", NSStringFromSize(frame.size), status);
		glDeleteTextures(1, &texture);
		texture = 0;
	}
#endif
	
	glDisable(GL_TEXTURE_RECTANGLE_ARB);
    
	return texture;
}

- (void) _fillTexture: (GLuint)texture
      withFrameBuffer: (BXFrameBuffer *)frame
         inCGLContext: (CGLContextObj)glContext
{
	CGLContextObj cgl_ctx = glContext;
    
	glEnable(GL_TEXTURE_RECTANGLE_ARB);
	glBindTexture(GL_TEXTURE_RECTANGLE_ARB, texture);
    
    //Optimisation: only upload the changed regions to the texture.
    //TODO: profile this and see if it's quicker under some circumstances
    //to just upload the whole texture at once, e.g. if there's lots of small
    //changed regions.
    
    NSUInteger pitch = frame.pitch;
    GLsizei frameWidth = (GLsizei)frame.size.width;
    NSUInteger i, numRegions = frame.numDirtyRegions;
    
    for (i=0; i < numRegions; i++)
    {
        NSRange dirtyRegion = [frame dirtyRegionAtIndex: i];
        NSUInteger regionOffset = dirtyRegion.location * pitch;
        
        //Uggghhhh, pointer arithmetic
        const void *regionBytes = frame.bytes + regionOffset;
        
        glTexSubImage2D(GL_TEXTURE_RECTANGLE_ARB,
                     0,                     //Mipmap level
                     0,                     //X offset
                     dirtyRegion.location,	//Y offset
                     frameWidth,            //Width
                     dirtyRegion.length,	//Height
                     GL_BGRA,               //Byte ordering
                     GL_UNSIGNED_INT_8_8_8_8_REV,	//Byte packing
                     regionBytes);                  //Texture data
    }
	
#ifdef BOXER_DEBUG	
	GLenum status = glGetError();
    if (status)
    {
        NSLog(@"[BXRenderingLayer _fillTexture:withFrameBuffer:inCGLContext:] Could not update texture for frame buffer of size: %@ (OpenGL error %04X)", NSStringFromSize(frame.size), status);
	}
#endif
	
	glDisable(GL_TEXTURE_RECTANGLE_ARB);
}


- (GLuint) _createTextureForScalingBuffer: (GLuint)buffer
                                 withSize: (CGSize)size
                             inCGLContext: (CGLContextObj)glContext
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
	
#ifdef BOXER_DEBUG
	GLenum status = glGetError();
    if (status)
    {
        NSLog(@"[BXRenderingLayer _createTextureForScalingBuffer:withSize:inCGLContext:] Could not create texture for scaling buffer of size: %@ (OpenGL error %04X)", NSStringFromSize(NSSizeFromCGSize(size)), status);
		glDeleteTextures(1, &texture);
		texture = 0;
	}
#endif
	
	//Now bind it to the specified buffer
	if (texture)
	{
		GLint contextFramebuffer;
		glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &contextFramebuffer);
		
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, buffer);
		glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_RECTANGLE_ARB, texture, 0);
		
#ifdef BOXER_DEBUG
		status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
		if (status != GL_FRAMEBUFFER_COMPLETE_EXT)
		{
			NSLog(@"[BXRenderingLayer _createTextureForScalingBuffer:withSize:inCGLContext:] Could not bind to scaling buffer (OpenGL error %04X)", status);
			glDeleteTextures(1, &texture);
			texture = 0;
		}
#endif
		
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, contextFramebuffer);
	}
	
	glDisable(GL_TEXTURE_RECTANGLE_ARB);
	
	return texture;	
}

- (CGSize) _idealScalingBufferSizeForFrame: (BXFrameBuffer *)frame
                            toViewportSize: (CGSize)viewportSize
{
	CGSize frameSize		= NSSizeToCGSize(frame.size);
	CGSize scalingFactor	= CGSizeMake(viewportSize.width / frameSize.width,
										 viewportSize.height / frameSize.height);
	
	//TODO: once we get the additional rendering styles reimplemented, the optimisations below
	//should be specific to the Original style.
	
	//We disable the scaling buffer for scales over a certain limit,
	//where (we assume) stretching artifacts won't be visible.
	if (scalingFactor.height >= BXScalingBufferScaleCutoff &&
		scalingFactor.width >= BXScalingBufferScaleCutoff) return CGSizeZero;
	
	//If there's no aspect ratio correction needed, and the viewport is an even multiple
	//of the initial resolution, then we don't need to scale either.
	if (NSEqualSizes(frame.intendedScale, NSMakeSize(1, 1)) &&
		!((NSInteger)viewportSize.width % (NSInteger)frameSize.width) && 
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
	while (!BXCGSizeFitsWithinSize(idealBufferSize, _maxScalingBufferSize));
	
	return idealBufferSize;
}

@end
