/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXBasicRendererPrivate.h"

@implementation BXSupersamplingRenderer
@synthesize maxSupersamplingScale = _maxSupersamplingScale;
@synthesize supersamplingBufferTexture = _supersamplingBufferTexture;

- (id) initWithContext: (CGLContextObj)glContext
                 error: (NSError **)outError
{
    //First check for FBO support to see if we can use the scaling buffer
    BOOL framebuffersSupported = [self.class context: glContext
                                   supportsExtension: "GL_EXT_framebuffer_object"];

    if (framebuffersSupported)
    {
        return [super initWithContext: glContext error: outError];
    }
    
    //Without framebuffer support we cannot function, so bail out
    else
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain: BXRendererErrorDomain
                                            code: BXRendererUnsupported
                                        userInfo: nil];
        }
        
        [self dealloc];
        self = nil;
    }
    
    return self;
}

- (id) init
{
    self = [super init];
    if (self)
    {
        self.maxSupersamplingScale = BXDefaultMaxSupersamplingScale;
        _shouldRecalculateBuffer = YES;
    }
    return self;
}

- (void) prepareContext
{
    [super prepareContext];
    
    CGLContextObj cgl_ctx = _context;
    
    //Generate a framebuffer in this context
    glGenFramebuffersEXT(1, &_supersamplingBuffer);
    _maxBufferTextureSize = [self.class maxTextureSizeForType: self.bufferTextureType
                                                    inContext: _context];
}

- (void) tearDownContext
{
    [super tearDownContext];
    
    CGLContextObj cgl_ctx = _context;
    
    if (glIsFramebufferEXT(_supersamplingBuffer))
        glDeleteFramebuffersEXT(1, &_supersamplingBuffer);
    _supersamplingBuffer = 0;

    [self.supersamplingBufferTexture deleteTexture];
    self.supersamplingBufferTexture = nil;
}



#pragma mark -
#pragma mark Handling frame updates and canvas resizes

//Whenever a new frame comes in, check if the size has changed and if so,
//recalculate how big our supersampling buffer should be.
- (void) updateWithFrame: (BXVideoFrame *)frame
{
    //If the frame has changed size, we may need to recalculate
    //the supersampling buffer
    if (frame != self.currentFrame && !NSEqualSizes(frame.size, self.currentFrame.size))
    {
        _shouldRecalculateBuffer = YES;
    }
    
    [super updateWithFrame: frame];
}

- (void) recalculateViewport
{
    _shouldRecalculateBuffer = YES;
}

//TWEAK: always recalculate the supersampling buffer size whenever the viewport changes,
//because it's cheap and ensures high-quality scaling.
- (BOOL) alwaysRecalculatesAfterViewportChange
{
    return YES;
}


#pragma mark -
#pragma mark Rendering


- (GLenum) bufferTextureType
{
    return GL_TEXTURE_RECTANGLE_ARB;
}

- (void) _prepareForRenderingFrame: (BXVideoFrame *)frame
{
    [super _prepareForRenderingFrame: frame];
    [self _prepareSupersamplingBufferForFrame: frame];
}

- (BOOL) _shouldRenderWithSupersampling
{
    return _shouldUseSupersampling;
}

- (void) _renderFrame: (BXVideoFrame *)frame
{
    if ([self _shouldRenderWithSupersampling])
    {
        BXTexture2D *destinationTexture = self.supersamplingBufferTexture;
        
        CGLContextObj cgl_ctx = _context;
        
        //Retrieve the current framebuffer so we can revert to it afterwards.
        GLuint originalBuffer = 0;
        glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, (GLint *)&originalBuffer);
        
        //Bind our own framebuffer and texture.
        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _supersamplingBuffer);
        [self _bindTextureToSupersamplingBuffer: destinationTexture];
        
        //Set the GL viewport to match the content region of the buffer texture.
        CGRect bufferViewport = destinationTexture.contentRegion;
        [self _setGLViewportToRegion: bufferViewport];
        
        //Draw the frame into the buffer texture.
        [self.frameTexture drawOntoVertices: viewportVerticesFlipped error: NULL];
        
        //Revert the framebuffer to the context's original target,
        //so that future drawing goes to the screen (or a parent framebuffer.)
        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, originalBuffer);
        
        //Finally, draw the scaling buffer texture into the final viewport
        //Note that this is flipped vertically from the coordinates we use
        //for rendering the frame texture - DOCUMENT WHY THIS IS SO!
        
        if (self.delegate)
            [self.delegate renderer: self willRenderTextureToDestinationContext: destinationTexture];
        
        [self _setGLViewportToRegion: self.viewport];
        [destinationTexture drawOntoVertices: viewportVertices
                                       error: NULL];
        
        if (self.delegate)
            [self.delegate renderer: self didRenderTextureToDestinationContext: destinationTexture];
    }
    //Fall back on the standard rendering path if we don't need supersampling
    else
    {
        [super _renderFrame: frame];
    }
}

