/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXEmulatedJoystickPrivate.h"


#pragma mark -
#pragma mark Constants

//These correspond to property names in BXEmulatedJoystick protocols
NSString * const BXAxisX            = @"xAxis";
NSString * const BXAxisY            = @"yAxis";
NSString * const BXAxisX2           = @"x2Axis";
NSString * const BXAxisY2           = @"y2Axis";
NSString * const BXAxisThrottle     = @"throttleAxis";
NSString * const BXAxisRudder       = @"rudderAxis";
NSString * const BXAxisWheel        = @"wheelAxis";
NSString * const BXAxisAccelerator  = @"acceleratorAxis";
NSString * const BXAxisBrake        = @"brakeAxis";


#pragma mark -
#pragma mark Error constants

NSString * const BXEmulatedJoystickErrorDomain = @"BXEmulatedJoystickErrorDomain";
NSString * const BXEmulatedJoystickClassKey = @"BXEmulatedJoystickClassKey";


#pragma mark -
#pragma mark Implementations

@implementation BXBaseEmulatedJoystick

+ (BXEmulatedPOVDirection) closest4WayDirectionForPOV: (BXEmulatedPOVDirection)direction
                                          previousPOV: (BXEmulatedPOVDirection)oldDirection
{
    BXEmulatedPOVDirection normalizedDirection = direction;
	switch (normalizedDirection)
	{
		case BXEmulatedPOVNorthEast:
			normalizedDirection = (oldDirection == BXEmulatedPOVNorth) ? BXEmulatedPOVNorth : BXEmulatedPOVEast;
			break;
			
		case BXEmulatedPOVNorthWest:
			normalizedDirection = (oldDirection == BXEmulatedPOVNorth) ? BXEmulatedPOVNorth : BXEmulatedPOVWest;
			break;
			
		case BXEmulatedPOVSouthWest:
			normalizedDirection = (oldDirection == BXEmulatedPOVSouth) ? BXEmulatedPOVSouth : BXEmulatedPOVWest;
			break;
			
		case BXEmulatedPOVSouthEast:
			normalizedDirection = (oldDirection == BXEmulatedPOVSouth) ? BXEmulatedPOVSouth : BXEmulatedPOVEast;
			break;
	}
	return normalizedDirection;
}

- (void) clearInput
{
	JOYSTICK_Move_X(BXGameportStick1, BXGameportAxisCentered);
	JOYSTICK_Move_Y(BXGameportStick1, BXGameportAxisCentered);
	JOYSTICK_Move_X(BXGameportStick2, BXGameportAxisCentered);
	JOYSTICK_Move_Y(BXGameportStick2, BXGameportAxisCentered);
	
	[self setPressedButtons: BXNoGameportButtonsMask];
}

- (void) didConnect
{
	BOOL enableSecondJoystick = [[self class] requiresFullJoystickSupport];
	JOYSTICK_Enable(BXGameportStick1, YES);
	JOYSTICK_Enable(BXGameportStick2, enableSecondJoystick);
	//Reset all inputs to default position
	[self clearInput];
}

- (void) willDisconnect
{
	JOYSTICK_Enable(BXGameportStick1, NO);
	JOYSTICK_Enable(BXGameportStick2, NO);
}


- (void) buttonDown: (BXEmulatedJoystickButton)button
{
	[self setButton: button toState: YES];
}

- (void) buttonUp: (BXEmulatedJoystickButton)button
{
	[self setButton: button toState: NO];
}

- (BOOL) buttonIsDown: (BXEmulatedJoystickButton)button
{
	switch (button)
	{
		case BXEmulatedJoystickButton1:
			return JOYSTICK_GetButton(BXGameportStick1, BXGameportButton1);
			break;
			
		case BXEmulatedJoystickButton2:
			return JOYSTICK_GetButton(BXGameportStick1, BXGameportButton2);
			break;
			
		case BXEmulatedJoystickButton3:
			return JOYSTICK_GetButton(BXGameportStick2, BXGameportButton1);
			break;
			
		case BXEmulatedJoystickButton4:
			return JOYSTICK_GetButton(BXGameportStick2, BXGameportButton2);
			break;
			
		default:
			return NO;
	}
}

# pragma mark -
# pragma mark Emulated axis accessors

+ (BOOL) instancesSupportAxis: (NSString *)axisName
{
    return [self instancesRespondToSelector: NSSelectorFromString(axisName)];
}

- (BOOL) supportsAxis: (NSString *)axisName
{
    return [self respondsToSelector: NSSelectorFromString(axisName)];   
}

- (void) setPosition: (float)position forAxis: (NSString *)axis
{
    [self setValue: [NSNumber numberWithFloat: position] forKey: axis];
}

