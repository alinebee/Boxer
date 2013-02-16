/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "ADBShader.h"

@interface BXRippleShader : ADBShader
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
