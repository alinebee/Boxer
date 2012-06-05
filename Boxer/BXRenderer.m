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
#import "BXVideoFrame.h"
#import "BXTexture2D+BXVideoFrameExtensions.h"
#import "BXGeometry.h"


#pragma mark -
#pragma mark Constants


//Documented but for some reason not present in OpenGL headers
#ifndef kCGLRendererIDMatchingMask
#define kCGLRendererIDMatchingMask 0x00FE7F00
#endif

//When scaling up beyond this we won't bother with the scaling buffer
#define BXScalingBufferScaleCutoff 4.0f


//The vertex coordinates of the viewport in the screen projection matrix, unflipped and flipped
GLfloat viewportVertices[] = {
    -1,	1,
    1,	1,
    1,	-1,
    -1,	-1
};

GLfloat viewportVerticesFlipped[] = {
    -1,	-1,
    1,	-1,
    1,	1,
    -1,	1
};


@interface BXRenderer ()

//The texture into which we are drawing the DOS frames.
@property (retain) BXTexture2D *frameTexture;
//The texture into which we are drawing output for scaling.
@property (retain) BXTexture2D *scalingBufferTexture;

@property (readwrite, retain) BXVideoFrame *currentFrame;

//Prepares our context, turning unnecessary rendering features off and others on.
- (void) _prepareContext;

//Ensure our framebuffer and scaling buffers are prepared for rendering the current frame.
//Called when the layer is about to be drawn.
- (void) _prepareScalingBufferForFrame: (BXVideoFrame *)frame;

- (void) _prepareFrameTextureForFrame: (BXVideoFrame *)frame;

//Render the specified frame into the specified GL context.
- (void) _renderFrame: (BXVideoFrame *)frame;

//Updates the GL viewport to the specified region in screen pixels.
- (void) _setViewportToRegion: (CGRect)viewportRegion;

//Calculate the appropriate scaling buffer size for the specified frame to the specified viewport dimensions.
//This will be the nearest even multiple of the frame's resolution which covers the entire viewport size.
- (CGSize) _idealScalingBufferSizeForFrame: (BXVideoFrame *)frame
                            toViewportSize: (CGSize)viewportSize;

@end


@implementation BXRenderer
@synthesize context = _context;
@synthesize currentFrame = _currentFrame;
@synthesize frameTexture = _frameTexture;
@synthesize scalingBufferTexture = _scalingBufferTexture;
@synthesize shaders = _shaders;
@synthesize frameRate = _frameRate;
@synthesize renderingTime = _renderingTime;
@synthesize canvas = _canvas;
@synthesize maintainsAspectRatio = _maintainsAspectRatio;

- (void) dealloc
{
    CGLContextObj cgl_ctx = _context;
    
    CGLLockContext(cgl_ctx);
        self.currentFrame = nil;
        self.shaders = nil;
        self.frameTexture = nil;
        self.scalingBufferTexture = nil;
        
        if (glIsFramebufferEXT(_scalingBuffer))
            glDeleteFramebuffersEXT(1, &_scalingBuffer);
        _scalingBuffer = 0;
    CGLUnlockContext(cgl_ctx);
    
    CGLReleaseContext(_context);
    
	[super dealloc];
}


#pragma mark -
#pragma mark Initialization and deallocation
#pragma mark -
#pragma mark Preparing and tearing down the GL context

- (id) initWithGLContext: (CGLContextObj)glContext
{
    if ((self = [super init]))
    {
        CGLContextObj cgl_ctx = glContext;
        
        _context = cgl_ctx;
        CGLRetainContext(_context);
        
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
        
        [self _prepareContext];
    }
    return self;
}