- (float) positionForAxis: (NSString *)axis
{
    return [[self valueForKey: axis] floatValue];
}


#pragma mark -
#pragma mark Gameport axis accessors (for internal use only)

- (void) setPosition: (float)position forGameportAxis: (BXGameportAxis)axis 
{	
	//Clamp the position to fit within -1.0 to +1.0
	position = fmaxf(fminf(position, BXGameportAxisMax), BXGameportAxisMin);
	
	switch (axis)
	{
		case BXGameportXAxis:
			JOYSTICK_Move_X(BXGameportStick1, position);
			break;
		
		case BXGameportYAxis:
			JOYSTICK_Move_Y(BXGameportStick1, position);
			break;
			
		case BXGameportX2Axis:
			JOYSTICK_Move_X(BXGameportStick2, position);
			break;
			
		case BXGameportY2Axis:
			JOYSTICK_Move_Y(BXGameportStick2, position);
			break;
	}
}

- (float) positionForGameportAxis: (BXGameportAxis)axis
{
	switch (axis)
	{
		case BXGameportXAxis:
			return JOYSTICK_GetMove_X(BXGameportStick1);
			break;
		
		case BXGameportYAxis:
			return JOYSTICK_GetMove_Y(BXGameportStick1);
			break;
			
		case BXGameportX2Axis:
			return JOYSTICK_GetMove_X(BXGameportStick2);
			break;
			
		case BXGameportY2Axis:
			return JOYSTICK_GetMove_Y(BXGameportStick2);
			break;
		
		default:
			return 0.0f;
	}
}

- (void) buttonPressed: (BXEmulatedJoystickButton)button forDuration: (NSTimeInterval)duration
{
	[self buttonDown: button];
	[self performSelector: @selector(releaseButton:)
			   withObject: [NSNumber numberWithUnsignedInteger: button]
			   afterDelay: duration];
}

- (void) buttonPressed: (BXEmulatedJoystickButton)button
{
	[self buttonPressed: button forDuration: BXJoystickButtonPressDefaultDuration];
}

- (void) setPressedButtons: (BXGameportButtonMask)buttonMask
{
	JOYSTICK_Button(BXGameportStick1, BXGameportButton1, (buttonMask & BXGameportButton1Mask));
	JOYSTICK_Button(BXGameportStick1, BXGameportButton2, (buttonMask & BXGameportButton2Mask));
	JOYSTICK_Button(BXGameportStick2, BXGameportButton1, (buttonMask & BXGameportButton3Mask));
	JOYSTICK_Button(BXGameportStick2, BXGameportButton2, (buttonMask & BXGameportButton4Mask));	
}

- (BXGameportButtonMask) pressedButtons
{
	BXGameportButtonMask buttonMask = BXNoGameportButtonsMask;
	
	if (JOYSTICK_GetButton(BXGameportStick1, BXGameportButton1)) buttonMask |= BXGameportButton1Mask;
	if (JOYSTICK_GetButton(BXGameportStick1, BXGameportButton2)) buttonMask |= BXGameportButton2Mask;
	if (JOYSTICK_GetButton(BXGameportStick2, BXGameportButton1)) buttonMask |= BXGameportButton3Mask;
	if (JOYSTICK_GetButton(BXGameportStick2, BXGameportButton2)) buttonMask |= BXGameportButton4Mask;
	
	return buttonMask;
}

#pragma mark -
#pragma mark Private methods

- (void) setButton: (BXEmulatedJoystickButton)button toState: (BOOL)pressed
{
	switch (button)
	{
		case BXEmulatedJoystickButton1:
			JOYSTICK_Button(BXGameportStick1, BXGameportButton1, pressed);
			break;
			
		case BXEmulatedJoystickButton2:
			JOYSTICK_Button(BXGameportStick1, BXGameportButton2, pressed);
			break;
			
		case BXEmulatedJoystickButton3:
			JOYSTICK_Button(BXGameportStick2, BXGameportButton1, pressed);
			break;
			
		case BXEmulatedJoystickButton4:
			JOYSTICK_Button(BXGameportStick2, BXGameportButton2, pressed);
			break;
	}
}

- (void) releaseButton: (NSNumber *)button
{
	[self buttonUp: [button unsignedIntegerValue]];
}

@end



@implementation BX2AxisJoystick

+ (NSString *) localizedName
{
	return NSLocalizedString(@"Standard joystick", @"Localized name for generic 2-axis joystick type.");
}

+ (NSString *) localizedInformativeText
{
	return NSLocalizedString(@"Joystick with 2 buttons and 2 axes.",
							 @"Localized informative text for generic 2-axis joystick type.");	
}

