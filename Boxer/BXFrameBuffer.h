/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXFrameBuffer is a renderer-agnostic framebuffer for DOSBox to draw frames into and for BXRenderer
//to draw as an OpenGL texture. It keeps track of the frame's resolution, bit depth and intended
//display scale.

#import <Cocoa/Cocoa.h>

@interface BXFrameBuffer : NSObject
{
	NSMutableData *frameData;
	NSSize resolution;
	NSUInteger bitDepth;
	NSSize intendedScale;
}
@property (readonly) NSSize resolution;
@property (readonly) NSUInteger bitDepth;
@property (assign) NSSize intendedScale;

+ (id) bufferWithResolution: (NSSize)targetResolution depth: (NSUInteger)depth scale: (NSSize)scale;
- (id) initWithResolution: (NSSize)targetResolution depth: (NSUInteger)depth scale: (NSSize)scale;

//Return the width in bytes of one scanline in the buffer.
- (NSInteger) pitch;

//Returns the resolution of the frame scaled to the intended scale.
- (NSSize) scaledResolution;

//Return a read-only/mutable pointer to the frame's data.
- (const void *) bytes;
- (void *) mutableBytes;

@end