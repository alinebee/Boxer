/*
 *  Copyright (c) 2013, Alun Bestor (alun.bestor@gmail.com)
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *		Redistributions of source code must retain the above copyright notice, this
 *	    list of conditions and the following disclaimer.
 *
 *		Redistributions in binary form must reproduce the above copyright notice,
 *	    this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 *	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 */


#import "ADBBSNESShader.h"
#import <OpenGL/gl.h>
#import <OpenGL/CGLMacro.h>

#pragma mark -
#pragma mark Constants

NSString * const ADBBSNESShaderErrorDomain = @"ADBBSNESShaderErrorDomain";

//The texture to render from.
#define ADBBSNESShaderTextureUniform "rubyTexture"
//The dimensions (in texels) of the texture.

#define ADBBSNESShaderTextureSizeUniform "rubyTextureSize"

//The area (in texels) of the texture from which we want to render.
#define ADBBSNESShaderInputSizeUniform "rubyInputSize"

//The area (in pixels) to render to.
#define ADBBSNESShaderOutputSizeUniform "rubyOutputSize"

//The number of frames that have been rendered by the shader so far, starting from 0.
#define ADBBSNESShaderFrameCountUniform "rubyFrameCount"


#pragma mark -
#pragma mark Private method declarations

@interface ADBBSNESShader ()
@end

#pragma mark -
#pragma mark Implementation

@implementation ADBBSNESShader
@synthesize frameCount = _frameCount;
@synthesize horizontalScalingBehaviour = _horizontalScalingBehaviour;
@synthesize verticalScalingBehaviour = _verticalScalingBehaviour;
@synthesize scalingFactor = _scalingFactor;
@synthesize filterType = _filterType;


#pragma mark -
#pragma mark Initialization and deallocation

+ (NSArray *) shadersWithContentsOfURL: (NSURL *)shaderURL
                             inContext: (CGLContextObj)context
                                 error: (NSError **)outError
{
    NSXMLDocument *definition = [[NSXMLDocument alloc] initWithContentsOfURL: shaderURL
                                                                     options: 0
                                                                       error: outError];
    
    if (definition)
    {
        return [self shadersWithDefinition: definition
                                 inContext: context
                                     error: outError];
    }
    else return nil;
}

