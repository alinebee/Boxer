/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXBasicRendererPrivate.h"
#import "ADBBSNESShader.h"

@implementation BXShaderRenderer
@synthesize auxiliaryBufferTexture = _auxiliaryBufferTexture;
@synthesize shaders = _shaders;
@synthesize usesShaderSupersampling = _usesShaderSupersampling;

#pragma mark -
#pragma mark Initialization and deallocation

- (id) initWithShaderSet: (NSArray *)shaders
             inContext: (CGLContextObj)glContext
                 error: (NSError **)outError
{
    self = [super initWithContext: glContext error: outError];
    if (self)
    {
        self.shaders = shaders;
    }
    return self;
}

- (id) initWithContentsOfURL: (NSURL *)shaderURL
                   inContext: (CGLContextObj)glContext
                       error: (NSError **)outError
{
    NSArray *shaders = [ADBBSNESShader shadersWithContentsOfURL: shaderURL
                                                     inContext: glContext
                                                         error: outError];
    if (shaders)
    {
        self = [self initWithShaderSet: shaders inContext: glContext error: outError];
    }
    else
    {
        return nil;
    }
    return self;
}

- (id) init
{
    self = [super init];
    if (self)
    {
        _shouldUseShaders = YES;
        _usesShaderSupersampling = YES;
    }
    return self;
}

- (void) tearDownContext
{
    [super tearDownContext];
    
    [self.auxiliaryBufferTexture deleteTexture];
    self.auxiliaryBufferTexture = nil;
    
    [self.shaders makeObjectsPerformSelector: @selector(deleteShaderProgram)];
    self.shaders = nil;
}


#pragma mark -
#pragma mark Rendering

//BSNES-style shaders require 2D textures.
- (GLenum) frameTextureType
{
    return GL_TEXTURE_2D;
}

- (GLenum) bufferTextureType
{
    return GL_TEXTURE_2D;
}

//IMPLEMENTATION NOTE: our precalculations in _prepareSupersamplingBufferForFrame make it unsafe
//to render to arbitrary viewports without recalculating, because _renderFrame: makes assumptions
//about whether it needs to render into a buffer or not based on those precalculations.
//If they're incorrect, we may try to render into a buffer that doesn't exist or is the wrong size.
- (BOOL) alwaysRecalculatesAfterViewportChange
{
    return YES;
}

- (BOOL) _shouldRenderWithShaders
{
    return _shouldUseShaders;
}

- (void) _renderFrame: (BXVideoFrame *)frame
{
    if ([self _shouldRenderWithShaders])
    {
        CGLContextObj cgl_ctx = _context;
        
        //Retrieve the current framebuffer so we can revert to it for the final drawing stage.
        GLint originalBuffer = 0;
        glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &originalBuffer);
        
        ADBTexture2D *inTexture = self.frameTexture;
        ADBTexture2D *outTexture = nil;
        
        NSUInteger i, numShaders = self.shaders.count;
        for (i=0; i < numShaders; i++)
        {
            ADBBSNESShader *shader = [self.shaders objectAtIndex: i];
            
            BOOL isLastShader = (i == numShaders - 1);
            
            //Retrieve the output size that we calculated earlier for this shader.
            CGSize outputSize = _shaderOutputSizes[i];
            CGRect outputRect;
            GLfloat *quadCoords;
            
            //All shaders but the final one need to draw into a framebuffer.
            //If the last shader can't render straight to the viewport,
            //it'll need a buffer too.
            BOOL shaderNeedsBuffer = !(isLastShader && CGSizeEqualToSize(outputSize, self.viewport.size));
            
            //If this shader needs to render into a buffer, grab the next available
            //buffer texture and bind it to the framebuffer.
            if (shaderNeedsBuffer)
            {
                //We can't render a texture back into itself, so ping-pong back and forth
                //between our main and auxiliary buffers.
                if (inTexture == self.supersamplingBufferTexture)
                    outTexture = self.auxiliaryBufferTexture;
                else
                    outTexture = self.supersamplingBufferTexture;
                    
                glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _supersamplingBuffer);
                
                //Resize the buffer's content region to match the intended output size.
                outTexture.contentRegion = CGRectMake(0, 0, outputSize.width, outputSize.height);
                
                //Bind the texture to the framebuffer if it isn't already.
                [self _bindTextureToSupersamplingBuffer: outTexture];
                
                outputRect = outTexture.contentRegion;
                quadCoords = viewportVerticesFlipped;
            }
            //Otherwise we'll render this shader straight to the screen.
            else
            {
                glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, originalBuffer);
                
                outTexture = nil;
                outputRect = self.viewport;
                quadCoords = viewportVertices;
            }
            
            //Sync the texture's filtering parameters to match what this shader expects.
            //Note that we switch to GL_REPEAT also, as certain distorting shaders will
            //otherwise stretch clamped edge pixels into the view in an ugly way.
            switch (shader.filterType)
            {
                case ADBBSNESShaderFilterNearest:
                    [inTexture setMinFilter: GL_NEAREST
                                  magFilter: GL_NEAREST
                                   wrapping: GL_REPEAT];
                    break;
                case ADBBSNESShaderFilterLinear:
                case ADBBSNESShaderFilterAuto:
                default:
                    [inTexture setMinFilter: GL_NEAREST
                                  magFilter: GL_LINEAR
                                   wrapping: GL_REPEAT];
                    break;
            }
            
            //Activate the shader program and assign the uniform variables appropriately.
            glUseProgramObjectARB(shader.shaderProgram);
            
            //TODO: all of these could be set once in advance when we're preparing the buffers.
            shader.textureIndex = 0;
            shader.textureSize = inTexture.textureSize;
            shader.inputSize = inTexture.contentRegion.size;
            shader.outputSize = outputRect.size;
            shader.frameCount++;
            
            if (!shaderNeedsBuffer && self.delegate)
                [self.delegate renderer: self willRenderTextureToDestinationContext: inTexture];
            
            //Resize the viewport and draw!
            [self _setGLViewportToRegion: outputRect];
            [inTexture drawOntoVertices: quadCoords error: nil];
            
            if (!shaderNeedsBuffer && self.delegate)
                [self.delegate renderer: self didRenderTextureToDestinationContext: inTexture];
                
            //Use the output from this shader as the input for the next shader (if any.)
            inTexture = outTexture;
        }
        
        glUseProgramObjectARB(NULL);
        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, originalBuffer);
        
        //If we were left with a final rendered buffer texture at the end of the process,
        //draw this to the screen now.
        if (outTexture)
        {
            if (self.delegate)
                [self.delegate renderer: self willRenderTextureToDestinationContext: outTexture];
            
            [self _setGLViewportToRegion: self.viewport];
            [outTexture drawOntoVertices: viewportVertices error: nil];
            
            if (self.delegate)
                [self.delegate renderer: self didRenderTextureToDestinationContext: outTexture];
        }
    }
    //Fall back on the parent rendering path if shaders should not be used.
    else
    {
        [super _renderFrame: frame];
    }
}

