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
@synthesize shadersEnabled = _shadersEnabled;
@synthesize minShaderScale = _minShaderScale;
@synthesize maxShaderScale = _maxShaderScale;

#pragma mark -
#pragma mark Initialization and deallocation

- (id) initWithShaders: (NSArray *)shaders
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
        self = [self initWithShaders: shaders inContext: glContext error: outError];
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
        _shadersEnabled = YES;
        _shouldUseShaders = YES;
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
    return _shouldUseShaders && self.shadersEnabled;
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
            //Otherwise we'll render the shader straight to the screen.
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
            [self _setViewportToRegion: outputRect];
            [inTexture drawOntoVertices: quadCoords error: nil];
            
            //Use the output from this shader as the input for the next shader (if any.)
            inTexture = outTexture;
        }
        
        glUseProgramObjectARB(NULL);
        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, originalBuffer);
        
        //If we were left with a final rendered buffer texture at the end of the process,
        //draw this to the screen now.
        if (outTexture)
        {
            [self _setViewportToRegion: self.viewport];
            [outTexture drawOntoVertices: viewportVertices error: nil];
        }
    }
    //Fall back on the parent rendering path if shaders should not be used.
    else
    {
        //Our parent implementation sets the filtering and content size of the buffer texture
        //once in _prepareSupersamplingBufferForFrame:.
        //Because we're reusing frame and buffer textures between both rendering paths,
        //the texture filtering parameters and rendering sizes may have been modified
        //from what it expects by our shader rendering path.
        [self.frameTexture setMinFilter: GL_LINEAR
                              magFilter: GL_NEAREST
                               wrapping: GL_CLAMP_TO_EDGE];
        
        if (_shouldUseSupersampling)
        {
            [self.supersamplingBufferTexture setMinFilter: GL_LINEAR
                                                magFilter: GL_LINEAR
                                                 wrapping: GL_CLAMP_TO_EDGE];
            
            self.supersamplingBufferTexture.contentRegion = CGRectMake(0, 0,
                                                                       _supersamplingSize.width,
                                                                       _supersamplingSize.height);
        }
        
        [super _renderFrame: frame];
    }
}

- (CGSize) _idealShaderRenderingSizeForFrame: (BXVideoFrame *)frame toViewport: (CGRect)viewport
{
    return viewport.size;
    /*
    CGSize preferredSupersamplingSize = [self _idealSupersamplingBufferSizeForFrame: frame
                                                                         toViewport: viewport];
    
    if (CGSizeEqualToSize(_supersamplingSize, CGSizeZero))
        preferredSupersamplingSize = viewport.size;
    
    return preferredSupersamplingSize;
     */
}

- (void) _prepareSupersamplingBufferForFrame: (BXVideoFrame *)frame
{
    //IMPLEMENTATION NOTE: when preparing the supersampling buffer(s)
    //we also precalculate details about the shader stack we're using
    //to save time when rendering.
    if (_shouldRecalculateBuffer)
    {
        _supersamplingSize = [self _idealSupersamplingBufferSizeForFrame: frame
                                                              toViewport: self.viewport];
        
        _shouldUseSupersampling = !CGSizeEqualToSize(_supersamplingSize, CGSizeZero);
        
        //TODO: check here if the supersampling scale is too small for
        //the shader program to produce good-quality results, and disable shaders if so.
        
        CGSize inputSize = NSSizeToCGSize(frame.size);
        CGSize finalOutputSize = self.viewport.size;
        CGSize preferredOutputSize = [self _idealShaderRenderingSizeForFrame: frame
                                                                  toViewport: self.viewport];
        
        //Scan our shaders to figure out how big an output surface they will render
        //and whether they will need to draw into an intermediate sample buffer
        //rather than direct to the screen.
        CGSize largestOutputSize = preferredOutputSize;
        NSUInteger numShadersNeedingBuffers = 0;
        
        NSUInteger i, numShaders = self.shaders.count;
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
            
            NSLog(@"Size needed for shader %i: %@", i, NSStringFromCGSize(outputSize));
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
        if (_shouldUseSupersampling || numShadersNeedingBuffers > 0)
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
        
        _shouldRecalculateBuffer = NO;
    }
}

@end
