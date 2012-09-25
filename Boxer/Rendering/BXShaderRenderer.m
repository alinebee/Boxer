//
//  BXShaderRenderer.m
//  Boxer
//
//  Created by Alun Bestor on 20/06/2012.
//  Copyright (c) 2012 Alun Bestor and contributors. All rights reserved.
//

#import "BXBasicRendererPrivate.h"
#import "BXBSNESShader.h"

@implementation BXShaderRenderer
@synthesize auxiliaryBufferTexture = _auxiliaryBufferTexture;
@synthesize shaders = _shaders;
@synthesize usesShaderUpsampling = _usesShaderUpsampling;

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
    NSArray *shaders = [BXBSNESShader shadersWithContentsOfURL: shaderURL
                                                     inContext: glContext
                                                         error: outError];
    if (shaders)
    {
        self = [self initWithShaderSet: shaders inContext: glContext error: outError];
    }
    else
    {
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
        _shouldUseShaders = YES;
        _usesShaderUpsampling = YES;
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
        
        BXTexture2D *inTexture = self.frameTexture;
        BXTexture2D *outTexture = nil;
        
        NSUInteger i, numShaders = self.shaders.count;
        for (i=0; i < numShaders; i++)
        {
            BXBSNESShader *shader = [self.shaders objectAtIndex: i];
            
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
                [outTexture setContentRegion: CGRectMake(0, 0, outputSize.width, outputSize.height)];
                
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
                case BXBSNESShaderFilterNearest:
                    [inTexture setMinFilter: GL_NEAREST
                                  magFilter: GL_NEAREST
                                   wrapping: GL_REPEAT];
                    break;
                case BXBSNESShaderFilterLinear:
                case BXBSNESShaderFilterAuto:
                default:
                    [inTexture setMinFilter: GL_NEAREST
                                  magFilter: GL_LINEAR
                                   wrapping: GL_REPEAT];
                    break;
            }
            
            //Activate the shader program and assign the uniform variables appropriately.
            glUseProgramObjectARB(shader.shaderProgram);
            
            shader.textureIndex = 0;
            shader.textureSize = inTexture.textureSize;
            shader.inputSize = inTexture.contentRegion.size;
            shader.outputSize = outputRect.size;
            shader.frameCount++;
            
            //Resize the viewport and draw!
            if (!shaderNeedsBuffer && self.delegate)
                [self.delegate renderer: self willRenderTextureToDestinationContext: inTexture];
                
            [self _setViewportToRegion: outputRect];
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
            
            [self _setViewportToRegion: self.viewport];
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
    if (self.usesShaderUpsampling)
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
        while (nearestScale > 0 && !BXCGSizeFitsWithinSize(preferredSupersamplingSize, _maxBufferTextureSize));
        
        return preferredSupersamplingSize;
    }
    else
    {
        return viewport.size;
    }
}

