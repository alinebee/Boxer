/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "ADBTexture2D.h"

//Helper methods for creating and filling BXGLTextures straight from frame buffers. 

@class BXVideoFrame;

@interface ADBTexture2D (BXVideoFrameExtensions)

//Create a new texture with the contents of the specified frame buffer.
+ (instancetype) textureWithType: (GLenum)type
                      videoFrame: (BXVideoFrame *)frame
                     inGLContext: (CGLContextObj)context
                           error: (NSError **)outError;

- (instancetype) initWithType: (GLenum)type
                   videoFrame: (BXVideoFrame *)frame
                  inGLContext: (CGLContextObj)context
                        error: (NSError **)outError;

//Fill the frame with the specified frame buffer.
//This takes into account 'dirty' regions of the frame buffer, and also updates the content region
//of the texture to match the size of the frame buffer. 
- (BOOL) fillWithVideoFrame: (BXVideoFrame *)frame
                      error: (NSError **)outError;

- (BOOL) canAccomodateVideoFrame: (BXVideoFrame *)frame;

@end
