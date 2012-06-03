//
//  BXGLTexture+BXFrameBufferExtensions.h
//  Boxer
//
//  Created by Alun Bestor on 03/06/2012.
//  Copyright (c) 2012 Alun Bestor and contributors. All rights reserved.
//

#import "BXGLTexture.h"

//Helper methods for creating and filling BXGLTextures straight from frame buffers. 

@class BXFrameBuffer;

@interface BXGLTexture (BXFrameBufferExtensions)

//Create a new texture with the contents of the specified frame buffer.
+ (id) textureWithType: (GLenum)type
           frameBuffer: (BXFrameBuffer *)frameBuffer
                 error: (NSError **)outError;

- (id) initWithType: (GLenum)type
        frameBuffer: (BXFrameBuffer *)frameBuffer
              error: (NSError **)outError;

//Fill the frame with the specified frame buffer.
//This takes into account 'dirty' regions of the frame buffer, and also updates the content region
//of the texture to match the size of the frame buffer. 
- (BOOL) fillWithFrameBuffer: (BXFrameBuffer *)frameBuffer
                       error: (NSError **)outError;

@end
