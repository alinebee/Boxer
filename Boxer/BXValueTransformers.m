/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXValueTransformers.h"

#pragma mark -
#pragma mark Numeric transformers


@implementation BXRollingAverageTransformer

+ (Class) transformedValueClass			{ return [NSNumber class]; }
+ (BOOL) allowsReverseTransformation	{ return NO; }

- (id) initWithWindowSize: (NSUInteger)size
{
	if ((self = [super init]))
	{
		windowSize = size;
	}
	return self;
}
				  
- (void) dealloc
{
	[previousAverage release]; previousAverage = nil;
	[super dealloc];
}

- (NSNumber *) transformedValue: (NSNumber *)value
{
	NSNumber *newAverage;
	if (previousAverage)
	{
		CGFloat oldAvg	= [previousAverage floatValue],
				val		= [value floatValue],
				newAvg;
		
		newAvg = (val + (oldAvg * (windowSize - 1))) / windowSize;
		
		newAverage = [NSNumber numberWithFloat: newAvg];
	}
	else
	{
		newAverage = value;
	}
	
	[previousAverage release];
	previousAverage = [newAverage retain];
	return newAverage;
}

@end


@implementation BXArraySizeTransformer

+ (Class) transformedValueClass			{ return [NSNumber class]; }
+ (BOOL) allowsReverseTransformation	{ return NO; }

- (id) initWithMinSize: (NSUInteger)min maxSize: (NSUInteger)max
{
	if ((self = [super init]))
	{
		minSize = min;
		maxSize = max;
	}
	return self;
}

- (NSNumber *) transformedValue: (NSArray *)value
{
	NSUInteger count = [value count];
	BOOL isInRange = (count >= minSize && count <= maxSize);
	return [NSNumber numberWithBool: isInRange];
}
@end


@implementation BXInvertNumberTransformer
+ (Class) transformedValueClass			{ return [NSNumber class]; }
+ (BOOL) allowsReverseTransformation	{ return YES; }

- (NSNumber *) transformedValue:		(NSNumber *)value	{ return [NSNumber numberWithFloat: -[value floatValue]]; }
- (NSNumber *) reverseTransformedValue:	(NSNumber *)value	{ return [self transformedValue: value]; }
@end


@implementation BXBandedValueTransformer
@synthesize bandThresholds;

+ (Class) transformedValueClass			{ return [NSNumber class]; }
+ (BOOL) allowsReverseTransformation	{ return YES; }

- (NSNumber *) minValue	{ return [[self bandThresholds] objectAtIndex: 0]; }
- (NSNumber *) maxValue	{ return [[self bandThresholds] lastObject]; }

//Return the 0.0->1.0 ratio that corresponds to the specified banded value
- (NSNumber *) transformedValue: (NSNumber *)value
{
	CGFloat bandedValue = [value floatValue];

	//Save us some odious calculations by doing bounds checking up front
	if (bandedValue <= [[self minValue] floatValue]) return [NSNumber numberWithFloat: 0.0f];
	if (bandedValue >= [[self maxValue] floatValue]) return [NSNumber numberWithFloat: 1.0f];
	
	//Now get to work!
	NSArray *thresholds = [self bandThresholds];
	NSInteger numBands	= [thresholds count];
	NSInteger bandNum;
	
	//How much of the overall range each band occupies
	CGFloat bandSpread		= 1.0f / (numBands - 1);
	
	CGFloat upperThreshold	= 0.0f;
	CGFloat lowerThreshold	= 0.0f;
	CGFloat bandRange		= 0.0f;

	//Now figure out which band this value falls into
	for (bandNum = 1; bandNum < numBands; bandNum++)
	{
		upperThreshold = [[thresholds objectAtIndex: bandNum] floatValue];
		//We've found the band, stop looking now
		if (bandedValue < upperThreshold) break;
	}
	
	//Now populate the limits and range of the band
	lowerThreshold	= [[thresholds objectAtIndex: bandNum - 1] floatValue];
	bandRange		= upperThreshold - lowerThreshold;
	
	//Now work out where in the band we fall
	CGFloat offsetWithinBand	= bandedValue - lowerThreshold;
	CGFloat ratioWithinBand		= (bandRange != 0.0f) ? offsetWithinBand / bandRange : 0.0f;
	
	//Once we know the ratio within this band, we apply it to the band's own ratio to derive the full field ratio
	CGFloat fieldRatio = (bandNum - 1 + ratioWithinBand) * bandSpread;
	
	return [NSNumber numberWithFloat: fieldRatio];
}