- (void) _bindTextureToSupersamplingBuffer: (BXTexture2D *)bufferTexture
{
    //Keep track of what texture is currently bound so we don't bind redundantly.
    if (_currentBufferTexture != bufferTexture.texture)
    {
        CGLContextObj cgl_ctx = _context;
        glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT,
                                  GL_COLOR_ATTACHMENT0,
                                  bufferTexture.type,
                                  bufferTexture.texture,
                                  0);
        
        _currentBufferTexture = bufferTexture.texture;
    }
}

- (void) _prepareSupersamplingBufferForFrame: (BXVideoFrame *)frame
{
    if (_shouldRecalculateBuffer)
    {	
        CGSize supersamplingSize = [self _idealSupersamplingBufferSizeForFrame: frame
                                                                    toViewport: self.viewport];
        
        //A zero ideal size means the supersampling buffer is not necessary.
        _shouldUseSupersampling = !CGSizeEqualToSize(supersamplingSize, CGSizeZero);
        
        if (_shouldUseSupersampling)
        {
            //Reuse the existing buffer if it's already large enough, simply ensuring
            //that it uses the new supersampling size.
            if ([self.supersamplingBufferTexture canAccommodateContentSize: supersamplingSize])
            {
                self.supersamplingBufferTexture.contentRegion = CGRectMake(0, 0,
                                                                           supersamplingSize.width,
                                                                           supersamplingSize.height);
            }
            //Otherwise, recreate the buffer texture if it can't accomodate the new size.
            else
            {   
                //Clear our old buffer texture straight away when replacing it
                if (_currentBufferTexture == self.supersamplingBufferTexture.texture)
                    _currentBufferTexture = 0;
                
                [self.supersamplingBufferTexture deleteTexture];
                
                //(Re)create the buffer texture in the new dimensions
                NSError *bufferError = nil;
                self.supersamplingBufferTexture = [BXTexture2D textureWithType: self.bufferTextureType
                                                                   contentSize: supersamplingSize
                                                                         bytes: NULL
                                                                   inGLContext: _context
                                                                         error: &bufferError];
                
                NSAssert1(self.supersamplingBufferTexture != nil, @"Buffer texture creation failed: %@", bufferError);
                
                [self.supersamplingBufferTexture setMinFilter: GL_LINEAR
                                                    magFilter: GL_LINEAR
                                                     wrapping: GL_CLAMP_TO_EDGE];
            }
        }
        
        _shouldRecalculateBuffer = NO;
    }
}

- (CGSize) _idealSupersamplingBufferSizeForFrame: (BXVideoFrame *)frame
                                      toViewport: (CGRect)viewport
{
    CGPoint scalingFactor = [self _scalingFactorFromFrame: frame toViewport: viewport];
	
	//Disable supersampling for scales over a certain limit,
	//where we assume stretching artifacts won't be visible.
	if (scalingFactor.y >= self.maxSupersamplingScale &&
		scalingFactor.x >= self.maxSupersamplingScale) return CGSizeZero;
	
	//If no aspect ratio correction is being applied, and the viewport is an even multiple
	//of the initial resolution, then we don't need to supersample either: the base pixels
    //will scale cleanly up to the final viewport without stretching.
    BOOL usesSquarePixels = (frame.intendedScale.width == 1 && frame.intendedScale.height == 1);
    BOOL isEvenScaling = CGPointEqualToPoint(scalingFactor, CGPointIntegral(scalingFactor));
	if (usesSquarePixels && isEvenScaling) return CGSizeZero;
	
	//Our ideal supersampling buffer size is the smallest integer multiple
    //of the base resolution that fully covers the viewport. This is then scaled
    //down to the final viewport.
	NSInteger nearestScale = ceilf(scalingFactor.y);
	CGSize frameSize = NSSizeToCGSize(frame.size);
	CGSize idealBufferSize = CGSizeMake(frameSize.width * nearestScale,
                                        frameSize.height * nearestScale);
    
	//If the ideal buffer size is larger than our texture size, work our way down
    //from that to find the largest even multiple that we can support.
	while (!BXCGSizeFitsWithinSize(idealBufferSize, _maxBufferTextureSize))
	{
		idealBufferSize.width -= frameSize.width;
        idealBufferSize.height -= frameSize.height;
	}
    
    //If we're not scaling up at all in the end, then we don't need to supersample.
    if (CGSizeEqualToSize(idealBufferSize, frameSize))
        return CGSizeZero;
	
	return idealBufferSize;
}

@end
