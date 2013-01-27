/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXVideoFrame.h"
#import "BXGeometry.h"

const CGFloat BX4by3AspectRatio = (CGFloat)320.0 / (CGFloat)240.0;

@interface BXVideoFrame ()
@property (readwrite, assign) NSUInteger numDirtyRegions;
@end

@implementation BXVideoFrame
@synthesize frameData = _frameData;
@synthesize size = _size;
@synthesize baseResolution = _baseResolution;
@synthesize bytesPerPixel = _bytesPerPixel;
@synthesize intendedScale = _intendedScale;
@synthesize numDirtyRegions = _numDirtyRegions;
@synthesize containsText = _containsText;


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


+ (id) frameWithSize: (NSSize)targetSize depth: (NSUInteger)depth
{
	return [[[self alloc] initWithSize: targetSize depth: depth] autorelease];
}

- (id) initWithSize: (NSSize)targetSize depth: (NSUInteger)depth
{
	if ((self = [super init]))
	{
		_size			= targetSize;
		_baseResolution	= targetSize;
		_bytesPerPixel	= depth;
		_intendedScale	= NSMakeSize(1.0f, 1.0f);
		
		NSUInteger requiredLength = _size.width * _size.height * _bytesPerPixel;
		_frameData = [[NSMutableData alloc] initWithLength: requiredLength];
	}
	return self;
}

- (void) dealloc
{
	[_frameData release], _frameData = nil;
	[super dealloc];
}

- (NSInteger) pitch
{
	return self.size.width * self.bytesPerPixel;
}

- (void) useAspectRatio: (CGFloat)aspectRatio
{
	self.intendedScale = [self.class scalingFactorForSize: self.size
                                            toAspectRatio: aspectRatio];
}

- (void) useSquarePixels
{
    self.intendedScale = NSMakeSize(1, 1);
}

- (NSSize) scaledSize
{
	return NSMakeSize(roundf(self.size.width    * self.intendedScale.width),
					  roundf(self.size.height   * self.intendedScale.height));
}

//IMPLEMENTATION NOTE: sometimes the buffer size that DOSBox is using
//is already a different aspect ratio from the original resolution,
//e.g. if it is performing pixel pre-doubling to correct for wacky video modes.
//This provides a corrected version of that resolution.
- (NSSize) effectiveResolution
{
	CGFloat bufferRatio		= aspectRatioOfSize(self.size);
	CGFloat resolutionRatio	= aspectRatioOfSize(self.baseResolution);
	
	return sizeToMatchRatio(self.baseResolution, bufferRatio, resolutionRatio < bufferRatio);
}

- (NSSize) scaledResolution
{
	NSSize effectiveResolution = self.effectiveResolution;
	return NSMakeSize(roundf(effectiveResolution.width	* self.intendedScale.width),
					  roundf(effectiveResolution.height	* self.intendedScale.height));
}

- (const void *) bytes
{
	return _frameData.bytes;
}

- (void *) mutableBytes
{
	return _frameData.mutableBytes;
}

#pragma mark Region-dirtying

- (void) setNeedsDisplayInRegion: (NSRange)range
{
    NSAssert(self.numDirtyRegions < MAX_DIRTY_REGIONS,
             @"setNeedsDisplayInRegion: called when the list of dirty regions is already full.");
    
    NSUInteger nextIndex = self.numDirtyRegions;
    _dirtyRegions[nextIndex] = range;
    
    self.numDirtyRegions = nextIndex + 1;
}

- (void) clearDirtyRegions
{
    self.numDirtyRegions = 0;
}

- (NSRange) dirtyRegionAtIndex: (NSUInteger)regionIndex
{
    NSAssert1(regionIndex < self.numDirtyRegions,
              @"dirtyRegionAtIndex: called with index out of range: %lu", (unsigned long)regionIndex);
    
    return _dirtyRegions[regionIndex];
}

@end
