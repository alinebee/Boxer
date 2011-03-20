/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXSessionPrivate.h"
#import "BXEmulator+BXShell.h"
#import "BXEmulator+BXPaste.h"
#import "BXValueTransformers.h"
#import "BXVideoFormatAlert.h"
#import "BXAppController.h"
#import "BXVideoHandler.h"
#import "BXEmulatorConfiguration.h"
#import "BXInspectorController.h"

#import "BXDOSWindowController.h"
#import "BXInputController.h"


#pragma mark Private method declarations

@interface BXSession ()

//Whether we can accept pasted data from the specified pasteboard.
//Copy-paste is disabled, so this currently always returns NO.
- (BOOL) _canPasteFromPasteboard: (NSPasteboard *)pboard;

@end


@implementation BXSession (BXEmulatorControls)

#pragma mark -
#pragma mark Speed-related helper methods

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

#pragma mark -
#pragma mark Controlling CPU emulation

- (IBAction) togglePaused: (id)sender
{
	[self setManuallyPaused: ![self isManuallyPaused]];
}

- (NSUInteger) frameskip
{
	return [[emulator videoHandler] frameskip];
}

- (void) setFrameskip: (NSUInteger)frameskip
{
	[[emulator videoHandler] setFrameskip: frameskip];
	
	[gameSettings setObject: [NSNumber numberWithUnsignedInteger: frameskip] forKey: @"frameskip"];
}

- (BOOL) validateFrameskip: (id *)ioValue error: (NSError **)outError
{
	NSUInteger theValue = [*ioValue unsignedIntegerValue];
	if		(theValue < 0)				*ioValue = [NSNumber numberWithUnsignedInteger: 0];
	else if	(theValue > BXMaxFrameskip)	*ioValue = [NSNumber numberWithUnsignedInteger: BXMaxFrameskip];
	return YES;
}

- (IBAction) incrementFrameSkip: (id)sender
{
	NSNumber *newFrameskip = [NSNumber numberWithInteger: [self frameskip] + 1];
	if ([self validateFrameskip: &newFrameskip error: nil])
		[self setFrameskip: [newFrameskip integerValue]];
}

- (IBAction) decrementFrameSkip: (id)sender
{
	NSNumber *newFrameskip = [NSNumber numberWithInteger: [self frameskip] - 1];
	if ([self validateFrameskip: &newFrameskip error: nil])
		[self setFrameskip: [newFrameskip integerValue]];
}


- (BOOL) isAutoSpeed
{
	return [emulator isAutoSpeed];
}

- (void) setAutoSpeed: (BOOL)isAuto
{
	[emulator setAutoSpeed: isAuto];
	
	//Preserve changes to the speed settings
	[gameSettings setObject: [NSNumber numberWithBool: isAuto] forKey: @"autoSpeed"];
}

- (NSInteger) fixedSpeed
{
	return [emulator fixedSpeed];
}

- (void) setFixedSpeed: (NSInteger)fixedSpeed
{
	[emulator setFixedSpeed: fixedSpeed];
	
	[gameSettings setObject: [NSNumber numberWithInteger: fixedSpeed] forKey: @"fixedSpeed"];
}

- (BOOL) validateFixedSpeed: (id *)ioValue error: (NSError **)outError
{
	NSInteger theValue = [*ioValue integerValue];
	if		(theValue < BXMinSpeedThreshold) *ioValue = [NSNumber numberWithInteger: BXMinSpeedThreshold];
	else if	(theValue > BXMaxSpeedThreshold) *ioValue = [NSNumber numberWithInteger: BXMaxSpeedThreshold];
	return YES;
}

- (IBAction) incrementSpeed: (id)sender
{
	if ([self speedAtMaximum]) return;
	
	NSInteger currentSpeed = [self fixedSpeed];
	
	if (currentSpeed >= BXMaxSpeedThreshold) [self setAutoSpeed: YES];
	else
	{
		NSInteger increment	= [[self class] incrementAmountForSpeed: currentSpeed goingUp: YES];
		//This snaps the speed to the nearest increment rather than doing straight addition
		increment -= (currentSpeed % increment);
		
		//Validate our final value before assigning it
		NSNumber *newSpeed = [NSNumber numberWithInteger: currentSpeed + increment];
		if ([self validateFixedSpeed: &newSpeed error: nil])
			[self setFixedSpeed: [newSpeed integerValue]];
	}
}

- (IBAction) decrementSpeed: (id)sender
{
	if ([self speedAtMinimum]) return;
	
	if ([self isAutoSpeed])
	{
		[self setFixedSpeed: BXMaxSpeedThreshold];
	}
	else
	{
		NSInteger currentSpeed	= [self fixedSpeed];
		NSInteger increment		= [[self class] incrementAmountForSpeed: currentSpeed goingUp: NO];
		//This snaps the speed to the nearest increment rather than doing straight subtraction
		NSInteger diff			= (currentSpeed % increment);
		if (diff) increment		= diff;
		
		//Validate our final value before assigning it
		NSNumber *newSpeed = [NSNumber numberWithInteger: currentSpeed - increment];
		if ([self validateFixedSpeed: &newSpeed error: nil])
			[self setFixedSpeed: [newSpeed integerValue]];
	}
}


- (void) setSliderSpeed: (NSInteger)speed
{
	//If we're at the maximum speed, bump it into auto-throttling mode
	if (speed >= BXMaxSpeedThreshold) [self setAutoSpeed: YES];
	
	//Otherwise, set the fixed speed
	else [self setFixedSpeed: speed];
}

