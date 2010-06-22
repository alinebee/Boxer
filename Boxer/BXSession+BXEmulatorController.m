/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXSession+BXEmulatorController.h"
#import "BXEmulator+BXShell.h"
#import "BXEmulator+BXPaste.h"
#import "BXValueTransformers.h"
#import "BXVideoFormatAlert.h"
#import "BXAppController.h"

#import "BXSessionWindowController+BXRenderController.h"

@implementation BXSession (BXEmulatorController)

//Speed-related class methods
//---------------------------

+ (void) initialize
{
	BXBandedValueTransformer *speedBanding		= [[BXBandedValueTransformer new] autorelease];
	BXInvertNumberTransformer *invertFramerate	= [[BXInvertNumberTransformer new] autorelease];
	
	NSArray *bands = [NSArray arrayWithObjects:
		[NSNumber numberWithInteger: BXMinSpeedThreshold],
		[NSNumber numberWithInteger: BX286SpeedThreshold],
		[NSNumber numberWithInteger: BX386SpeedThreshold],
		[NSNumber numberWithInteger: BX486SpeedThreshold],
		[NSNumber numberWithInteger: BXPentiumSpeedThreshold],
		[NSNumber numberWithInteger: BXMaxSpeedThreshold],
	nil];
	
	[speedBanding setBandThresholds: bands];
	
	[NSValueTransformer setValueTransformer: speedBanding forName: @"BXSpeedSliderTransformer"];
	[NSValueTransformer setValueTransformer: invertFramerate forName: @"BXFrameRateSliderTransformer"];
}

//We use different increment scales depending on the speed, to give more accuracy to low-speed adjustments
+ (NSInteger) incrementAmountForSpeed: (NSInteger)speed goingUp: (BOOL) increasing
{
	speed += increasing;
	if (speed > BXPentiumSpeedThreshold)	return BXPentiumSpeedIncrement;
	if (speed > BX486SpeedThreshold)		return BX486SpeedIncrement;
	if (speed > BX386SpeedThreshold)		return BX386SpeedIncrement;
	if (speed > BX286SpeedThreshold)		return BX286SpeedIncrement;
											return BXMinSpeedIncrement;
}

+ (NSInteger) snappedSpeed: (NSInteger) rawSpeed
{
	NSInteger increment = [self incrementAmountForSpeed: rawSpeed goingUp: YES];
	return (NSInteger)(round((CGFloat)rawSpeed / increment) * increment);
}

+ (NSString *) cpuClassFormatForSpeed: (NSInteger)speed
{
	if (speed >= BXPentiumSpeedThreshold)	return NSLocalizedString(@"Pentium speed (%u)",	@"Description for Pentium speed class. %u is cycles setting.");
	if (speed >= BX486SpeedThreshold)		return NSLocalizedString(@"486 speed (%u)",		@"Description for 80486 speed class. %u is cycles setting.");
	if (speed >= BX386SpeedThreshold)		return NSLocalizedString(@"386 speed (%u)",		@"Description for 80386 speed class. %u is cycles setting.");
	if (speed >= BX286SpeedThreshold)		return NSLocalizedString(@"AT speed (%u)",		@"Description for PC-AT 80286 speed class. %u is cycles setting.");
	
	return NSLocalizedString(@"XT speed (%u)",		@"Description for PC-XT 8088 speed class. %u is cycles setting.");
}


//Class methods affecting binding
//-------------------------------

+ (NSSet *) keyPathsForValuesAffectingSliderSpeed			{ return [NSSet setWithObjects: @"emulator.fixedSpeed", @"emulator.autoSpeed", nil]; }

+ (NSSet *) keyPathsForValuesAffectingSpeedDescription		{ return [NSSet setWithObject: @"sliderSpeed"]; }
+ (NSSet *) keyPathsForValuesAffectingFrameskipDescription	{ return [NSSet setWithObject: @"emulator.frameskip"]; }


- (IBAction) incrementFrameSkip: (id)sender
{
	
	NSNumber *newFrameskip = [NSNumber numberWithInteger: [[self emulator] frameskip] + 1];
	if ([self validateFrameskip: &newFrameskip error: nil])
		[[self emulator] setFrameskip: [newFrameskip integerValue]];
}