+ (NSImage *) icon
{
	return [NSImage imageNamed: @"4ButtonJoystick"];
}

+ (BOOL) requiresFullJoystickSupport { return NO; }

+ (NSUInteger) numButtons { return 2; }
+ (NSUInteger) numAxes { return 2; }

- (float) xAxis { return [self positionForGameportAxis: BXGameportXAxis]; }
- (float) yAxis { return [self positionForGameportAxis: BXGameportYAxis]; }

- (void) setXAxis: (float)position	{ [self setPosition: position forGameportAxis: BXGameportXAxis]; }
- (void) setYAxis: (float)position	{ [self setPosition: position forGameportAxis: BXGameportYAxis]; }

@end


@implementation BX4AxisJoystick

+ (NSString *) localizedName
{
	return NSLocalizedString(@"Standard joystick/gamepad",
							 @"Localized name for generic 4-axis joystick type.");
}

+ (NSString *) localizedInformativeText
{
	return NSLocalizedString(@"4 buttons and up to 4 generic axes.",
							 @"Localized informative text for generic 4-axis joystick type.");	
}

+ (NSImage *) icon
{
	return [NSImage imageNamed: @"4ButtonJoystick"];
}


+ (BOOL) requiresFullJoystickSupport { return YES; }

+ (NSUInteger) numButtons { return 4; }
+ (NSUInteger) numAxes { return 4; }

- (float) x2Axis    { return [self positionForGameportAxis: BXGameportX2Axis]; }
- (float) y2Axis    { return [self positionForGameportAxis: BXGameportY2Axis]; }

- (void) setX2Axis: (float)position { [self setPosition: position forGameportAxis: BXGameportX2Axis]; }
- (void) setY2Axis: (float)position { [self setPosition: position forGameportAxis: BXGameportY2Axis]; }

@end


@implementation BX2AxisWheel

+ (NSString *) localizedName
{
	return NSLocalizedString(@"Racing wheel",
							 @"Localized name for 2-axis racing wheel joystick type.");
}

+ (NSString *) localizedInformativeText
{
	return NSLocalizedString(@"2 buttons and gas/brake pedals on a single axis.",
							 @"Localized informative text for 2-axis racing wheel.");	
}

+ (NSImage *) icon
{
	return [NSImage imageNamed: @"RacingWheel"];
}

+ (BOOL) requiresFullJoystickSupport { return NO; }

+ (NSUInteger) numButtons { return 2; }
+ (NSUInteger) numAxes { return 2; }

- (void) clearInput
{
	acceleratorComponent	= 0.0f;
	brakeComponent			= 0.0f;
	[super clearInput];
}

- (void) _syncPedalAxisPosition
{
	[self setPosition: (brakeComponent - acceleratorComponent) forGameportAxis: BXWheelCombinedPedalAxis];
}

- (float) wheelAxis         { return [self positionForGameportAxis: BXWheelWheelAxis]; }
- (float) acceleratorAxis   { return acceleratorComponent; }
- (float) brakeAxis         { return brakeComponent; }

- (void) setWheelAxis: (float)position { [self setPosition: position forGameportAxis: BXWheelWheelAxis]; }
- (void) setAcceleratorAxis: (float)position
{
	position = ABS(position);
	acceleratorComponent = MIN(position, 1.0f);
	[self _syncPedalAxisPosition];
}
- (void) setBrakeAxis: (float)position
{
	position = ABS(position);
	brakeComponent = MIN(position, 1.0f);
	[self _syncPedalAxisPosition];
}

@end


@implementation BX4AxisWheel

+ (NSString *) localizedName
{
	return NSLocalizedString(@"Racing wheel",
							 @"Localized name for 4-axis racing wheel joystick type.");
}

+ (NSString *) localizedInformativeText
{
	return NSLocalizedString(@"4 buttons and gas/brake pedals\non separate axes.",
							 @"Localized informative text for 4-axis racing wheel.");	
}

+ (NSImage *) icon
{
	return [NSImage imageNamed: @"RacingWheel"];
}

+ (BOOL) requiresFullJoystickSupport { return YES; }

+ (NSUInteger) numButtons { return 4; }
+ (NSUInteger) numAxes { return 3; } //Wheel, brake and accelerator


//Note: the accelerator and brake still power the combined Y axis,
//as well as their own individual axes
- (void) setAcceleratorAxis: (float)position
{
	position = ABS(position);
	[self setPosition: -position forGameportAxis: BXWheelAcceleratorAxis];
    [super setAcceleratorAxis: position];
}

- (void) setBrakeAxis: (float)position
{
	position = ABS(position);
	[self setPosition: -position forGameportAxis: BXWheelBrakeAxis];
    [super setBrakeAxis: position];
}

@end