//Return the banded value that corresponds to the input's 0.0->1.0 ratio
- (NSNumber *) reverseTransformedValue: (NSNumber *)value
{
	CGFloat fieldRatio = [value floatValue];
	
	//Save us some odious calculations by doing bounds checking up front
	if		(fieldRatio >= 1.0f) return [self maxValue];
	else if	(fieldRatio <= 0.0f) return [self minValue];
	
	//Now get to work!
	NSArray *thresholds = [self bandThresholds];
	NSInteger numBands	= [thresholds count];
	NSInteger bandNum;
	
	//How much of the overall range each band occupies
	CGFloat bandSpread	= 1.0f / (numBands - 1);
	
	CGFloat upperThreshold, lowerThreshold, bandRange;
	
	//First work out which band the field's ratio falls into
	bandNum = (NSInteger)floor(fieldRatio / bandSpread);
	
	//Grab the upper and lower points of this band's range
	lowerThreshold	= [[thresholds objectAtIndex: bandNum]		floatValue];
	upperThreshold	= [[thresholds objectAtIndex: bandNum + 1]	floatValue];
	bandRange		= upperThreshold - lowerThreshold;
	
	//Work out where within the band our current ratio falls
	CGFloat bandRatio			= bandNum * bandSpread;
	CGFloat ratioWithinBand		= (fieldRatio - bandRatio) / bandSpread;
	
	//From that we can calculate our banded value! hurrah
	CGFloat bandedValue			= lowerThreshold + (ratioWithinBand * bandRange);
	
	return [NSNumber numberWithFloat: bandedValue];
}
@end





#pragma mark -
#pragma mark String transformers

@implementation BXCapitalizer
+ (Class) transformedValueClass			{ return [NSString class]; }
+ (BOOL) allowsReverseTransformation	{ return NO; }

- (NSString *) transformedValue: (NSString *)text
{
	return [[[text substringToIndex: 1] capitalizedString] stringByAppendingString: [text substringFromIndex: 1]];
}
@end

@implementation BXDOSFilenameTransformer
+ (Class) transformedValueClass			{ return [NSString class]; }
+ (BOOL) allowsReverseTransformation	{ return NO; }

- (NSString *) transformedValue: (NSString *)path	{ return [[path lastPathComponent] lowercaseString]; }
@end


@implementation BXDisplayNameTransformer
+ (Class) transformedValueClass			{ return [NSString class]; }
+ (BOOL) allowsReverseTransformation	{ return NO; }

- (NSString *) transformedValue: (NSString *)path
{
	NSFileManager *manager	= [NSFileManager defaultManager];
	return [manager displayNameAtPath: path];
}
@end


@implementation BXDisplayPathTransformer
@synthesize joiner, ellipsis, maxComponents;
+ (Class) transformedValueClass			{ return [NSString class]; }
+ (BOOL) allowsReverseTransformation	{ return NO; }

- (id) initWithJoiner: (NSString *)joinString
			 ellipsis: (NSString *)ellipsisString
		maxComponents: (NSUInteger)components
{
	if ((self = [super init]))
	{
		[self setJoiner: joinString];
		[self setEllipsis: ellipsisString];
		[self setMaxComponents: components];
	}
	return self;	
}

- (id) initWithJoiner: (NSString *)joinString maxComponents: (NSUInteger)components
{
	return [self initWithJoiner: joinString
					   ellipsis: nil
				  maxComponents: components];
}

- (NSString *) transformedValue: (NSString *)path
{
	NSFileManager *manager	= [NSFileManager defaultManager];
	NSArray *components		= [manager componentsToDisplayForPath: path];
	NSUInteger count		= [components count];
	BOOL shortened = NO;
	
	if (maxComponents > 0 && count > maxComponents)
	{
		components = [components subarrayWithRange: NSMakeRange(count - maxComponents, maxComponents)];
		shortened = YES;
	}
	
	NSString *displayPath = [components componentsJoinedByString: [self joiner]];
	if (shortened && [self ellipsis]) displayPath = [[self ellipsis] stringByAppendingString: displayPath];
	return displayPath;
}

- (void) dealloc
{
	[self setJoiner: nil],		[joiner release];
	[self setEllipsis: nil],	[ellipsis release];
	[super dealloc];
}
@end

#pragma mark -
#pragma mark Image transformers

@implementation BXImageSizeTransformer
@synthesize size;

+ (Class) transformedValueClass			{ return [NSImage class]; }
+ (BOOL) allowsReverseTransformation	{ return NO; }

- (id) initWithSize: (NSSize)targetSize
{
	if ((self = [super init]))
	{
		[self setSize: targetSize];
	}
	return self;
}
- (NSImage *) transformedValue: (NSImage *)image	{ [image setSize: [self size]]; return image; }

@end