- (void) _prepareSupersamplingBufferForFrame: (BXVideoFrame *)frame
{
    //IMPLEMENTATION NOTE: when preparing the supersampling buffer(s)
    //we also precalculate details about the shader stack we're using
    //to save time when rendering.
    if (_shouldRecalculateBuffer)
    {   
        NSUInteger i, numShaders = self.shaders.count;
        if (numShaders)
        {
            CGSize inputSize = NSSizeToCGSize(frame.size);
            CGSize finalOutputSize = self.viewport.size;
            CGSize preferredOutputSize = [self _idealShaderRenderingSizeForFrame: frame toViewport: self.viewport];
            
            CGSize largestOutputSize = preferredOutputSize;
            NSUInteger numShadersNeedingBuffers = 0;
            
            //Scan our shaders to figure out how big an output surface they will render
            //and whether they will need to draw into an intermediate sample buffer
            //rather than direct to the screen.
            
            _shouldUseShaders = YES;
            for (i=0; i<numShaders; i++)
            {
                BXBSNESShader *shader = [self.shaders objectAtIndex: i];
                
                BOOL isFirstShader  = (i == 0);
                BOOL isLastShader   = (i == numShaders - 1);
                
                //All but the last shader are guaranteed to need to draw into a frame buffer.
                BOOL shaderNeedsBuffer = !isLastShader;
                
                //Ask the shader how big a surface it wants to render into given the current input size.
                CGSize outputSize = [shader outputSizeForInputSize: inputSize
                                                   finalOutputSize: finalOutputSize];
                
                //If no preferred size was given, and this is the first shader,
                //then use our own preferred upscaling output size.
                if (isFirstShader)
                {
                    if (outputSize.width == 0)
                        outputSize.width = preferredOutputSize.width;
                    
                    if (outputSize.height == 0)
                        outputSize.height = preferredOutputSize.height;
                }
                
                //If this is the last shader and its output size differs from
                //the viewport size, then we'll need to render to an intermediate
                //framebuffer for that also.
                if (isLastShader)
                {
                    if (outputSize.width == 0)
                        outputSize.width = finalOutputSize.width;
                    else if (outputSize.height != finalOutputSize.height)
                        shaderNeedsBuffer = YES;
                    
                    if (outputSize.height == 0)
                        outputSize.height = finalOutputSize.height;
                    else if (outputSize.height != finalOutputSize.height)
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
            
            //At this stage, we now know:
            //1. Whether our fallback supersampling render path will need a buffer;
            //2. How many of our shaders need to draw to an intermediate scaling buffer;
            //3. The largest output size we will need to accomodate in our scaling buffer.
            
            //From this we can decide how many buffer textures we'll need and what size
            //to make them. We'll use up to two buffers of identical size and swap them
            //back and forth as we render our shaders into them.
            
            //Bounds-check the overall size we need for the buffer, to ensure that it still
            //fits within our maximum texture size.
            //TODO: finesse this so that it will try to choose a suitable size based on the
            //shader context.
            largestOutputSize.width     = MIN(largestOutputSize.width, _maxBufferTextureSize.width);
            largestOutputSize.height    = MIN(largestOutputSize.height, _maxBufferTextureSize.height);
        
            //Recreate the main buffer texture, if we don't have one yet or if our old one
            //cannot accomodate the output size.
            if (numShadersNeedingBuffers > 0)
            {
                if (![self.supersamplingBufferTexture canAccomodateContentSize: largestOutputSize])
                {
                    if (_currentBufferTexture == self.supersamplingBufferTexture.texture)
                        _currentBufferTexture = 0;
                    
                    //Clear our old buffer texture straight away when replacing it
                    [self.supersamplingBufferTexture deleteTexture];
                    
                    //(Re)create the buffer texture in the new dimensions
                    self.supersamplingBufferTexture = [BXTexture2D textureWithType: self.bufferTextureType
                                                                       contentSize: largestOutputSize
                                                                             bytes: NULL
                                                                       inGLContext: _context
                                                                             error: NULL];
                }
            }
            
            //(Re)create a second auxiliary buffer if we'll need to swap back and forth
            //to handle multiple shaders.
            if (numShadersNeedingBuffers > 1)
            {
                if (![self.auxiliaryBufferTexture canAccomodateContentSize: largestOutputSize])
                {   
                    if (_currentBufferTexture == self.auxiliaryBufferTexture.texture)
                        _currentBufferTexture = 0;
                    
                    
                    //Clear our old buffer texture straight away when replacing it
                    [self.auxiliaryBufferTexture deleteTexture];
                    
                    //(Re)create the buffer texture in the new dimensions
                    self.auxiliaryBufferTexture = [BXTexture2D textureWithType: self.bufferTextureType
                                                                   contentSize: largestOutputSize
                                                                         bytes: NULL
                                                                   inGLContext: _context
                                                                         error: NULL];
                }
            }
        }
        else
        {
            _shouldUseShaders = NO;
            
            if (_currentBufferTexture == self.supersamplingBufferTexture.texture)
                _currentBufferTexture = 0;
            
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
