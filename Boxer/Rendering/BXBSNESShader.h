/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXSNESShader is an implementation of BXShader that handles BSNES's XML-format shader specification version 1.1.
//q.v. https://gitorious.org/bsnes/pages/XmlShaderFormat

#import "BXShader.h"


#pragma mark -
#pragma mark Constants

typedef enum {
    BXBSNESShaderFilterAuto,     //Application can decide which texture scaling mode to use.
    BXBSNESShaderFilterNearest,  //Shader wants nearest-neighbor scaling.
    BXBSNESShaderFilterLinear    //Shader wants bilinear scaling.
} BXBSNESShaderFilterType;

typedef enum {
    BXBSNESShaderScaleAuto,                  //Application can decide the appropriate output size.
    BXBSNESShaderScaleRelativeToInputSize,   //Scale is treated as a multiple of the input size.
    BXBSNESShaderScaleRelativeToOutputSize,  //Scale is treated as a multiple of the final output size.
    BXBSNESShaderScaleToFixedSize            //Scale is treated as a fixed pixel size.
} BXBSNESShaderScalingBehaviour;


#pragma mark -
#pragma mark Error constants

enum {
    BXBSNESShaderDefinitionInvalid,     //The .OpenGLShader file was in an unrecognised format or had invalid parameters.
    BXBSNESShaderDefinitionUnsupported, //The .OpenGLShader file was an unsupported shader type.
};

extern NSString * const BXBSNESShaderErrorDomain;


#pragma mark -
#pragma mark Uniform names

extern const GLcharARB * const BXBSNESShaderTextureUniform;
extern const GLcharARB * const BXBSNESShaderTextureSizeUniform;
extern const GLcharARB * const BXBSNESShaderInputSizeUniform;
extern const GLcharARB * const BXBSNESShaderOutputSizeUniform;
extern const GLcharARB * const BXBSNESShaderFrameCountUniform;

#pragma mark -
#pragma mark Interface declaration

@interface BXBSNESShader : BXShader
{
    GLint _textureLocation;
    GLint _textureSizeLocation;
    GLint _inputSizeLocation;
    GLint _outputSizeLocation;
    GLint _frameCountLocation;
    
    uint64_t _frameCount;
    
    BXBSNESShaderScalingBehaviour _horizontalScalingBehaviour;
    BXBSNESShaderScalingBehaviour _verticalScalingBehaviour;
    //The X and Y scaling factors to apply. The meaning of these depends on the scaling behaviour.
    CGPoint _scalingFactor;
    BXBSNESShaderFilterType _filterType;
}

#pragma mark -
#pragma mark Properties

//How many frames have been rendered so far by this shader. Used by some shader programs.
@property (assign, nonatomic) uint64_t frameCount;

//How the shader will scale horizontally and vertically.
@property (assign, nonatomic) BXBSNESShaderScalingBehaviour horizontalScalingBehaviour;
@property (assign, nonatomic) BXBSNESShaderScalingBehaviour verticalScalingBehaviour;
@property (assign, nonatomic) CGPoint scalingFactor;
@property (assign, nonatomic) BXBSNESShaderFilterType filterType;


#pragma mark -
#pragma mark Loader methods

//Returns an array of shaders loaded from the specified OpenGLShader XML definition, in the order
//they were defined. Returns nil and populates outError if the file could not be parsed or if one
//or more shaders failed to compile.
+ (NSArray *) shadersWithContentsOfURL: (NSURL *)shaderURL
                                 error: (NSError **)outError;

+ (NSArray *) shadersWithDefinition: (NSXMLDocument *)shaderDefinition
                              error: (NSError **)outError;


#pragma mark -
#pragma mark Rendering behaviour

//Returns how large an output surface this shader needs to render the specified input size
//(what the emulator rendered or the previous pipeline stage produced) to the specified final
//output size (what the user will see.)
//This is calculated by the shader based on the scaling parameters included in the definition.
- (CGSize) outputSizeForInputSize: (CGSize)inputSize
                  finalOutputSize: (CGSize)finalOutputSize;


//Apply the specified values into the shader's uniforms.
//(Note that these are write-only).
- (void) setTexture: (GLint)texture;
- (void) setTextureSize: (CGSize)textureSize;
- (void) setInputSize: (CGSize)size;
- (void) setOutputSize: (CGSize)size;

@end
