//
//  BXGLTexture+BXFrameBufferExtensions.m
//  Boxer
//
//  Created by Alun Bestor on 03/06/2012.
//  Copyright (c) 2012 Alun Bestor and contributors. All rights reserved.
//

#import "BXGLTexture+BXVideoFrameExtensions.h"
#import "BXVideoFrame.h"

@implementation BXTexture2D (BXVideoFrameExtensions)

+ (id) textureWithType: (GLenum)type videoFrame: (BXVideoFrame *)frame error: (NSError **)outError
{
    return [[[self alloc] initWithType: type videoFrame: frame error: outError] autorelease];
}

- (id) initWithType: (GLenum)type videoFrame: (BXVideoFrame *)frame error: (NSError **)outError
{
    return [self initWithType: type
                  contentSize: NSSizeToCGSize(frame.size)
                        bytes: frame.bytes
                        error: outError];
}

- (BOOL) fillWithVideoFrame: (BXVideoFrame *)frame
                      error: (NSError **)outError
{
	glBindTexture(_type, _texture);
    
    self.contentRegion = CGRectMake(0, 0, frame.size.width, frame.size.height);
    
    //Optimisation: only upload the changed regions to the texture.
    //TODO: profile this and see if it's quicker under some circumstances
    //to just upload the whole texture at once, e.g. if there's lots of small
    //changed regions.
    
    NSUInteger pitch = frame.pitch;
    GLsizei frameWidth = (GLsizei)frame.size.width;
    NSUInteger i, numRegions = frame.numDirtyRegions;
    
    for (i=0; i < numRegions; i++)
    {
        NSRange dirtyRegion = [frame dirtyRegionAtIndex: i];
        NSUInteger regionOffset = dirtyRegion.location * pitch;
        
        //Uggghhhh, pointer arithmetic
        const void *regionBytes = frame.bytes + regionOffset;
        
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

- (BOOL) canAccomodateVideoFrame: (BXVideoFrame *)frame
{
    return (frame.size.width < self.textureSize.width) && (frame.size.height < self.textureSize.height);
}
@end
