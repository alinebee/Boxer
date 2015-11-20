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

//ADBSNESShader is an implementation of ADBShader that handles BSNES's XML-format shader specification version 1.1.
//q.v. https://gitorious.org/bsnes/pages/XmlShaderFormat

#import "ADBShader.h"


#pragma mark -
#pragma mark Constants

typedef enum {
    ADBBSNESShaderFilterAuto,     //Application can decide which texture scaling mode to use.
    ADBBSNESShaderFilterNearest,  //Shader wants nearest-neighbor scaling.
    ADBBSNESShaderFilterLinear    //Shader wants bilinear scaling.
} ADBBSNESShaderFilterType;

typedef enum {
    ADBBSNESShaderScaleAuto,                  //Application can decide the appropriate output size.
    ADBBSNESShaderScaleRelativeToInputSize,   //Scale is treated as a multiple of the input size.
    ADBBSNESShaderScaleRelativeToOutputSize,  //Scale is treated as a multiple of the final output size.
    ADBBSNESShaderScaleToFixedSize            //Scale is treated as a fixed pixel size.
} ADBBSNESShaderScalingBehaviour;


#pragma mark -
#pragma mark Error constants

enum {
    ADBBSNESShaderDefinitionInvalid,     //The .OpenGLShader file was in an unrecognised format or had invalid parameters.
    ADBBSNESShaderDefinitionUnsupported, //The .OpenGLShader file was an unsupported shader type.
};

extern NSString * const ADBBSNESShaderErrorDomain;


#pragma mark -
#pragma mark Uniform names

extern const GLcharARB * const ADBBSNESShaderTextureUniform;
extern const GLcharARB * const ADBBSNESShaderTextureSizeUniform;
extern const GLcharARB * const ADBBSNESShaderInputSizeUniform;
extern const GLcharARB * const ADBBSNESShaderOutputSizeUniform;
extern const GLcharARB * const ADBBSNESShaderFrameCountUniform;

#pragma mark -
#pragma mark Interface declaration

@interface ADBBSNESShader : ADBShader
{
    GLint _textureLocation;
    GLint _textureSizeLocation;
    GLint _inputSizeLocation;
    GLint _outputSizeLocation;
    GLint _frameCountLocation;
    
    uint64_t _frameCount;
    
    ADBBSNESShaderScalingBehaviour _horizontalScalingBehaviour;
    ADBBSNESShaderScalingBehaviour _verticalScalingBehaviour;
    //The X and Y scaling factors to apply. The meaning of these depends on the scaling behaviour.
    CGPoint _scalingFactor;
    ADBBSNESShaderFilterType _filterType;
}

#pragma mark -
#pragma mark Properties

//How many frames have been rendered so far by this shader. Can be used by some shader programs.
@property (assign, nonatomic) uint64_t frameCount;

//How the shader will scale horizontally and vertically.
@property (assign, nonatomic) ADBBSNESShaderScalingBehaviour horizontalScalingBehaviour;
@property (assign, nonatomic) ADBBSNESShaderScalingBehaviour verticalScalingBehaviour;
@property (assign, nonatomic) CGPoint scalingFactor;
@property (assign, nonatomic) ADBBSNESShaderFilterType filterType;


#pragma mark -
#pragma mark Loader methods

//Returns an array of ADBBSNESShaders loaded from the specified OpenGLShader XML definition,
//in the order they were defined. Returns nil and populates outError if the file could not
//be parsed or if one or more shaders failed to compile.
+ (NSArray<ADBBSNESShader*> *) shadersWithContentsOfURL: (NSURL *)shaderURL
                             inContext: (CGLContextObj)context
                                 error: (NSError **)outError;

+ (NSArray<ADBBSNESShader*> *) shadersWithDefinition: (NSXMLDocument *)shaderDefinition
                          inContext: (CGLContextObj)context
                              error: (NSError **)outError;


#pragma mark -
#pragma mark Rendering behaviour

//Returns how large an output surface this shader wants to render the specified input size
//(what the emulator or previous pipeline stage produced) to the specified final output size
//(what the user will see.)
//This is calculated by the shader based on the scaling parameters included in the definition.
- (CGSize) outputSizeForInputSize: (CGSize)inputSize
                  finalOutputSize: (CGSize)finalOutputSize;


//Apply the specified values into the shader's uniforms.
//(Note that these are write-only).
- (void) setTextureIndex: (GLint)texture;
- (void) setTextureSize: (CGSize)textureSize;
- (void) setInputSize: (CGSize)size;
- (void) setOutputSize: (CGSize)size;

@end
