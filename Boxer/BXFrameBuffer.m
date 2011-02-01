/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXFrameBuffer.h"
#import "BXGeometry.h"

@implementation BXFrameBuffer
@synthesize size, baseResolution, bitDepth, intendedScale;

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

- (NSSize) scaledSize
{
	return NSMakeSize(ceilf(size.width	* intendedScale.width),
					  ceilf(size.height	* intendedScale.height));
}

//IMPLEMENTATION NOTE: sometimes the buffer size that DOSBox is using
//is already a different aspect ratio from the original resolution,
//e.g. if it is performing pixel pre-doubling to correct for wacky video modes.
- (NSSize) correctedResolution
{
	CGFloat bufferRatio		= aspectRatioOfSize(size);
	CGFloat resolutionRatio	= aspectRatioOfSize(baseResolution);
	
	if (resolutionRatio > 1)
	{
		return NSMakeSize(baseResolution.width, baseResolution.width / bufferRatio);
	}
	else
	{
		return NSMakeSize(baseResolution.height * bufferRatio, baseResolution.height);
	}
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
@end
