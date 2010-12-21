/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXFrameBuffer.h"


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

- (NSSize) scaledResolution
{
	return NSMakeSize(ceilf(baseResolution.width	* intendedScale.width),
					  ceilf(baseResolution.height	* intendedScale.height));
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
