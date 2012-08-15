/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXTexture2D+BXVideoFrameExtensions.h"
#import "BXVideoFrame.h"
#import "BXGeometry.h"
#import <OpenGL/gl.h>
#import <OpenGL/CGLMacro.h>

@implementation BXTexture2D (BXVideoFrameExtensions)

+ (id) textureWithType: (GLenum)type
            videoFrame: (BXVideoFrame *)frame
           inGLContext: (CGLContextObj)context
                 error: (NSError **)outError
{
    return [[[self alloc] initWithType: type
                            videoFrame: frame
                           inGLContext: context
                                 error: outError] autorelease];
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
    if (!CGRectEqualToRect(_contentRegion, newContentRegion))
    {
        self.contentRegion = newContentRegion;
        CGRect textureRegion = CGRectMake(0, 0, _textureSize.width, _textureSize.height);
        [self fillRegion: textureRegion withRed: 0 green: 0 blue: 0 alpha: 0 error: nil];
        return [self fillRegion: newContentRegion withBytes: frame.bytes error: outError];
    }
    
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
                  @"Dirty region offset exceeded frame size: %u (limit %u)", regionOffset, frame.frameData.length);
        
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

- (BOOL) canAccomodateVideoFrame: (BXVideoFrame *)frame
{
    return [self canAccomodateContentSize: NSSizeToCGSize(frame.size)];
}
@end
