/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXValueTransformers.h"
#import "NSString+BXPaths.h"

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

- (id) initWithThresholds: (NSArray *)thresholds
{
	if ((self = [super init]))
	{
		[self setBandThresholds: thresholds];
	}
	return self;
}


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
@synthesize joiner, ellipsis, maxComponents, useFilesystemDisplayPath;
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
		[self setUseFilesystemDisplayPath: YES];
	}
	return self;
}

- (id) initWithJoiner: (NSString *)joinString maxComponents: (NSUInteger)components
{
	return [self initWithJoiner: joinString
					   ellipsis: nil
				  maxComponents: components];
}

- (NSArray *) _componentsForPath: (NSString *)path
{		
	NSArray *components = nil;
	if (useFilesystemDisplayPath)
	{
		components	= [[NSFileManager defaultManager] componentsToDisplayForPath: path];
	}
	
	//If NSFileManager couldn't derive display names for this path,
	//or we disabled filesystem display paths, just use ordinary path components
	if (!components)
	{
		//Fix for 10.5 leaving in / when breaking up "C:/DOSPATH"
		components = [[path pathComponents] filteredArrayUsingPredicate: [NSPredicate predicateWithFormat: @"SELF != '/'"]];
	}
	return components;
}

- (NSString *) transformedValue: (NSString *)path
{
	if (!path) return nil;
	
	NSMutableArray *components = [[self _componentsForPath: path] mutableCopy];
	NSUInteger count = [components count];
	BOOL shortened = NO;

	if (maxComponents > 0 && count > maxComponents)
	{
		[components removeObjectsInRange: NSMakeRange(0, count - maxComponents)];
		shortened = YES;
	}
	
	NSString *displayPath = [components componentsJoinedByString: [self joiner]];
	if (shortened && [self ellipsis]) displayPath = [[self ellipsis] stringByAppendingString: displayPath];
	
	[components release];
	return displayPath;
}

- (void) dealloc
{
	[self setJoiner: nil],		[joiner release];
	[self setEllipsis: nil],	[ellipsis release];
	[super dealloc];
}
@end


@implementation BXIconifiedDisplayPathTransformer
@synthesize missingFileIcon, textAttributes, iconAttributes, iconSize, hideSystemRoots;

+ (Class) transformedValueClass { return [NSAttributedString class]; }

- (id) initWithJoiner: (NSString *)joinString
			 ellipsis: (NSString *)ellipsisString
		maxComponents: (NSUInteger)components
{
	if ((self = [super initWithJoiner: joinString ellipsis: ellipsisString maxComponents: components]))
	{
		[self setIconSize: NSMakeSize(16.0f, 16.0f)];
		[self setTextAttributes: [NSMutableDictionary dictionaryWithObjectsAndKeys:
								  [NSFont systemFontOfSize: 0], NSFontAttributeName,
								  nil]];
		
		[self setIconAttributes: [NSMutableDictionary dictionaryWithObjectsAndKeys:
								  [NSNumber numberWithFloat: -3.0f], NSBaselineOffsetAttributeName,
								  nil]];
	}
	return self;
}

- (void) dealloc
{
	[self setMissingFileIcon: nil], [missingFileIcon release];
	[self setTextAttributes: nil], [textAttributes release];
	[self setIconAttributes: nil], [iconAttributes release];
	[super dealloc];
}

- (NSAttributedString *) componentForPath: (NSString *)path
						  withDefaultIcon: (NSImage *)defaultIcon
{
	NSString *displayName;
	NSImage *icon;

	NSFileManager *manager = [NSFileManager defaultManager];
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	
	//Determine the display name and file icon, falling back on sensible defaults if the path doesn't yet exist
	if ([manager fileExistsAtPath: path])
	{
		displayName = [manager displayNameAtPath: path];
		icon = [workspace iconForFile: path];
		
		//FIXME: For regular folders that don't have a custom icon, NSWorkspace returns a folder icon with
		//the wrong 16x16 representation (a scaled-down copy of the 512x512 version).
		//See about substituting the NSFolder named image in this case.
	}
	else
	{
		displayName = [path lastPathComponent];
		//If no fallback icon was specified, use whatever icon NSWorkspace provides for nonexistent files.
		icon = (defaultIcon) ? defaultIcon : [workspace iconForFile: path];
	}
	
	NSTextAttachment *iconAttachment = [[NSTextAttachment alloc] init];
	NSTextAttachmentCell *iconCell = (NSTextAttachmentCell *)[iconAttachment attachmentCell];
	[iconCell setImage: icon];
	[[iconCell image] setSize: [self iconSize]];
	
	NSMutableAttributedString *component = [[NSAttributedString attributedStringWithAttachment: iconAttachment] mutableCopy];
	[component addAttributes: [self iconAttributes] range: NSMakeRange(0, [component length])];
	
	NSAttributedString *label = [[NSAttributedString alloc] initWithString: [@" " stringByAppendingString: displayName]
																attributes: [self textAttributes]];
	
	[component appendAttributedString: label];
	
	[iconAttachment release];
	[label release];
	
	return [component autorelease];
}

- (NSAttributedString *) transformedValue: (NSString *)path
{
	if (!path) return nil;
	
	NSMutableArray *components = [[path fullPathComponents] mutableCopy];
	
	//Bail out early if the path is empty
	if (![components count])
		return [[[NSAttributedString alloc] init] autorelease];
	
	//Hide common system root directories
	if ([self hideSystemRoots])
	{
		[components removeObject: @"/"];
		[components removeObject: @"/Users"];
		[components removeObject: @"/Volumes"];
	}
	
	NSMutableAttributedString *displayPath = [[NSMutableAttributedString alloc] init];
	NSAttributedString *attributedJoiner = [[NSAttributedString alloc] initWithString: [self joiner] attributes: [self textAttributes]];
	
	//Truncate the path with ellipses if there are too many components
	NSUInteger count = [components count];
	if (maxComponents > 0 && count > maxComponents)
	{
		[components removeObjectsInRange: NSMakeRange(0, count - maxComponents)];
		
		NSAttributedString *attributedEllipsis = [[NSAttributedString alloc] initWithString: [self ellipsis] attributes: [self textAttributes]];
		[displayPath appendAttributedString: attributedEllipsis];
		[attributedEllipsis release];
	}

	NSImage *folderIcon = [NSImage imageNamed: @"NSFolder"];
	NSUInteger i, numComponents = [components count];
	for (i = 0; i < numComponents; i++)
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		NSString *subPath = [components objectAtIndex: i];
		
		//Use regular folder icon for all missing path components except for the final one
		NSImage *defaultIcon = (i == numComponents - 1) ? [self missingFileIcon] : folderIcon;
		
		NSAttributedString *componentString = [self componentForPath: subPath withDefaultIcon: defaultIcon];
		
		if (i > 0) [displayPath appendAttributedString: attributedJoiner];
		[displayPath appendAttributedString: componentString];
		
		[pool release];
	}
	
	[attributedJoiner release];
	[components release];
	
	return [displayPath autorelease];
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
- (NSImage *) transformedValue: (NSImage *)image
{
	NSImage *resizedImage = [image copy];
	[resizedImage setSize: [self size]];
	return [resizedImage autorelease];
}

@end