- (NSInteger) sliderSpeed
{
	//Report the max fixed speed if we're in auto-throttling mode
	return ([self isAutoSpeed]) ? BXMaxSpeedThreshold : [self fixedSpeed];
}

//Snap fixed speed to even increments, unless the Option key is held down
- (BOOL) validateSliderSpeed: (id *)ioValue error: (NSError **)outError
{
	if (!([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask))
	{
		NSInteger speed			= [*ioValue integerValue]; 
		NSInteger snappedSpeed	= [[self class] snappedSpeed: speed];
		*ioValue = [NSNumber numberWithInteger: snappedSpeed];
	}
	return YES;
}


- (BOOL) isDynamic	{ return [emulator coreMode] == BXCoreDynamic; }

- (void) setDynamic: (BOOL)dynamic
{
	[emulator setCoreMode: dynamic ? BXCoreDynamic : BXCoreNormal];
	
	[gameSettings setObject: [NSNumber numberWithInteger: [emulator coreMode]] forKey: @"coreMode"];
}


- (BOOL) validateUserInterfaceItem: (id)theItem
{
	//All our actions depend on the emulator being active
	if (![self isEmulating]) return NO;
	
	SEL theAction = [theItem action];
	
	if (theAction == @selector(incrementSpeed:))		return ![self speedAtMaximum];
	if (theAction == @selector(decrementSpeed:))		return ![self speedAtMinimum];

	if (theAction == @selector(incrementFrameSkip:))	return ![self frameskipAtMaximum];
	if (theAction == @selector(decrementFrameSkip:))	return ![self frameskipAtMinimum];

	//Defined in BXFileManager
	if (theAction == @selector(openInDOS:))				return [emulator isAtPrompt];
	if (theAction == @selector(relaunch:))				return [emulator isAtPrompt];
	
	if (theAction == @selector(paste:))
		return [self _canPasteFromPasteboard: [NSPasteboard generalPasteboard]];
	
	return [super validateUserInterfaceItem: theItem];
}

- (BOOL) validateMenuItem: (NSMenuItem *)theItem
{
	SEL theAction = [theItem action];
	NSString *title;
	
	if (theAction == @selector(togglePaused:))
	{
		if (![self isManuallyPaused])
			title = NSLocalizedString(@"Pause", @"Emulation menu option for pausing the emulator.");
		else
			title = NSLocalizedString(@"Resume", @"Emulation menu option for resuming from pause.");
		
		[theItem setTitle: title];
	
		return [self isEmulating];
	}
	
    return [super validateMenuItem: theItem];
}


//Used to selectively enable/disable menu items by validateUserInterfaceItem
- (BOOL) speedAtMinimum		{ return ![self isAutoSpeed] && [self fixedSpeed] <= BXMinSpeedThreshold; }
- (BOOL) speedAtMaximum		{ return [self isAutoSpeed]; }

- (BOOL) frameskipAtMinimum	{ return [self frameskip] <= 0; }
- (BOOL) frameskipAtMaximum	{ return [self frameskip] >= BXMaxFrameskip; }


#pragma mark -
#pragma mark Copy-paste

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
	[emulator handlePastedString: pastedString];
}

- (BOOL) _canPasteFromPasteboard: (NSPasteboard *)pboard 
{
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
	return [emulator canAcceptPastedString: pastedString];
}


#pragma mark -
#pragma mark Describing emulation state

- (NSString *) speedDescription
{	
	if (![self isEmulating]) return @"";

	if ([self isAutoSpeed])
		return NSLocalizedString(@"Maximized speed", @"Description for current CPU speed when in automatic CPU throttling mode.");
	else
	{
		NSInteger speed		= [self fixedSpeed];
		NSString *format	= [[self class] cpuClassFormatForSpeed: speed];
		return [NSString stringWithFormat: format, speed];
	}
}

- (NSString *) frameskipDescription
{
	if (![self isEmulating]) return @"";
	
	NSString *format;
	NSUInteger frameskip = [self frameskip]; 
	if (frameskip == 0)
			format = NSLocalizedString(@"Playing every frame",		@"Descriptive text for 0 frameskipping");
	else	format = NSLocalizedString(@"Playing 1 in %u frames",	@"Descriptive text for >0 frameskipping");
	
	return [NSString stringWithFormat: format, frameskip + 1];
}

+ (NSSet *) keyPathsForValuesAffectingSliderSpeed			{ return [NSSet setWithObjects: @"emulating", @"fixedSpeed", @"autoSpeed", @"dynamic", nil]; }
+ (NSSet *) keyPathsForValuesAffectingSpeedDescription		{ return [NSSet setWithObject: @"sliderSpeed"]; }
+ (NSSet *) keyPathsForValuesAffectingFrameskipDescription	{ return [NSSet setWithObjects: @"emulating", @"frameskip", nil]; }


#pragma mark -
#pragma mark Inspector actions

//These are passthroughs for when BXInspectorController isn't in the responder chain
- (IBAction) showGamePanel:		(id)sender	{ [[BXInspectorController controller] showGamePanel: sender]; }
- (IBAction) showCPUPanel:		(id)sender	{ [[BXInspectorController controller] showCPUPanel: sender]; }
- (IBAction) showDrivesPanel:	(id)sender	{ [[BXInspectorController controller] showDrivesPanel: sender]; }
- (IBAction) showMousePanel:	(id)sender	{ [[BXInspectorController controller] showMousePanel: sender]; }
@end