- (void) _prepareContext
{
    CGLContextObj cgl_ctx = _context;
    
    CGLLockContext(cgl_ctx);
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


#pragma mark -
#pragma mark Handling frame updates and canvas resizes

- (void) updateWithFrame: (BXVideoFrame *)frame
{
    if (frame != self.currentFrame)
    {   
        //If the current buffer can't accommodate the new frame,
        //we'll need to create a new one.
        if (![self.frameTexture canAccomodateVideoFrame: frame])
        {
            _needsNewFrameTexture = YES;
        }
        
        //If the buffers for the two frames are a different size,
        //we may need to recreate the scaling buffer.
        if (!NSEqualSizes(frame.size, self.currentFrame.size))
        {
            _recalculateScalingBuffer = YES;
        }
        
        self.currentFrame = frame;
    }
    
    //Even if the frame hasn't changed, it may contain new data:
    //flag that we're dirty and need re-rendering.
    _needsFrameTextureUpdate = YES;
    
    //TWEAK: update our frame texture immediately with the new frame, while we know
    //we have a complete frame in the buffer. (If we defer the update until it's time
    //to render to the screen, then we may do it while DOS is in the middle of writing
    //to the framebuffer: resulting in a 'torn' frame.)
    
    CGLLockContext(_context);
        [self _prepareFrameTextureForFrame: frame];
    CGLUnlockContext(_context);
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
        
        //We need to recalculate the scaling buffer size if our canvas changes.
        _recalculateScalingBuffer = YES;
    }
}

- (void) setMaintainsAspectRatio: (BOOL)flag
{
    if (_maintainsAspectRatio != flag)
    {
        _maintainsAspectRatio = flag;
        
        //We need to recalculate the scaling buffer size if our aspect ratio changes.
        _recalculateScalingBuffer = YES;
    }
}

- (CGRect) viewportForFrame: (BXVideoFrame *)frame
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
#pragma mark Rendering

- (BOOL) canRender
{
	return self.frameTexture != nil;
}

- (void) render
{
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    
    BXVideoFrame *frame = self.currentFrame;
    
    CGLLockContext(_context);
        [self _prepareFrameTextureForFrame: frame];
        [self _prepareScalingBufferForFrame: frame];
        [self _renderFrame: frame];
    CGLUnlockContext(_context);
    
    CFAbsoluteTime endTime = CFAbsoluteTimeGetCurrent();
    
    //After rendering, calculate how long this frame took us to render (to determine rendering speed),
    //and how long it's been since we completed the last frame (to determine overall frame rate).
    self.renderingTime = endTime - startTime;
    
    if (_lastFrameTime)
    {
        CFTimeInterval timeSinceEndOfLastFrame = endTime - _lastFrameTime;
        if (timeSinceEndOfLastFrame > 0)
            self.frameRate = (CGFloat)(1.0 / timeSinceEndOfLastFrame);
    }
    
    _lastFrameTime = endTime;
}

- (void) flush
{   
    CGLLockContext(_context);
        CGLFlushDrawable(_context);
    CGLUnlockContext(_context);
}


- (void) _renderFrame: (BXVideoFrame *)frame
{
    CGLContextObj cgl_ctx = _context;
	
	GLint contextFramebuffer = 0;
	if (_useScalingBuffer)
    {
        glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &contextFramebuffer);
    }
	
	//Calculate the appropriate viewport to display this frame given its intended aspect ratio.
	CGRect viewportRect = [self viewportForFrame: frame];
    [self _setViewportToRegion: viewportRect];
	
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
		
		//Set the GL viewport to match the extents of the scaling buffer, rather than the viewport.
        CGRect scalingBufferViewport = self.scalingBufferTexture.contentRegion;
        [self _setViewportToRegion: scalingBufferViewport];
	}
	
	//Draw the frame texture as a quad filling the viewport/framebuffer
	//-----------
	
	if (self.shaders.count)
	{
        BXShader *currentShader = [self.shaders objectAtIndex: 0];
		glUseProgramObjectARB(currentShader.shaderProgram);
		glUniform1iARB([currentShader locationOfUniform: "OGL2Texture"], 0);
	}
	
    [self.frameTexture drawOntoVertices: viewportVertices error: NULL];
	
	if (self.shaders)
    {
        glUseProgramObjectARB(NULL);
    }
	
	if (_useScalingBuffer)
	{
		//Revert the framebuffer to the context's original target,
		//so that future drawing goes to the screen (or a parent framebuffer)
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, contextFramebuffer);
        
		//Revert the GL viewport to match the real viewport again.
        [self _setViewportToRegion: viewportRect];
		
		//Finally, draw the scaling buffer texture into the original viewport
        //Note that this is flipped vertically from the coordinates we use
        //for rendering the frame texture (DOCUMENT WHY THIS IS SO!)
        [self.scalingBufferTexture drawOntoVertices: viewportVerticesFlipped error: NULL];
	}
}