- (IBAction) decrementFrameSkip: (id)sender
{
	NSNumber *newFrameskip = [NSNumber numberWithInteger: [[self emulator] frameskip] - 1];
	if ([self validateFrameskip: &newFrameskip error: nil])
		[[self emulator] setFrameskip: [newFrameskip integerValue]];
}

- (BOOL) validateFrameskip: (id *)ioValue error: (NSError **)outError
{
	NSInteger theValue = [*ioValue integerValue];
	if		(theValue < 0)				*ioValue = [NSNumber numberWithInteger: 0];
	else if	(theValue > BXMaxFrameskip)	*ioValue = [NSNumber numberWithInteger: BXMaxFrameskip];
	return YES;
}


- (IBAction) incrementSpeed: (id)sender
{
	if ([self speedAtMaximum]) return;
	
	NSInteger currentSpeed = [[self emulator] fixedSpeed];
	
	if (currentSpeed >= BXMaxSpeedThreshold) [[self emulator] setAutoSpeed: YES];
	else
	{
		NSInteger increment	= [[self class] incrementAmountForSpeed: currentSpeed goingUp: YES];
		//This snaps the speed to the nearest increment rather than doing straight addition
		increment -= (currentSpeed % increment);
		
		//Validate our final value before assigning it
		NSNumber *newSpeed = [NSNumber numberWithInteger: currentSpeed + increment];
		if ([self validateSpeed: &newSpeed error: nil])
			[[self emulator] setFixedSpeed: [newSpeed integerValue]];
	}
}

- (IBAction) decrementSpeed: (id)sender
{
	if ([self speedAtMinimum]) return;
	
	if ([[self emulator] isAutoSpeed])
	{
		[[self emulator] setFixedSpeed: BXMaxSpeedThreshold];
	}
	else
	{
		NSInteger currentSpeed	= [[self emulator] fixedSpeed];
		NSInteger increment		= [[self class] incrementAmountForSpeed: currentSpeed goingUp: NO];
		//This snaps the speed to the nearest increment rather than doing straight subtraction
		NSInteger diff			= (currentSpeed % increment);
		if (diff) increment		= diff;
		
		//Validate our final value before assigning it
		NSNumber *newSpeed = [NSNumber numberWithInteger: currentSpeed - increment];
		if ([self validateSpeed: &newSpeed error: nil])
			[[self emulator] setFixedSpeed: [newSpeed integerValue]];
	}
}

- (BOOL) validateSpeed: (id *)ioValue error: (NSError **)outError
{
	NSInteger theValue = [*ioValue integerValue];
	if		(theValue < BXMinSpeedThreshold) *ioValue = [NSNumber numberWithInteger: BXMinSpeedThreshold];
	else if	(theValue > BXMaxSpeedThreshold) *ioValue = [NSNumber numberWithInteger: BXMaxSpeedThreshold];
	return YES;
}


- (BOOL) validateUserInterfaceItem: (id)theItem
{
	//All our actions depend on the emulator being active
	if (![[self emulator] isExecuting]) return NO;
	
	SEL theAction = [theItem action];
	BOOL hideItem;

	if (theAction == @selector(incrementSpeed:))		return ![self speedAtMaximum];
	if (theAction == @selector(decrementSpeed:))		return ![self speedAtMinimum];

	if (theAction == @selector(incrementFrameSkip:))	return ![self frameskipAtMaximum];
	if (theAction == @selector(decrementFrameSkip:))	return ![self frameskipAtMinimum];

	//Defined in BXFileManager
	if (theAction == @selector(openInDOS:))				return [[self emulator] isAtPrompt];

	if (theAction == @selector(paste:))	return [self canPaste];
	
	return [super validateUserInterfaceItem: theItem];
}


//Used to selectively enable/disable menu items by validateUserInterfaceItem
- (BOOL) speedAtMinimum		{ return ![[self emulator] isAutoSpeed] && [[self emulator] fixedSpeed] <= BXMinSpeedThreshold; }
- (BOOL) speedAtMaximum		{ return [[self emulator] isAutoSpeed]; }

