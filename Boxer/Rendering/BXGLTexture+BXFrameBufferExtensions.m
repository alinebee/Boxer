//
//  BXGLTexture+BXFrameBufferExtensions.m
//  Boxer
//
//  Created by Alun Bestor on 03/06/2012.
//  Copyright (c) 2012 Alun Bestor and contributors. All rights reserved.
//

#import "BXGLTexture+BXFrameBufferExtensions.h"
#import "BXFrameBuffer.h"

@implementation BXGLTexture (BXFrameBufferExtensions)

+ (id) textureWithType: (GLenum)type frameBuffer: (BXFrameBuffer *)frameBuffer error: (NSError **)outError
{
    return [[[self alloc] initWithType: type frameBuffer: frameBuffer error: outError] autorelease];
}

- (id) initWithType: (GLenum)type frameBuffer: (BXFrameBuffer *)frameBuffer error: (NSError **)outError
{
    return [self initWithType: type
                  contentSize: NSSizeToCGSize(frameBuffer.size)
                        bytes: frameBuffer.bytes
                        error: outError];
}

- (BOOL) fillWithFrameBuffer: (BXFrameBuffer *)frameBuffer
                       error: (NSError **)outError
{    
	glBindTexture(_type, _texture);
    
    self.contentRegion = CGRectMake(0, 0, frameBuffer.size.width, frameBuffer.size.height);
    
    //Optimisation: only upload the changed regions to the texture.
    //TODO: profile this and see if it's quicker under some circumstances
    //to just upload the whole texture at once, e.g. if there's lots of small
    //changed regions.
    
    NSUInteger pitch = frameBuffer.pitch;
    GLsizei frameWidth = (GLsizei)frameBuffer.size.width;
    NSUInteger i, numRegions = frameBuffer.numDirtyRegions;
    
    for (i=0; i < numRegions; i++)
    {
        NSRange dirtyRegion = [frameBuffer dirtyRegionAtIndex: i];
        NSUInteger regionOffset = dirtyRegion.location * pitch;
        
        //Uggghhhh, pointer arithmetic
        const void *regionBytes = frameBuffer.bytes + regionOffset;
        
        glTexSubImage2D(_type,
                        0,                      //Mipmap level
                        0,                      //X offset
                        dirtyRegion.location,	//Y offset
                        frameWidth,             //Width
                        dirtyRegion.length,     //Height
                        GL_BGRA,                //Byte ordering
                        GL_UNSIGNED_INT_8_8_8_8_REV,    //Byte packing
                        regionBytes);                   //Texture data
    }
	
    //Check for errors only if an error object was provided.
    //Otherwise, we assume everything worked OK.
    BOOL succeeded = YES;
    if (outError)
    {
        *outError = [self.class latestGLError];
        succeeded = (*outError == nil);
    }
        
    return succeeded;
}
@end