- (void) _setViewportToRegion: (CGRect)viewport 
{
    CGLContextObj cgl_ctx = _context;
    
    viewport = CGRectIntegral(viewport);
	glViewport((GLint)viewport.origin.x,
			   (GLint)viewport.origin.y,
			   (GLsizei)viewport.size.width,
			   (GLsizei)viewport.size.height);
}


#pragma mark -
#pragma mark Preparing resources for drawing

- (void) _prepareFrameTextureForFrame: (BXVideoFrame *)frame
{
    if (!self.frameTexture || _needsNewFrameTexture)
    {
        NSError *textureError = nil;
        //Clear our old frame texture straight away when replacing it
        [self.frameTexture deleteTexture];
        
        self.frameTexture = [BXTexture2D textureWithType: GL_TEXTURE_RECTANGLE_ARB
                                              videoFrame: frame
                                             inGLContext: _context
                                                   error: &textureError];
        
        NSAssert(self.frameTexture != nil, @"Fuck, texture creation failed: %@", textureError);
        
        self.frameTexture.minFilter = GL_LINEAR;
        self.frameTexture.magFilter = GL_NEAREST;
        
        _needsNewFrameTexture = NO;
        _needsFrameTextureUpdate = NO;
    }
    else if (_needsFrameTextureUpdate)
    {
        [self.frameTexture fillWithVideoFrame: frame error: NULL];
        _needsFrameTextureUpdate = NO;
    }
}

- (void) _prepareScalingBufferForFrame: (BXVideoFrame *)frame
{
    if (_scalingBuffer && _recalculateScalingBuffer)
    {	
        CGSize viewportSize = [self viewportForFrame: frame].size;
        CGSize oldBufferSize = self.scalingBufferTexture.contentRegion.size;
        CGSize newBufferSize = [self _idealScalingBufferSizeForFrame: frame
                                                      toViewportSize: viewportSize];
        
        //If the old scaling buffer doesn't fit the new ideal size, recreate it
        if (!CGSizeEqualToSize(oldBufferSize, newBufferSize))
        {
            //A zero suggested size means the scaling buffer is not necessary
            _useScalingBuffer = !CGSizeEqualToSize(newBufferSize, CGSizeZero);
            
            if (_useScalingBuffer)
            {
                //Clear our old scaling buffer texture straight away when replacing it
                [self.scalingBufferTexture deleteTexture];
                
                //(Re)create the scaling buffer texture in the new dimensions
                self.scalingBufferTexture = [BXTexture2D textureWithType: GL_TEXTURE_RECTANGLE_ARB
                                                             contentSize: newBufferSize
                                                                   bytes: NULL
                                                             inGLContext: _context
                                                                   error: NULL];
                
                //Now try binding the texture to our scaling buffer.
                BOOL bindSucceeded = [self.scalingBufferTexture bindToFrameBuffer: _scalingBuffer
                                                                       attachment: GL_COLOR_ATTACHMENT0_EXT
                                                                            level: 0
                                                                            error: nil];
                
                //If binding failed, then ditch the texture after all.
                if (!bindSucceeded)
                {
                    self.scalingBufferTexture = nil;
                    _useScalingBuffer = NO;
                }
            }
        }
        _recalculateScalingBuffer = NO;
    }
}

- (CGSize) _idealScalingBufferSizeForFrame: (BXVideoFrame *)frame
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