+ (NSArray *) shadersWithDefinition: (NSXMLDocument *)shaderDefinition
                          inContext: (CGLContextObj)context
                              error: (NSError **)outError
{
    NSMutableArray *shaders = [NSMutableArray arrayWithCapacity: 1];
    
    //First, check that this is a supported shader format. We only support GLSL shaders.
    NSString *format = [shaderDefinition.rootElement attributeForName: @"language"].stringValue;
    if (![format isEqualToString: @"GLSL"])
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain: ADBBSNESShaderErrorDomain
                                            code: ADBBSNESShaderDefinitionUnsupported
                                        userInfo: nil];
        }
        return nil;
    }
    
    //Now, walk through the nodes building up a set of shader programs.
    //In the 1.1 shader format, the file is composed of sequences of zero or one vertex shader
    //definitions and one fragment shader definition. Sequential fragment shaders will be
    //compiled into separate programs, as they may have .
    NSArray *nodes = shaderDefinition.rootElement.children;
    NSXMLElement *lastVertexNode = nil;
    NSXMLElement *lastFragmentNode = nil;
    for (NSXMLElement *node in nodes)
    {
        if ([node.name isEqualToString: @"vertex"])
        {
            //If there were two vertex nodes in a row, this is a malformed shader and we should bail out.
            if (lastVertexNode)
            {
                if (outError)
                {
                    *outError = [NSError errorWithDomain: ADBBSNESShaderErrorDomain
                                                    code: ADBBSNESShaderDefinitionInvalid
                                                userInfo: nil];
                }
                return nil;
            }
            else
            {
                lastVertexNode = node;
            }
        }
        else if ([node.name isEqualToString: @"fragment"])
        {
            lastFragmentNode = node;
        }
        
        //When we hit a fragment node, compile this and any vertex node into a new shader program.
        if (lastFragmentNode)
        {
            NSArray *fragments = (lastFragmentNode) ? [NSArray arrayWithObject: lastFragmentNode.stringValue] : nil;
            ADBBSNESShader *shader = [[ADBBSNESShader alloc] initWithVertexShader: lastVertexNode.stringValue
                                                                fragmentShaders: fragments
                                                                      inContext: context
                                                                          error: outError];
            
            //If we failed to create the shader, bail out immediately
            //(outError will have been populated for us already.)
            if (!shader)
            {
                return nil;
            }
            
            [shaders addObject: shader];
            
            //Fragment definitions also carry data about what kind of scaling and filtering
            //we should do when using the shader. Populate the shader with those now.
            if (lastFragmentNode)
            {
                NSString *filterType = [node attributeForName: @"filter"].stringValue;
                if ([filterType isEqualToString: @"linear"])
                    shader.filterType = ADBBSNESShaderFilterLinear;
                else if ([filterType isEqualToString: @"nearest"])
                    shader.filterType = ADBBSNESShaderFilterNearest;
                
                //IMPLEMENTATION NOTE: many of the scaling options are mutually exclusive and we
                //should treat it as an error if conflicting options are present. But I can't be
                //bothered doing that at this point, so instead we just ensure the most specific
                //will be applied last.
                CGPoint scalingFactor = CGPointZero;
                
                NSString *tempScaleParam = nil;
                
                if ((tempScaleParam = [node attributeForName: @"size"].stringValue) != nil)
                {
                    shader.horizontalScalingBehaviour = ADBBSNESShaderScaleToFixedSize;
                    shader.verticalScalingBehaviour = ADBBSNESShaderScaleToFixedSize;
                    scalingFactor.x = scalingFactor.y = tempScaleParam.floatValue;
                }
                
                else if ((tempScaleParam = [node attributeForName: @"scale"].stringValue) != nil)
                {
                    shader.horizontalScalingBehaviour = ADBBSNESShaderScaleRelativeToInputSize;
                    shader.verticalScalingBehaviour = ADBBSNESShaderScaleRelativeToInputSize;
                    scalingFactor.x = scalingFactor.y = tempScaleParam.floatValue;
                }
                
                else if ((tempScaleParam = [node attributeForName: @"outscale"].stringValue) != nil)
                {
                    shader.horizontalScalingBehaviour = ADBBSNESShaderScaleRelativeToOutputSize;
                    shader.verticalScalingBehaviour = ADBBSNESShaderScaleRelativeToOutputSize;
                    scalingFactor.x = scalingFactor.y = tempScaleParam.floatValue;
                }
                
                
                if ((tempScaleParam = [node attributeForName: @"size_x"].stringValue) != nil)
                {
                    shader.horizontalScalingBehaviour = ADBBSNESShaderScaleToFixedSize;
                    scalingFactor.x = tempScaleParam.floatValue;
                }
                
                else if ((tempScaleParam = [node attributeForName: @"scale_x"].stringValue) != nil)
                {
                    shader.horizontalScalingBehaviour = ADBBSNESShaderScaleRelativeToInputSize;
                    scalingFactor.x = tempScaleParam.floatValue;
                }
                
                else if ((tempScaleParam = [node attributeForName: @"outscale_x"].stringValue) != nil)
                {
                    shader.horizontalScalingBehaviour = ADBBSNESShaderScaleRelativeToOutputSize;
                    scalingFactor.x = tempScaleParam.floatValue;
                }
                
                
                if ((tempScaleParam = [node attributeForName: @"size_y"].stringValue) != nil)
                {
                    shader.verticalScalingBehaviour = ADBBSNESShaderScaleToFixedSize;
                    scalingFactor.y = tempScaleParam.floatValue;
                }
                
                else if ((tempScaleParam = [node attributeForName: @"scale_y"].stringValue) != nil)
                {
                    shader.verticalScalingBehaviour = ADBBSNESShaderScaleRelativeToInputSize;
                    scalingFactor.y = tempScaleParam.floatValue;
                }
                
                else if ((tempScaleParam = [node attributeForName: @"outscale_y"].stringValue) != nil)
                {
                    shader.verticalScalingBehaviour = ADBBSNESShaderScaleRelativeToOutputSize;
                    scalingFactor.y = tempScaleParam.floatValue;
                }
                
                shader.scalingFactor = scalingFactor;
            }
            
            //After making a new shader pair, clear our tracking variables
            //so we can find another pair.
            lastVertexNode = lastFragmentNode = nil;
        }
    }
    
    return shaders;
}

