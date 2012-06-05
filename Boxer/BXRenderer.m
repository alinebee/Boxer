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
#import "BXBSNESShader.h"
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


//The vertex coordinates of a viewport-covering quad in orthographic projection, unflipped and flipped
GLfloat viewportVertices[] = {
    0,	1,
    1,	1,
    1,	0,
    0,	0
};

GLfloat viewportVerticesFlipped[] = {
    0,	0,
    1,	0,
    1,	1,
    0,	1
};


@interface BXRenderer ()

//The texture into which we are drawing the DOS frames.
@property (retain) BXTexture2D *frameTexture;
//The texture into which we are drawing output for scaling.
@property (retain) BXTexture2D *scalingBufferTexture;

@property (retain) NSArray *shaderTextures;

@property (readwrite, retain) BXVideoFrame *currentFrame;

//Prepares our context, turning unnecessary rendering features off and others on.
- (void) _prepareContext;

//Ensure our framebuffer and scaling buffers are prepared for rendering the current frame.
//Called when the layer is about to be drawn.
- (void) _prepareFrameTextureForFrame: (BXVideoFrame *)frame;
- (void) _prepareScalingBufferForFrame: (BXVideoFrame *)frame;
- (void) _prepareShaderTexturesForFrame: (BXVideoFrame *)frame;


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
@synthesize shaderTextures = _shaderTextures;
@synthesize frameRate = _frameRate;
@synthesize renderingTime = _renderingTime;
@synthesize viewport = _viewport;


#pragma mark -
#pragma mark Initialization and deallocation

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
        glOrtho(0, 1,
                0, 1,
                -1, 1);
    CGLUnlockContext(cgl_ctx);
}

