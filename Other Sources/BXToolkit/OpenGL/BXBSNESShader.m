/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXBSNESShader.h"
#import <OpenGL/gl.h>
#import <OpenGL/CGLMacro.h>

#pragma mark -
#pragma mark Constants

NSString * const BXBSNESShaderErrorDomain = @"BXBSNESShaderErrorDomain";

//The texture to render from.
#define BXBSNESShaderTextureUniform "rubyTexture"
//The dimensions (in texels) of the texture.

#define BXBSNESShaderTextureSizeUniform "rubyTextureSize"

//The area (in texels) of the texture from which we want to render.
#define BXBSNESShaderInputSizeUniform "rubyInputSize"

//The area (in pixels) to render to.
#define BXBSNESShaderOutputSizeUniform "rubyOutputSize"

//The number of frames that have been rendered by the shader so far, starting from 0.
#define BXBSNESShaderFrameCountUniform "rubyFrameCount"


#pragma mark -
#pragma mark Private method declarations

@interface BXBSNESShader ()
@end

#pragma mark -
#pragma mark Implementation

@implementation BXBSNESShader
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
        
        [definition release];
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
            *outError = [NSError errorWithDomain: BXBSNESShaderErrorDomain
                                            code: BXBSNESShaderDefinitionUnsupported
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
                    *outError = [NSError errorWithDomain: BXBSNESShaderErrorDomain
                                                    code: BXBSNESShaderDefinitionInvalid
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
            BXBSNESShader *shader = [[BXBSNESShader alloc] initWithVertexShader: lastVertexNode.stringValue
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
            [shader release];
            
            //Fragment definitions also carry data about what kind of scaling and filtering
            //we should do when using the shader. Populate the shader with those now.
            if (lastFragmentNode)
            {
                NSString *filterType = [node attributeForName: @"filter"].stringValue;
                if ([filterType isEqualToString: @"linear"])
                    shader.filterType = BXBSNESShaderFilterLinear;
                else if ([filterType isEqualToString: @"nearest"])
                    shader.filterType = BXBSNESShaderFilterNearest;
                
                //IMPLEMENTATION NOTE: many of the scaling options are mutually exclusive and we
                //should treat it as an error if conflicting options are present. But I can't be
                //bothered doing that at this point, so instead we just ensure the most specific
                //will be applied last.
                CGPoint scalingFactor = CGPointZero;
                
                NSString *tempScaleParam = nil;
                
                if ((tempScaleParam = [node attributeForName: @"size"].stringValue) != nil)
                {
                    shader.horizontalScalingBehaviour = BXBSNESShaderScaleToFixedSize;
                    shader.verticalScalingBehaviour = BXBSNESShaderScaleToFixedSize;
                    scalingFactor.x = scalingFactor.y = tempScaleParam.floatValue;
                }
                
                else if ((tempScaleParam = [node attributeForName: @"scale"].stringValue) != nil)
                {
                    shader.horizontalScalingBehaviour = BXBSNESShaderScaleRelativeToInputSize;
                    shader.verticalScalingBehaviour = BXBSNESShaderScaleRelativeToInputSize;
                    scalingFactor.x = scalingFactor.y = tempScaleParam.floatValue;
                }
                
                else if ((tempScaleParam = [node attributeForName: @"outscale"].stringValue) != nil)
                {
                    shader.horizontalScalingBehaviour = BXBSNESShaderScaleRelativeToOutputSize;
                    shader.verticalScalingBehaviour = BXBSNESShaderScaleRelativeToOutputSize;
                    scalingFactor.x = scalingFactor.y = tempScaleParam.floatValue;
                }
                
                
                if ((tempScaleParam = [node attributeForName: @"size_x"].stringValue) != nil)
                {
                    shader.horizontalScalingBehaviour = BXBSNESShaderScaleToFixedSize;
                    scalingFactor.x = tempScaleParam.floatValue;
                }
                
                else if ((tempScaleParam = [node attributeForName: @"scale_x"].stringValue) != nil)
                {
                    shader.horizontalScalingBehaviour = BXBSNESShaderScaleRelativeToInputSize;
                    scalingFactor.x = tempScaleParam.floatValue;
                }
                
                else if ((tempScaleParam = [node attributeForName: @"outscale_x"].stringValue) != nil)
                {
                    shader.horizontalScalingBehaviour = BXBSNESShaderScaleRelativeToOutputSize;
                    scalingFactor.x = tempScaleParam.floatValue;
                }
                
                
                if ((tempScaleParam = [node attributeForName: @"size_y"].stringValue) != nil)
                {
                    shader.verticalScalingBehaviour = BXBSNESShaderScaleToFixedSize;
                    scalingFactor.y = tempScaleParam.floatValue;
                }
                
                else if ((tempScaleParam = [node attributeForName: @"scale_y"].stringValue) != nil)
                {
                    shader.verticalScalingBehaviour = BXBSNESShaderScaleRelativeToInputSize;
                    scalingFactor.y = tempScaleParam.floatValue;
                }
                
                else if ((tempScaleParam = [node attributeForName: @"outscale_y"].stringValue) != nil)
                {
                    shader.verticalScalingBehaviour = BXBSNESShaderScaleRelativeToOutputSize;
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
        self.horizontalScalingBehaviour = BXBSNESShaderScaleAuto;
        self.verticalScalingBehaviour = BXBSNESShaderScaleAuto;
        self.scalingFactor = CGPointMake(1, 1);
        self.filterType = BXBSNESShaderFilterAuto;
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
        _textureLocation = glGetUniformLocationARB(self.shaderProgram, BXBSNESShaderTextureUniform);
    }
    
    if (_textureLocation != BXShaderUnsupportedUniformLocation)
        glUniform1iARB(_textureLocation, texture);
}

- (void) setTextureSize: (CGSize)textureSize
{
    CGLContextObj cgl_ctx = _context;
    if (!_textureSizeLocation)
    {
        _textureSizeLocation = glGetUniformLocationARB(self.shaderProgram, BXBSNESShaderTextureSizeUniform);
    }
    
    if (_textureSizeLocation != BXShaderUnsupportedUniformLocation)
        glUniform2fARB(_textureSizeLocation, textureSize.width, textureSize.height);
}

- (void) setInputSize: (CGSize)inputSize
{
    CGLContextObj cgl_ctx = _context;
    if (!_inputSizeLocation)
    {
        _inputSizeLocation = glGetUniformLocationARB(self.shaderProgram, BXBSNESShaderInputSizeUniform);
    }
    
    if (_inputSizeLocation != BXShaderUnsupportedUniformLocation)
        glUniform2fARB(_inputSizeLocation, inputSize.width, inputSize.height);
}

- (void) setOutputSize: (CGSize)outputSize
{
    CGLContextObj cgl_ctx = _context;
    if (!_outputSizeLocation)
    {
        _outputSizeLocation = glGetUniformLocationARB(self.shaderProgram, BXBSNESShaderOutputSizeUniform);
    }
    
    if (_outputSizeLocation != BXShaderUnsupportedUniformLocation)
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
            _frameCountLocation = glGetUniformLocationARB(self.shaderProgram, BXBSNESShaderFrameCountUniform);
        }
        
        if (_frameCountLocation != BXShaderUnsupportedUniformLocation)
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
        case BXBSNESShaderScaleToFixedSize:
            outputSize.width = self.scalingFactor.x;
            break;
        case BXBSNESShaderScaleRelativeToInputSize:
            outputSize.width = inputSize.width * self.scalingFactor.x;
            break;
        case BXBSNESShaderScaleRelativeToOutputSize:
            outputSize.width = finalOutputSize.width * self.scalingFactor.x;
            break;
        case BXBSNESShaderScaleAuto:
        default:
            outputSize.width = 0;
    }
    
    switch (self.verticalScalingBehaviour)
    {
        case BXBSNESShaderScaleToFixedSize:
            outputSize.height = self.scalingFactor.y;
            break;
        case BXBSNESShaderScaleRelativeToInputSize:
            outputSize.height = inputSize.height * self.scalingFactor.y;
            break;
        case BXBSNESShaderScaleRelativeToOutputSize:
            outputSize.height = finalOutputSize.height * self.scalingFactor.y;
            break;
        case BXBSNESShaderScaleAuto:
        default:
            outputSize.height = 0;
    }
    
    return outputSize;
}

@end
