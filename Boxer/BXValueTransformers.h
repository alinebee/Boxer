/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXValueTransformers defines various generic and not-so-generic value transformers for UI elements
//that use key-value binding.

#import <Cocoa/Cocoa.h>


#pragma mark -
#pragma mark Numeric transformers

//Takes a ratio from 0.0 to 1.0, and returns a ratio from 0.0 to 1.0 massaged with the specified easing method.
@interface BXEasingTransformer : NSValueTransformer
{
	NSAnimationCurve easingType;
}
@property (assign, nonatomic) NSAnimationCurve easingType;

- (id) initWithEasingType: (NSAnimationCurve)easingType;

- (NSNumber *)linearValue: (NSNumber *)value;
- (NSNumber *)easedOutValue: (NSNumber *)value;
- (NSNumber *)easedInValue: (NSNumber *)value;
- (NSNumber *)easedInOutValue: (NSNumber *)value;
@end

@interface BXRollingAverageTransformer : NSValueTransformer
{
	NSNumber *previousAverage;
	NSUInteger windowSize;
}
- (id) initWithWindowSize: (NSUInteger)size;
@end

//Returns the NSNumber equivalents of YES or NO based on whether an array's size is within the min and max range of the transformer.
//Registered as BXIsEmpty and BXIsNotEmpty by BXAppController, which are used for detecting whether an array is empty or not.
@interface BXArraySizeTransformer : NSValueTransformer
{
	NSUInteger minSize;
	NSUInteger maxSize;
}
- (id) initWithMinSize: (NSUInteger)min maxSize: (NSUInteger)max;
@end


//Simply inverts a number and returns it.
//Registered as BXFrameRateSliderTransformer by BXSession+BXEmulatorController, which is used for flipping the values of the framerate slider.
@interface BXInvertNumberTransformer: NSValueTransformer
@end


//Maps sets of numeric ranges (0-1000, 1001-2000 etc.) onto a 0.0->1.0 scale, with equal weight for each range.
//Registered as BXSpeedSliderTransformer by BXSession+BXEmulatorController, to maps our different CPU speed bands onto a single speed slider.
//NOTE: sliders using this transformer must have a range from 0.0 to 1.0.
@interface BXBandedValueTransformer: NSValueTransformer
{
	NSArray *bandThresholds;
}
@property (retain) NSArray *bandThresholds;
@property (readonly) NSNumber *minValue;
@property (readonly) NSNumber *maxValue;

- (id) initWithThresholds: (NSArray *)thresholds;
@end


#pragma mark -
#pragma mark String transformers

//Capitalises the first letter of a string
@interface BXCapitalizer: NSValueTransformer
@end

//Converts a POSIX file path into a lowercase filename
@interface BXDOSFilenameTransformer: NSValueTransformer
@end

//Converts a POSIX file path into OS X's display filename
@interface BXDisplayNameTransformer: NSValueTransformer
@end


//Converts a POSIX file path into a representation suitable for display.
@interface BXDisplayPathTransformer: NSValueTransformer
{
	NSString *joiner;
	NSString *ellipsis;
	NSUInteger maxComponents;
}
@property (copy) NSString *joiner;
@property (copy) NSString *ellipsis;
@property (assign) NSUInteger maxComponents;

- (id) initWithJoiner: (NSString *)joinString
			 ellipsis: (NSString *)ellipsisString
		maxComponents: (NSUInteger)components;

- (id) initWithJoiner: (NSString *)joinString
		maxComponents: (NSUInteger)components;
@end


#pragma mark -
#pragma mark Image transformers

//Resizes an NSImage to the target size.
@interface BXImageSizeTransformer: NSValueTransformer
{
	NSSize size;
}
@property (assign) NSSize size;

- (id) initWithSize: (NSSize)targetSize;

- (NSImage *) transformedValue: (NSImage *)image;

@end
