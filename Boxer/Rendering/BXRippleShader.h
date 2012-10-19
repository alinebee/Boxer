//
//  BXRippleShader.h
//  Boxer
//
//  Created by Alun Bestor on 22/08/2012.
//  Copyright (c) 2012 Alun Bestor and contributors. All rights reserved.
//

#import "BXShader.h"

@interface BXRippleShader : BXShader
{
    GLint _textureLocation;
    GLint _textureSizeLocation;
    GLint _inputSizeLocation;
    GLint _frameTimeLocation;
    GLint _rippleOriginLocation;
    GLint _rippleHeightLocation;
}

#pragma mark -
#pragma mark Shader setters
- (void) setTextureIndex: (GLint)texture;
- (void) setTextureSize: (CGSize)textureSize;
- (void) setInputSize: (CGSize)inputSize;
- (void) setFrameTime: (CFAbsoluteTime)frameTime;

//Specified as a range from 0.0 to 1.0.
- (void) setRippleOrigin: (CGPoint)origin;

- (void) setRippleHeight: (GLfloat)rippleHeight;

@end
