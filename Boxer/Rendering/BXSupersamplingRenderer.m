/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
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
        [self _setViewportToRegion: bufferViewport];
        
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
        
        [self _setViewportToRegion: self.viewport];
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
            if ([self.supersamplingBufferTexture canAccomodateContentSize: supersamplingSize])
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
                self.supersamplingBufferTexture = [BXTexture2D textureWithType: self.bufferTextureType
                                                                   contentSize: supersamplingSize
                                                                         bytes: NULL
                                                                   inGLContext: _context
                                                                         error: NULL];
                
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
    CGSize viewportSize     = viewport.size;
	CGSize frameSize		= NSSizeToCGSize(frame.size);
    
    CGPoint scalingFactor = [self _scalingFactorFromFrame: frame toViewport: viewport];
	
	//We disable the scaling buffer for scales over a certain limit,
	//where (we assume) stretching artifacts won't be visible.
	if (scalingFactor.y >= self.maxSupersamplingScale &&
		scalingFactor.x >= self.maxSupersamplingScale) return CGSizeZero;
	
	//If no aspect ratio correction is needed, and the viewport is an even multiple
	//of the initial resolution, then we don't need to scale either.
	if (NSEqualSizes(frame.intendedScale, NSMakeSize(1, 1)) &&
		!((NSInteger)viewportSize.width % (NSInteger)frameSize.width) && 
		!((NSInteger)viewportSize.height % (NSInteger)frameSize.height)) return CGSizeZero;
	
	//Our ideal scaling buffer size is the closest integer multiple of the
	//base resolution to the viewport size: rounding up, so that we're always
	//scaling down to maintain sharpness.
	NSInteger nearestScale = ceilf(scalingFactor.y);
	
	//Work our way down from that to find the largest scale that will still
    //fit into our maximum texture size.
	CGSize idealBufferSize;
	do
	{		
		//If we're not scaling up at all in the end, then we don't need to supersample.
		if (nearestScale <= 1) return CGSizeZero;
		
		idealBufferSize = CGSizeMake(frameSize.width * nearestScale,
									 frameSize.height * nearestScale);
		nearestScale--;
	}
	while (!BXCGSizeFitsWithinSize(idealBufferSize, _maxBufferTextureSize));
	
	return idealBufferSize;
}

@end
