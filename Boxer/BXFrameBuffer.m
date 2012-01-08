/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXFrameBuffer.h"
#import "BXGeometry.h"

@interface BXFrameBuffer ()
@property (readwrite, assign) NSUInteger numDirtyRegions;
@end

@implementation BXFrameBuffer
@synthesize size, baseResolution, bitDepth, intendedScale;
@synthesize numDirtyRegions;


+ (NSSize) scalingFactorForSize: (NSSize)frameSize toAspectRatio: (CGFloat)aspectRatio
{
	CGFloat frameAspectRatio = aspectRatioOfSize(frameSize);
	
	//If the frame isn't naturally 4:3, work out the necessary scale corrections to make it so
	if (ABS(aspectRatio - frameAspectRatio) > BXIdenticalAspectRatioDelta)
	{
		BOOL preserveHeight = (frameAspectRatio < aspectRatio);
		NSSize intendedSize = sizeToMatchRatio(frameSize, aspectRatio, preserveHeight);
		
		NSAssert1(!NSEqualSizes(intendedSize, NSZeroSize),
				  @"Invalid frame size passed to [BXFrameBuffer scalingFactorForSize:toAspectRatio:] %@", NSStringFromSize(frameSize));
		
		
		//Calculate the difference between the intended size and the real size, and that is our scaling multiplier!
		return NSMakeSize(intendedSize.width / frameSize.width,
						  intendedSize.height / frameSize.height);
	}
	//Otherwise, no corrections are required
	else return NSMakeSize(1, 1);
}


+ (id) bufferWithSize: (NSSize)targetSize depth: (NSUInteger)depth
{
	return [[[self alloc] initWithSize: targetSize depth: depth] autorelease];
}

- (id) initWithSize: (NSSize)targetSize depth: (NSUInteger)depth
{
	if ((self = [super init]))
	{
		size			= targetSize;
		baseResolution	= targetSize;
		bitDepth		= depth;
		intendedScale	= NSMakeSize(1.0f, 1.0f);
		
		NSUInteger requiredLength = size.width * size.height * bitDepth;
		frameData = [[NSMutableData alloc] initWithCapacity: requiredLength];
	}
	return self;
}

- (void) dealloc
{
	[frameData release], frameData = nil;
	[super dealloc];
}

- (NSInteger) pitch
{
	return size.width * bitDepth;
}

- (void) useAspectRatio: (CGFloat)aspectRatio
{
	NSSize scale = [[self class] scalingFactorForSize: [self size] toAspectRatio: aspectRatio];
	[self setIntendedScale: scale];
}

- (void) useSquarePixels
{
	[self setIntendedScale: NSMakeSize(1, 1)];
}

- (NSSize) scaledSize
{
	return NSMakeSize(ceilf(size.width	* intendedScale.width),
					  ceilf(size.height	* intendedScale.height));
}

//IMPLEMENTATION NOTE: sometimes the buffer size that DOSBox is using
//is already a different aspect ratio from the original resolution,
//e.g. if it is performing pixel pre-doubling to correct for wacky video modes.
//This provides a corrected version of that resolution.
- (NSSize) correctedResolution
{
	CGFloat bufferRatio		= aspectRatioOfSize(size);
	CGFloat resolutionRatio	= aspectRatioOfSize(baseResolution);
	
	return sizeToMatchRatio(baseResolution, bufferRatio, resolutionRatio < bufferRatio);
}

- (NSSize) scaledResolution
{
	NSSize correctedResolution = [self correctedResolution];
	return NSMakeSize(ceilf(correctedResolution.width	* intendedScale.width),
					  ceilf(correctedResolution.height	* intendedScale.height));
}

- (const void *) bytes
{
	return [frameData bytes];
}

- (void *) mutableBytes
{
	return [frameData mutableBytes];
}

#pragma mark Region-dirtying

- (void) setNeedsDisplayInRegion: (NSRange)range
{
    NSAssert([self numDirtyRegions] < MAX_DIRTY_REGIONS, @"setNeedsDisplayInRegion: called when the list of dirty regions is already full.");
    
    NSUInteger nextIndex = [self numDirtyRegions];
    dirtyRegions[nextIndex] = range;
    
    [self setNumDirtyRegions: nextIndex + 1];
}

- (void) clearDirtyRegions
{
    [self setNumDirtyRegions: 0];
}

- (NSRange) dirtyRegionAtIndex: (NSUInteger)index
{
    NSAssert1(index < [self numDirtyRegions], @"dirtyRegionAtIndex: called with out of range index: %u", index);
    
    return dirtyRegions[index];
}

@end
