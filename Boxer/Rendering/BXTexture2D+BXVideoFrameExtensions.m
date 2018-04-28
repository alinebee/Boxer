/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXTexture2D+BXVideoFrameExtensions.h"
#import "BXVideoFrame.h"
#import "ADBGeometry.h"
#import <OpenGL/CGLMacro.h>

@implementation ADBTexture2D (BXVideoFrameExtensions)

+ (id) textureWithType: (GLenum)type
            videoFrame: (BXVideoFrame *)frame
           inGLContext: (CGLContextObj)context
                 error: (NSError **)outError
{
    return [[self alloc] initWithType: type
                            videoFrame: frame
                           inGLContext: context
                                 error: outError];
}

- (id) initWithType: (GLenum)type 
         videoFrame: (BXVideoFrame *)frame
        inGLContext: (CGLContextObj)context
              error: (NSError **)outError
{
    return [self initWithType: type
                  contentSize: NSSizeToCGSize(frame.size)
                        bytes: frame.bytes
                  inGLContext: context
                        error: outError];
}

- (BOOL) fillWithVideoFrame: (BXVideoFrame *)frame
                      error: (NSError **)outError
{
    //If the frame has changed shape: update the content region, wipe the texture clean,
    //and copy the entire frame into the texture rather than bothering to check for changed lines.
    CGRect newContentRegion = CGRectMake(0, 0, frame.size.width, frame.size.height);
    if (/* DISABLES CODE */ (YES) || !CGRectEqualToRect(_contentRegion, newContentRegion))
    {
        self.contentRegion = newContentRegion;
        CGRect textureRegion = CGRectMake(0, 0, _textureSize.width, _textureSize.height);
        [self fillRegion: textureRegion withRed: 0 green: 0 blue: 0 alpha: 0 error: NULL];
        return [self fillRegion: newContentRegion withBytes: frame.bytes error: outError];
    }
    //This branch is disabled for now because it was occasionally missing rows:
    //this could be because of a logical error in the calculation of dirty ranges,
    //or could be because of a change in OS X's GL server that has introduced some
    //race condition with the multithreaded renderer.
    //(My gut says that with modern drivers it's more efficient to upload all the texture
    //data in a single call anyway, so the code below is a false optimisation.)
    else
    {
        //Optimisation: only upload the changed regions to the texture.
        //TODO: profile this and see if it's quicker under some circumstances
        //to just upload the whole texture at once, e.g. if there's lots of small
        //changed regions.
        
        NSUInteger pitch = frame.pitch;
        GLsizei frameWidth = (GLsizei)frame.size.width;
        NSUInteger i, numRegions = frame.numDirtyRegions;
        
        CGLContextObj cgl_ctx = _context;
        
        glBindTexture(_type, _texture);
        
        for (i=0; i < numRegions; i++)
        {
            NSRange dirtyRegion = [frame dirtyRegionAtIndex: i];
            NSUInteger regionOffset = dirtyRegion.location * pitch;
            
            NSAssert2(regionOffset < frame.frameData.length,
                      @"Dirty region offset exceeded frame size: %lu (limit %lu)", (unsigned long)regionOffset, (unsigned long)frame.frameData.length);
            
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
        
        BOOL succeeded = [self _checkForGLError: outError];
            
        return succeeded;
    }
}

- (BOOL) canAccomodateVideoFrame: (BXVideoFrame *)frame
{
    return [self canAccommodateContentSize: NSSizeToCGSize(frame.size)];
}
@end