- (void) dealloc
{
    self.currentFrame = nil;
    
    CGLContextObj cgl_ctx = _context;
    
    CGLLockContext(cgl_ctx);
        self.shaders = nil;
        self.shaderTextures = nil;
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
#pragma mark Handling frame updates and canvas resizes

- (void) updateWithFrame: (BXVideoFrame *)frame
{
    if (frame != self.currentFrame)
    {   
        //If the current texture isn't large enough to fit the new frame,
        //we'll need to create a new one.
        if (![self.frameTexture canAccomodateVideoFrame: frame])
        {
            _needsNewFrameTexture = YES;
        }
        
        //If the two frames are a different size,
        //we may need to recreate the scaling buffer.
        if (!NSEqualSizes(frame.size, self.currentFrame.size))
        {
            _recalculateScalingBuffer = YES;
            _recalculateShaderTextures = YES;
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

- (void) setViewport: (CGRect)viewport
{
    if (!CGRectEqualToRect(_viewport, viewport))
    {
        _viewport = viewport;
        
        //We may need to recalculate the scaling buffer size if our viewport changes.
        _recalculateScalingBuffer = YES;
        _recalculateShaderTextures = YES;
    }
}

- (void) setShaders: (NSArray *)shaders
{
    if (![shaders isEqualToArray: self.shaders])
    {
        [_shaders release];
        _shaders = [shaders copy];
        
        _recalculateShaderTextures = YES;
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
        [self _prepareShaderTexturesForFrame: frame];
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
	
    //Fill the context with black before we begin
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
	
	if (_scalingBuffer && self.shaders.count)
	{
        //Retrieve the current framebuffer so we can revert to it for the final drawing stage.
        GLint contextFramebuffer = 0;
        glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &contextFramebuffer);
        
        BXTexture2D *inTexture = self.frameTexture;
        BXTexture2D *outTexture = nil;
        
        NSUInteger i, numShaders = self.shaders.count, numShaderTextures = self.shaderTextures.count;
        
        NSAssert(numShaderTextures >= (numShaders - 1), @"Insufficient shader textures to cover all shaders in list.");
        
        for (i=0; i < numShaders; i++)
        {
            BXBSNESShader *shader = [self.shaders objectAtIndex: i];
            
            //The final shader may not have an output texture of its own;
            //in which case we'll render directly to the output.
            if (numShaderTextures < i)
                outTexture = [self.shaderTextures objectAtIndex: i];
            else
                outTexture = nil;
            
            CGRect outputRect;
            GLfloat *quadCoords;
            //If we do have a texture to render into, bind that to the framebuffer now.
            if (outTexture)
            {   
                glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _scalingBuffer);
                
                [outTexture bindToFrameBuffer: _scalingBuffer
                                   attachment: GL_COLOR_ATTACHMENT0
                                        level: 0
                                        error: nil];
                
                outputRect = outTexture.contentRegion;
                quadCoords = viewportVerticesFlipped;
            }
            //Otherwise we'll render straight to the screen.
            else
            {
                glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, contextFramebuffer);
                outputRect = self.viewport;
                quadCoords = viewportVertices;
            }
            
            glUseProgramObjectARB(shader.shaderProgram);
            
            [shader setTexture: 0];
            [shader setTextureSize: inTexture.textureSize];
            [shader setInputSize: inTexture.contentRegion.size];
            [shader setOutputSize: outputRect.size];
            shader.frameCount++;
            
            //Apply the desired filtering mode to the texture we'll be rendering
            //(TODO: we could do this in advance already.)
            switch (shader.filterType)
            {
                case BXBSNESShaderFilterNearest:
                    inTexture.minFilter = inTexture.magFilter = GL_NEAREST;
                    break;
                case BXBSNESShaderFilterLinear:
                case BXBSNESShaderFilterAuto:
                default:
                    inTexture.minFilter = inTexture.magFilter = GL_LINEAR;
                    break;
            }
            
            [self _setViewportToRegion: outputRect];
            [inTexture drawOntoVertices: quadCoords error: nil];
            
            inTexture = outTexture;
        }
        
        glUseProgram(NULL);
        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, contextFramebuffer);
        
        //If we were left with a final rendered texture at the end of the process,
        //draw this to the screen now.
        if (outTexture)
        {
            [self _setViewportToRegion: self.viewport];
            [outTexture drawOntoVertices: viewportVertices error: nil];
        }
    }
    else if (_useScalingBuffer)
    {
        //Retrieve the current framebuffer so we can revert to it afterwards.
        GLint contextFramebuffer = 0;
        glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &contextFramebuffer);
        
        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _scalingBuffer);
        
        //First set the GL viewport to match the content of the scaling buffer.
        CGRect scalingBufferViewport = self.scalingBufferTexture.contentRegion;
        [self _setViewportToRegion: scalingBufferViewport];
        
        //Draw the frame into the scaling buffer.
        [self.frameTexture drawOntoVertices: viewportVertices error: NULL];
        
        //Revert the framebuffer to the context's original target,
        //so that future drawing goes to the screen (or a parent framebuffer.)
        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, contextFramebuffer);
        
        //Finally, draw the scaling buffer texture into the final viewport
        //Note that this is flipped vertically from the coordinates we use
        //for rendering the frame texture - DOCUMENT WHY THIS IS SO!
        [self _setViewportToRegion: self.viewport];
        [self.scalingBufferTexture drawOntoVertices: viewportVerticesFlipped error: NULL];
    }
    else
    {
        [self _setViewportToRegion: self.viewport];
        [self.frameTexture drawOntoVertices: viewportVertices error: NULL];
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
        //Clear our old frame texture straight away when replacing it,
        //so that the resources won't linger around.
        [self.frameTexture deleteTexture];
        
        self.frameTexture = [BXTexture2D textureWithType: GL_TEXTURE_2D
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

- (void) _prepareShaderTexturesForFrame: (BXVideoFrame *)frame
{
    if (self.shaders.count && (!self.shaderTextures || _recalculateShaderTextures))
    {
        CGLContextObj cgl_ctx = _context;
        
        CGSize inputSize = NSSizeToCGSize(frame.size);
        CGSize finalOutputSize = self.viewport.size;
        CGSize recommendedOutputSize = [self _idealScalingBufferSizeForFrame: frame toViewportSize: finalOutputSize];
        if (CGSizeEqualToSize(recommendedOutputSize, CGSizeZero))
            recommendedOutputSize = finalOutputSize;
        
        BOOL requiresFinalPass = NO;
        
        NSUInteger i, numShaders = self.shaders.count;
        NSMutableArray *shaderTextures = [NSMutableArray arrayWithCapacity: numShaders];
        
        for (i=0; i<numShaders; i++)
        {
            BOOL isFirstShader = (i == 0);
            BOOL isLastShader = (numShaders <= i + 1);
            
            BXBSNESShader *shader = [self.shaders objectAtIndex: i];
            
            //Ask the shader how big a surface it wants to render into.
            CGSize outputSize = [shader outputSizeForInputSize: inputSize
                                               finalOutputSize: finalOutputSize];
            
            //If no preferred size was given, and this is the first shader, then use our own preferred output size.
            if (isFirstShader)
            {
                if (outputSize.width == 0)
                    outputSize.width = recommendedOutputSize.width;
                
                if (outputSize.height == 0)
                    outputSize.height = recommendedOutputSize.height;
            }
            
            //If this was the last shader:
            //If a preferred size was already given, then record that we'll need to do a final-pass rendering.
            //Otherwise we'll just render straight into the framebuffer.
            if (isLastShader)
            {
                if (outputSize.width == 0)
                    outputSize.width = finalOutputSize.width;
                else if (outputSize.height != finalOutputSize.height)
                    requiresFinalPass = YES;
                
                if (outputSize.height == 0)
                    outputSize.height = finalOutputSize.height;
                else if (outputSize.height != finalOutputSize.height)
                    requiresFinalPass = YES;
            }
            
            NSLog(@"Preparing framebuffer texture with size: %@", NSStringFromCGSize(outputSize));
            if (!isLastShader || requiresFinalPass)
            {
                BXTexture2D *outputTexture = [[[BXTexture2D alloc] initWithType: GL_TEXTURE_2D
                                                                    contentSize: outputSize
                                                                          bytes: NULL
                                                                    inGLContext: cgl_ctx
                                                                          error: nil] autorelease];
                
                [shaderTextures addObject: outputTexture];
            }
            
            inputSize = outputSize;
        }
        
        //Wipe out all the previous textures before we replace them.
        [self.shaderTextures makeObjectsPerformSelector: @selector(deleteTexture)];
        self.shaderTextures = shaderTextures;
        
        _recalculateShaderTextures = NO;
    }
}

- (void) _prepareScalingBufferForFrame: (BXVideoFrame *)frame
{
    if (_scalingBuffer && _recalculateScalingBuffer)
    {	
        CGSize viewportSize = self.viewport.size;
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
                self.scalingBufferTexture = [BXTexture2D textureWithType: GL_TEXTURE_2D
                                                             contentSize: newBufferSize
                                                                   bytes: NULL
                                                             inGLContext: _context
                                                                   error: NULL];
                
                //Now try binding the texture to our scaling buffer.
                BOOL bindSucceeded = [self.scalingBufferTexture bindToFrameBuffer: _scalingBuffer
                                                                       attachment: GL_COLOR_ATTACHMENT0_EXT
                                                                            level: 0
                                                                            error: NULL];
                
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
