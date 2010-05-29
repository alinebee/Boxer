/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXFrameBuffer is a renderer-agnostic framebuffer for DOSBox to draw frames into and for BXRenderer
//to draw as an OpenGL texture. It keeps track of the frame's resolution, bit depth and intended
//display scale.

#import <Foundation/Foundation.h>

@interface BXFrameBuffer : NSObject
{
	NSMutableData *frameData;
	NSSize size;
	NSSize baseResolution;
	NSUInteger bitDepth;
	NSSize intendedScale;
}
@property (readonly) NSSize size;
@property (readonly) NSUInteger bitDepth;
@property (assign) NSSize intendedScale;
@property (assign) NSSize baseResolution;

+ (id) bufferWithSize: (NSSize)targetSize depth: (NSUInteger)depth;
- (id) initWithSize: (NSSize)targetSize depth: (NSUInteger)depth;

//Return the width in bytes of one scanline in the buffer.
- (NSInteger) pitch;

//Returns the size of the frame scaled to the intended scale.
- (NSSize) scaledSize;

//Returns the base resolution of the frame scaled to the intended scale.
- (NSSize) scaledResolution;

//Return a read-only/mutable pointer to the frame's data.
- (const void *) bytes;
- (void *) mutableBytes;

@end