- (BOOL) frameskipAtMinimum	{ return [[self emulator] frameskip] <= 0; }
- (BOOL) frameskipAtMaximum	{ return [[self emulator] frameskip] >= BXMaxFrameskip; }


//Handling paste
//--------------

- (IBAction) paste: (id)sender
{
	NSPasteboard *pboard = [NSPasteboard generalPasteboard];

	NSArray *acceptedPasteTypes = [NSArray arrayWithObjects: NSFilenamesPboardType, NSStringPboardType, nil];
	NSString *bestType = [pboard availableTypeFromArray: acceptedPasteTypes];
	NSString *pastedString;
	
	if (!bestType) return;
	if ([bestType isEqualToString: NSFilenamesPboardType])
	{
		NSArray *filePaths = [pboard propertyListForType: NSFilenamesPboardType];
		pastedString = [filePaths lastObject];
	}
	else pastedString = [pboard stringForType: NSStringPboardType];
	[[self emulator] handlePastedString: pastedString];
}

- (BOOL) canPaste
{
	NSPasteboard *pboard = [NSPasteboard generalPasteboard];

	NSArray *acceptedPasteTypes = [NSArray arrayWithObjects: NSFilenamesPboardType, NSStringPboardType, nil];
	NSString *bestType = [pboard availableTypeFromArray: acceptedPasteTypes];
	NSString *pastedString;
	
	if (!bestType) return NO;
	if ([bestType isEqualToString: NSFilenamesPboardType])
	{
		NSArray *filePaths = [pboard propertyListForType: NSFilenamesPboardType];
		pastedString = [filePaths lastObject];
	}
	else pastedString = [pboard stringForType: NSStringPboardType];
	return [[self emulator] canAcceptPastedString: pastedString];
}


//Wrapping CPU speed state
//------------------------
//We wrap the slider's speed value so that we can snap it to the nearest increment, and also switch to auto-throttled speed when it hits the highest speed setting

- (void) setSliderSpeed: (NSInteger)speed
{	
	//If we're at the maximum speed, bump it into auto-throttling mode
	if (speed >= BXMaxSpeedThreshold) [[self emulator] setAutoSpeed: YES];
	
	//Otherwise, set the fixed speed
	else [[self emulator] setFixedSpeed: speed];
}

- (NSInteger) sliderSpeed
{
	//Report the max fixed speed if we're in auto-throttling mode
	
	return ([[self emulator] isAutoSpeed]) ? BXMaxSpeedThreshold : [[self emulator] fixedSpeed];
}

//Snap fixed speed to even increments, unless the Option key is held down
- (BOOL)validateSliderSpeed: (id *)ioValue error: (NSError **)outError
{
	if (!([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask))
	{
		NSInteger speed			= [*ioValue integerValue]; 
		NSInteger snappedSpeed	= [[self class] snappedSpeed: speed];
		*ioValue = [NSNumber numberWithInteger: snappedSpeed];
	}
	return YES;
}


//Descriptions for emulation settings
//-----------------------------------

- (NSString *) speedDescription
{	
	if (![[self emulator] isExecuting]) return @"";

	if ([[self emulator] isAutoSpeed])
		return NSLocalizedString(@"Maximized speed", @"Description for current CPU speed when in automatic CPU throttling mode.");
	else
	{
		NSInteger speed		= [[self emulator] fixedSpeed];
		NSString *format	= [[self class] cpuClassFormatForSpeed: speed];
		return [NSString stringWithFormat: format, speed];
	}
}

- (NSString *) frameskipDescription
{
	if (![[self emulator] isExecuting]) return @"";
	
	NSString *format;
	NSUInteger frameskip = [[self emulator] frameskip]; 
	if (frameskip == 0)
			format = NSLocalizedString(@"Playing every frame",		@"Descriptive text for 0 frameskipping");
	else	format = NSLocalizedString(@"Playing 1 in %u frames",	@"Descriptive text for >0 frameskipping");
	
	return [NSString stringWithFormat: format, frameskip + 1];
}
@end