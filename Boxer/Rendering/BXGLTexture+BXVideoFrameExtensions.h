//
//  BXGLTexture+BXFrameBufferExtensions.h
//  Boxer
//
//  Created by Alun Bestor on 03/06/2012.
//  Copyright (c) 2012 Alun Bestor and contributors. All rights reserved.
//

#import "BXTexture2D.h"

//Helper methods for creating and filling BXGLTextures straight from frame buffers. 

@class BXVideoFrame;

@interface BXTexture2D (BXVideoFrameExtensions)

//Create a new texture with the contents of the specified frame buffer.
+ (id) textureWithType: (GLenum)type
            videoFrame: (BXVideoFrame *)frame
                 error: (NSError **)outError;

- (id) initWithType: (GLenum)type
         videoFrame: (BXVideoFrame *)frame
              error: (NSError **)outError;

//Fill the frame with the specified frame buffer.
//This takes into account 'dirty' regions of the frame buffer, and also updates the content region
//of the texture to match the size of the frame buffer. 
- (BOOL) fillWithVideoFrame: (BXVideoFrame *)frame
                      error: (NSError **)outError;

- (BOOL) canAccomodateVideoFrame: (BXVideoFrame *)frame;

@end