- (id) init
{
    if ((self = [super init]))
    {
        self.horizontalScalingBehaviour = ADBBSNESShaderScaleAuto;
        self.verticalScalingBehaviour = ADBBSNESShaderScaleAuto;
        self.scalingFactor = CGPointMake(1, 1);
        self.filterType = ADBBSNESShaderFilterAuto;
    }
    return self;
}


#pragma mark -
#pragma mark Uniform assignment

//These functions look up the location of their uniforms the first time they are needed,
//and store them thereafter.
- (void) setTextureIndex: (GLint)texture
{
    CGLContextObj cgl_ctx = _context;
    if (!_textureLocation)
    {
        _textureLocation = glGetUniformLocationARB(self.shaderProgram, ADBBSNESShaderTextureUniform);
    }
    
    if (_textureLocation != ADBShaderUnsupportedUniformLocation)
        glUniform1iARB(_textureLocation, texture);
}

- (void) setTextureSize: (CGSize)textureSize
{
    CGLContextObj cgl_ctx = _context;
    if (!_textureSizeLocation)
    {
        _textureSizeLocation = glGetUniformLocationARB(self.shaderProgram, ADBBSNESShaderTextureSizeUniform);
    }
    
    if (_textureSizeLocation != ADBShaderUnsupportedUniformLocation)
        glUniform2fARB(_textureSizeLocation, textureSize.width, textureSize.height);
}

- (void) setInputSize: (CGSize)inputSize
{
    CGLContextObj cgl_ctx = _context;
    if (!_inputSizeLocation)
    {
        _inputSizeLocation = glGetUniformLocationARB(self.shaderProgram, ADBBSNESShaderInputSizeUniform);
    }
    
    if (_inputSizeLocation != ADBShaderUnsupportedUniformLocation)
        glUniform2fARB(_inputSizeLocation, inputSize.width, inputSize.height);
}

- (void) setOutputSize: (CGSize)outputSize
{
    CGLContextObj cgl_ctx = _context;
    if (!_outputSizeLocation)
    {
        _outputSizeLocation = glGetUniformLocationARB(self.shaderProgram, ADBBSNESShaderOutputSizeUniform);
    }
    
    if (_outputSizeLocation != ADBShaderUnsupportedUniformLocation)
        glUniform2fARB(_outputSizeLocation, outputSize.width, outputSize.height);
}

- (void) setFrameCount: (uint64_t)frameCount
{
    CGLContextObj cgl_ctx = _context;
    if (frameCount != self.frameCount)
    {
        _frameCount = frameCount;
        
        if (!_frameCountLocation)
        {
            _frameCountLocation = glGetUniformLocationARB(self.shaderProgram, ADBBSNESShaderFrameCountUniform);
        }
        
        if (_frameCountLocation != ADBShaderUnsupportedUniformLocation)
            glUniform1iARB(_frameCountLocation, frameCount);
    }
}


#pragma mark -
#pragma mark Scaling decisions

- (CGSize) outputSizeForInputSize: (CGSize)inputSize
                  finalOutputSize: (CGSize)finalOutputSize
{
    CGSize outputSize;
    
    switch (self.horizontalScalingBehaviour)
    {
        case ADBBSNESShaderScaleToFixedSize:
            outputSize.width = self.scalingFactor.x;
            break;
        case ADBBSNESShaderScaleRelativeToInputSize:
            outputSize.width = inputSize.width * self.scalingFactor.x;
            break;
        case ADBBSNESShaderScaleRelativeToOutputSize:
            outputSize.width = finalOutputSize.width * self.scalingFactor.x;
            break;
        case ADBBSNESShaderScaleAuto:
        default:
            outputSize.width = 0;
    }
    
    switch (self.verticalScalingBehaviour)
    {
        case ADBBSNESShaderScaleToFixedSize:
            outputSize.height = self.scalingFactor.y;
            break;
        case ADBBSNESShaderScaleRelativeToInputSize:
            outputSize.height = inputSize.height * self.scalingFactor.y;
            break;
        case ADBBSNESShaderScaleRelativeToOutputSize:
            outputSize.height = finalOutputSize.height * self.scalingFactor.y;
            break;
        case ADBBSNESShaderScaleAuto:
        default:
            outputSize.height = 0;
    }
    
    return outputSize;
}

@end