- (CGSize) _idealShaderRenderingSizeForFrame: (BXVideoFrame *)frame toViewport: (CGRect)viewport
{
    //If shader supersampling is enabled, then for non-integer sizes we try to render the shader
    //to a larger size than the viewport and scale it back down. This works better for shaders
    //that target specific output sizes, and gives us nice antialiasing on non-integer scales.
    if (self.usesShaderSupersampling)
    {
        CGSize frameSize = NSSizeToCGSize(frame.size);
        CGPoint scalingFactor = [self _scalingFactorFromFrame: frame toViewport: viewport];
        
        //Our ideal shader target size is the closest integer multiple of the
        //base resolution to the viewport size: rounding up, so that we're always
        //scaling down to maintain sharpness.
        NSInteger nearestScale = ceilf(scalingFactor.y);
        
        //Work our way down from that to find the largest scale that will still
        //fit into our maximum texture size.
        CGSize preferredSupersamplingSize;
        do
        {
            preferredSupersamplingSize = CGSizeMake(frameSize.width * nearestScale,
                                                    frameSize.height * nearestScale);
            nearestScale--;
        }
        while (nearestScale > 0 && !CGSizeFitsWithinSize(preferredSupersamplingSize, _maxBufferTextureSize));
        
        return preferredSupersamplingSize;
    }
    //If shader supersampling is disabled, then we can assume the shader should render
    //directly to the viewport.
    else
    {
        return viewport.size;
    }
}

