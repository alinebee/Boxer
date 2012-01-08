/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXFrameBuffer is a renderer-agnostic framebuffer for DOSBox to draw frames into and for BXRenderer
//to draw as an OpenGL texture. It keeps track of the frame's resolution, bit depth and intended
//display scale.

#import <Foundation/Foundation.h>


//Aspect ratios with a difference smaller than this will be considered equivalent
#define BXIdenticalAspectRatioDelta	0.025f

//The maximum number of regions that can be flagged as dirty.
//This is set to the maximum vertical resolution expected from a DOS game.
#define MAX_DIRTY_REGIONS 1024

@interface BXFrameBuffer : NSObject
{
	NSMutableData *frameData;
	NSSize size;
	NSSize baseResolution;
	NSUInteger bitDepth;
	NSSize intendedScale;
    
    NSRange dirtyRegions[MAX_DIRTY_REGIONS];
    NSUInteger numDirtyRegions;
}

#pragma mark -
#pragma mark Properties


@property (readonly) NSSize size;
@property (readonly) NSUInteger bitDepth;

//The original game resolution represented by the framebuffer.
@property (assign) NSSize baseResolution;

//The scaling factor to apply to the framebuffer to reach the desired aspect ratio.
@property (assign) NSSize intendedScale;


//The base resolution corrected to the same aspect ratio as the underlying buffer size.
//Needed to account for pixel pre-doubling done by DOSBox.
@property (readonly) NSSize correctedResolution;

//The width in bytes of one scanline in the buffer.
@property (readonly) NSInteger pitch;

//The size of the frame scaled to the intended scale.
@property (readonly) NSSize scaledSize;

//The corrected resolution of the frame scaled to the intended scale.
@property (readonly) NSSize scaledResolution;

//Read-only/mutable pointers to the frame's data.
@property (readonly) const void *bytes;
@property (readonly) void *mutableBytes;

//The number of ranges of dirty lines. Incremented by setNeedsDisplayInRegion:
//and reset to 0 by clearDirtyRegions. See the dirty region functions below.
@property (readonly, assign) NSUInteger numDirtyRegions;


#pragma mark -
#pragma mark Class helpers

//Returns the scaling factor necessary to translate the specified size
//to match the specified aspect ratio
+ (NSSize) scalingFactorForSize: (NSSize)frameSize toAspectRatio: (CGFloat)aspectRatio;

#pragma mark -
#pragma mark Initializers

+ (id) bufferWithSize: (NSSize)targetSize depth: (NSUInteger)depth;
- (id) initWithSize: (NSSize)targetSize depth: (NSUInteger)depth;


#pragma mark -
#pragma mark Methods

//Sets the frame buffer to use the specified intended aspect ratio.
//This does not affect the underlying image data, just the intended scaled size and resolution.
- (void) useAspectRatio: (CGFloat)aspectRatio;

//Resets the aspect ratio of the framebuffer to use unscaled square pixels.
- (void) useSquarePixels;


#pragma mark -
#pragma mark Flagging scanlines of the frame as dirty.

- (void) setNeedsDisplayInRegion: (NSRange)range;
- (void) clearDirtyRegions;

- (NSRange) dirtyRegionAtIndex: (NSUInteger)index;

@end
