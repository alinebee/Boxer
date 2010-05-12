/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXFrameBuffer.h"


@implementation BXFrameBuffer
@synthesize resolution, bitDepth, intendedScale;

+ (id) bufferWithResolution: (NSSize)targetResolution depth: (NSUInteger)depth scale: (NSSize)scale
{
	return [[[self alloc] initWithResolution: targetResolution depth: depth scale: scale] autorelease];
}

- (id) initWithResolution: (NSSize)targetResolution depth: (NSUInteger)depth scale: (NSSize)scale
{
	if ((self = [super init]))
	{
		resolution		= targetResolution;
		intendedScale	= scale;
		bitDepth		= depth;

		NSUInteger requiredLength = resolution.width * resolution.height * bitDepth;
		frameData		= [[NSMutableData alloc] initWithCapacity: requiredLength];
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
	return resolution.width * bitDepth;
}

- (NSSize) scaledResolution
{
	return NSMakeSize(resolution.width	* intendedScale.width,
					  resolution.height	* intendedScale.height);
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