- (void) _prepareSupersamplingBufferForFrame: (BXVideoFrame *)frame
{
    //This is a reimplementation of BXSupersamplingBuffer's method which
    //calculates the largest buffer size needed by our shader stack, and
    //whether we will need multiple buffers.
    
    //This method also takes the opportunity to precalculate details about the
    //shader stack to save time when rendering, even though the details may be
    //nothing to do with the buffers themeselves.
    
    if (_shouldRecalculateBuffer)
    {   
        NSUInteger i, numShaders = self.shaders.count;
        if (numShaders)
        {
            CGSize inputSize = NSSizeToCGSize(frame.size);
            CGSize preferredOutputSize = [self _idealShaderRenderingSizeForFrame: frame toViewport: self.viewport];
            
            CGSize largestOutputSize = preferredOutputSize;
            NSUInteger numShadersNeedingBuffers = 0;
            
            //Scan our shaders to figure out how big an output surface they will render
            //and whether they will need to draw into an intermediate sample buffer
            //rather than direct to the screen.
            
            _shouldUseShaders = YES;
            for (i=0; i<numShaders; i++)
            {
                ADBBSNESShader *shader = [self.shaders objectAtIndex: i];
                
                BOOL isFirstShader  = (i == 0);
                BOOL isLastShader   = (i == numShaders - 1);
                
                //All but the last shader are guaranteed to need to draw into a frame buffer.
                BOOL shaderNeedsBuffer = !isLastShader;
                
                //Ask the shader how big a surface it wants to render into given the current input size.
                CGSize outputSize = [shader outputSizeForInputSize: inputSize
                                                   finalOutputSize: self.viewport.size];
                
                //If no preferred size was given, and this is the first shader,
                //then use our own preferred upscaling output size.
                if (isFirstShader)
                {
                    if (outputSize.width == 0)
                        outputSize.width = preferredOutputSize.width;
                    
                    if (outputSize.height == 0)
                        outputSize.height = preferredOutputSize.height;
                }
                
                //If this is the last shader and no output size has been specified in the
                //shader definition, then render it directly to the viewport.
                //If this is the last shader and its output size is defined to be different
                //from our viewport size, then we'll need to render it to an intermediate
                //framebuffer instead (which then gets rendered to the final viewport.)
                if (isLastShader)
                {
                    if (outputSize.width == 0)
                        outputSize.width = self.viewport.size.width;
                    else if (outputSize.width != self.viewport.size.width)
                        shaderNeedsBuffer = YES;
                    
                    if (outputSize.height == 0)
                        outputSize.height = self.viewport.size.height;
                    else if (outputSize.height != self.viewport.size.height)
                        shaderNeedsBuffer = YES;
                }
                
                //Track the largest overall output size across all shaders.
                //This will indicate the size of buffer texture(s) we need.
                largestOutputSize = CGSizeMake(MAX(largestOutputSize.width, outputSize.width),
                                               MAX(largestOutputSize.height, outputSize.height));
                
                if (shaderNeedsBuffer)
                    numShadersNeedingBuffers++;
                
                //Store the precalculated output size to use further on in our render path.
                _shaderOutputSizes[i] = outputSize;
                
                //We'll be using the output texture from this texture as the input texture
                //for the next shader in the list.
                inputSize = outputSize;
            }
            
            //Bounds-check the overall size we need for the buffer, to ensure that it still
            //fits within our maximum texture size.
            //TODO: finesse this so that it will try to choose a suitable size based on the
            //shader context.
            largestOutputSize.width     = MIN(largestOutputSize.width, _maxBufferTextureSize.width);
            largestOutputSize.height    = MIN(largestOutputSize.height, _maxBufferTextureSize.height);
        
            //At this stage, we now know:
            //1. How many of our shaders need to draw to an intermediate scaling buffer, and
            //2. The largest output size we will need to accomodate in our scaling buffer.
            
            //From this we can decide how many buffer textures we'll need and what size
            //to make them. We'll use up to two buffers of identical size and swap them
            //back and forth as we render our shaders into them.
            
            //Recreate the main buffer texture, if we don't have one yet or if our old one
            //cannot accomodate the output size.
            if (numShadersNeedingBuffers > 0)
            {
                if (![self.supersamplingBufferTexture canAccommodateContentSize: largestOutputSize])
                {
                    if (_currentBufferTexture == self.supersamplingBufferTexture.texture)
                        _currentBufferTexture = 0;
                    
                    //Clear our old buffer texture straight away when replacing it
                    [self.supersamplingBufferTexture deleteTexture];
                    
                    //(Re)create the buffer texture in the new dimensions
                    NSError *bufferError = nil;
                    self.supersamplingBufferTexture = [ADBTexture2D textureWithType: self.bufferTextureType
                                                                       contentSize: largestOutputSize
                                                                             bytes: NULL
                                                                       inGLContext: _context
                                                                             error: &bufferError];
                    
                    NSAssert1(self.supersamplingBufferTexture != nil, @"Buffer texture creation failed: %@", bufferError);
                }
            }
            
            //(Re)create a second auxiliary buffer if we'll need to swap back and forth
            //to handle multiple shaders.
            if (numShadersNeedingBuffers > 1)
            {
                if (![self.auxiliaryBufferTexture canAccommodateContentSize: largestOutputSize])
                {   
                    if (_currentBufferTexture == self.auxiliaryBufferTexture.texture)
                        _currentBufferTexture = 0;
                    
                    //Clear our old buffer texture straight away when replacing it
                    [self.auxiliaryBufferTexture deleteTexture];
                    
                    //(Re)create the buffer texture in the new dimensions
                    NSError *bufferError = nil;
                    self.auxiliaryBufferTexture = [ADBTexture2D textureWithType: self.bufferTextureType
                                                                   contentSize: largestOutputSize
                                                                         bytes: NULL
                                                                   inGLContext: _context
                                                                         error: &bufferError];
                    
                    NSAssert1(self.auxiliaryBufferTexture != nil, @"Buffer texture creation failed: %@", bufferError);
                }
            }
        }
        else
        {
            _shouldUseShaders = NO;
            
            [super _prepareSupersamplingBufferForFrame: frame];
            
            //If we're not using shaders this time around, then set the texture filtering parameters
            //appropriately for the fallback supersampling rendering path.
            [self.frameTexture setMinFilter: GL_LINEAR
                                  magFilter: GL_NEAREST
                                   wrapping: GL_CLAMP_TO_EDGE];
            
            [self.supersamplingBufferTexture setMinFilter: GL_LINEAR
                                                magFilter: GL_LINEAR
                                                 wrapping: GL_CLAMP_TO_EDGE];
        }
        
        _shouldRecalculateBuffer = NO;
    }
}

@end
