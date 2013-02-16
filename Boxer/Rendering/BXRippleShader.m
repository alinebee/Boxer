/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXRippleShader.h"
#import <OpenGL/gl.h>
#import <OpenGL/CGLMacro.h>

@implementation BXRippleShader

//These functions look up the location of their uniforms the first time they are needed,
//and store them thereafter.
- (void) setTextureIndex: (GLint)texture
{
    CGLContextObj cgl_ctx = _context;
    if (!_textureLocation)
    {
        _textureLocation = glGetUniformLocationARB(_shaderProgram, "rubyTexture");
    }
    
    if (_textureLocation != ADBShaderUnsupportedUniformLocation)
        glUniform1iARB(_textureLocation, texture);
}

- (void) setTextureSize: (CGSize)textureSize
{
    CGLContextObj cgl_ctx = _context;
    if (!_textureSizeLocation)
    {
        _textureSizeLocation = glGetUniformLocationARB(_shaderProgram, "rubyTextureSize");
    }
    
    if (_textureSizeLocation != ADBShaderUnsupportedUniformLocation)
        glUniform2fARB(_textureSizeLocation, textureSize.width, textureSize.height);
}

- (void) setInputSize: (CGSize)inputSize
{
    CGLContextObj cgl_ctx = _context;
    if (!_inputSizeLocation)
    {
        _inputSizeLocation = glGetUniformLocationARB(_shaderProgram, "rubyInputSize");
    }
    
    if (_inputSizeLocation != ADBShaderUnsupportedUniformLocation)
        glUniform2fARB(_inputSizeLocation, inputSize.width, inputSize.height);
}

- (void) setRippleOrigin: (CGPoint)origin
{
    CGLContextObj cgl_ctx = _context;
    if (!_rippleOriginLocation)
    {
        _rippleOriginLocation = glGetUniformLocationARB(_shaderProgram, "rippleOrigin");
    }
    
    if (_rippleOriginLocation != ADBShaderUnsupportedUniformLocation)
        glUniform2fARB(_rippleOriginLocation, origin.x, origin.y);
}

- (void) setRippleHeight: (GLfloat)height
{
    CGLContextObj cgl_ctx = _context;
    if (!_rippleHeightLocation)
    {
        _rippleHeightLocation = glGetUniformLocationARB(_shaderProgram, "rippleHeight");
    }
    
    if (_rippleHeightLocation != ADBShaderUnsupportedUniformLocation)
        glUniform1fARB(_rippleHeightLocation, height);
}

- (void) setFrameTime: (CFAbsoluteTime)frameTime
{
    CGLContextObj cgl_ctx = _context;
    if (!_frameTimeLocation)
    {
        _frameTimeLocation = glGetUniformLocationARB(_shaderProgram, "time");
    }
    
    if (_frameTimeLocation != ADBShaderUnsupportedUniformLocation)
    {
        GLfloat clampedTime = (GLfloat)fmod(frameTime, M_PI * 2);
        glUniform1fARB(_frameTimeLocation, clampedTime);
    }
}
@end
