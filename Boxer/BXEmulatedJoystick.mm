/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXEmulatedJoystickPrivate.h"


#pragma mark -
#pragma mark Error constants

NSString * const BXEmulatedJoystickErrorDomain = @"BXEmulatedJoystickErrorDomain";
NSString * const BXEmulatedJoystickClassKey = @"BXEmulatedJoystickClassKey";


#pragma mark -
#pragma mark Implementations

@implementation BXBaseEmulatedJoystick

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

- (void) axis: (BXEmulatedJoystickAxis)axis movedTo: (float)position
{	
	//Clamp the position to fit within -1.0 to +1.0
	position = fmaxf(fminf(position, BXGameportAxisMax), BXGameportAxisMin);
	
	switch (axis)
	{
		case BXEmulatedJoystickAxisX:
			JOYSTICK_Move_X(BXGameportStick1, position);
			break;
		
		case BXEmulatedJoystickAxisY:
			JOYSTICK_Move_Y(BXGameportStick1, position);
			break;
			
		case BXEmulatedJoystick2AxisX:
			JOYSTICK_Move_X(BXGameportStick2, position);
			break;
			
		case BXEmulatedJoystick2AxisY:
			JOYSTICK_Move_Y(BXGameportStick2, position);
			break;
	}
}

- (float) axisPosition: (BXEmulatedJoystickAxis)axis
{
	switch (axis)
	{
		case BXEmulatedJoystickAxisX:
			return JOYSTICK_GetMove_X(BXGameportStick1);
			break;
		
		case BXEmulatedJoystickAxisY:
			return JOYSTICK_GetMove_Y(BXGameportStick1);
			break;
			
		case BXEmulatedJoystick2AxisX:
			return JOYSTICK_GetMove_X(BXGameportStick2);
			break;
			
		case BXEmulatedJoystick2AxisY:
			return JOYSTICK_GetMove_Y(BXGameportStick2);
			break;
		
		default:
			return 0.0f;
	}
}

- (void) axis: (BXEmulatedJoystickAxis)axis movedBy: (float)delta
{
	float oldPosition = [self axisPosition: axis];
	float newPosition = oldPosition + delta;
	
	[self axis: axis movedTo: newPosition];
}

- (void) buttonPressed: (BXEmulatedJoystickButton)button forDuration: (NSTimeInterval)duration
{
	[self buttonDown: button];
	[self performSelector: @selector(_releaseButton:)
			   withObject: [NSNumber numberWithUnsignedInteger: button]
			   afterDelay: duration];
}

- (void) buttonPressed: (BXEmulatedJoystickButton)button
{
	[self buttonPressed: button forDuration: BXJoystickButtonPressDurationDefault];
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

- (void) _releaseButton: (NSNumber *)button
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
	return NSLocalizedString(@"Joystick with 2 buttons and 2 axes. Suitable for most games.",
							 @"Localized informative text for generic 2-axis joystick type.");	
}

+ (NSImage *) icon
{
	return [NSImage imageNamed: @"4AxisJoystick"];
}

+ (BOOL) requiresFullJoystickSupport { return NO; }

- (NSUInteger) numButtons		{ return 2; }
- (NSUInteger) numAxes			{ return 2; }
- (NSUInteger) numPOVSwitches	{ return 0; }


- (void) xAxisMovedTo: (float)position	{ [self axis: BXEmulatedJoystickAxisX movedTo: position]; }
- (void) xAxisMovedBy: (float)delta		{ [self axis: BXEmulatedJoystickAxisX movedBy: delta]; }

- (void) yAxisMovedTo: (float)position	{ [self axis: BXEmulatedJoystickAxisY movedTo: position]; }
- (void) yAxisMovedBy: (float)delta		{ [self axis: BXEmulatedJoystickAxisY movedBy: delta]; }

@end


@implementation BX4AxisJoystick

+ (NSString *) localizedName
{
	return NSLocalizedString(@"Standard joystick/gamepad",
							 @"Localized name for generic 4-axis joystick type.");
}

+ (NSString *) localizedInformativeText
{
	return NSLocalizedString(@"4 buttons and up to 4 axes.\nSuitable for most games.",
							 @"Localized informative text for generic 4-axis joystick type.");	
}

+ (NSImage *) icon
{
	return [NSImage imageNamed: @"4AxisJoystick"];
}


+ (BOOL) requiresFullJoystickSupport { return YES; }

- (NSUInteger) numButtons		{ return 4; }
- (NSUInteger) numAxes			{ return 4; }
- (NSUInteger) numPOVSwitches	{ return 0; }

- (void) x2AxisMovedTo: (float)position	{ [self axis: BXEmulatedJoystick2AxisX movedTo: position]; }
- (void) x2AxisMovedBy: (float)delta	{ [self axis: BXEmulatedJoystick2AxisX movedBy: delta]; }

- (void) y2AxisMovedTo: (float)position	{ [self axis: BXEmulatedJoystick2AxisY movedTo: position]; }
- (void) y2AxisMovedBy: (float)delta	{ [self axis: BXEmulatedJoystick2AxisY movedBy: delta]; }

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

- (NSUInteger) numButtons		{ return 2; }
- (NSUInteger) numAxes			{ return 2; }
- (NSUInteger) numPOVSwitches	{ return 0; }

- (void) clearInput
{
	acceleratorComponent	= 0.0f;
	brakeComponent			= 0.0f;
	[super clearInput];
}

- (void) _syncYAxisPosition
{
	[self axis: BXEmulatedJoystickAxisY movedTo: (acceleratorComponent - brakeComponent)];
}

- (void) xAxisMovedTo: (float)position	{ [self axis: BXEmulatedJoystickAxisX movedTo: position]; }
- (void) xAxisMovedBy: (float)delta		{ [self axis: BXEmulatedJoystickAxisX movedBy: delta]; }

- (void) acceleratorMovedTo: (float)position
{
	position = ABS(position);
	acceleratorComponent = MIN(position, 1.0f);
	[self _syncYAxisPosition];
}

- (void) acceleratorMovedBy: (float)delta
{
	float newPosition = acceleratorComponent + delta;
	[self acceleratorMovedTo: newPosition];
}

- (void) brakeMovedTo: (float)position
{
	position = ABS(position);
	brakeComponent = MIN(position, 1.0f);
	[self _syncYAxisPosition];
}

- (void) brakeMovedBy: (float)delta
{
	float newPosition = brakeComponent + delta;
	[self brakeMovedTo: newPosition];
}

@end


@implementation BX3AxisWheel

+ (NSString *) localizedName
{
	return NSLocalizedString(@"Racing wheel",
							 @"Localized name for 3-axis racing wheel joystick type.");
}

+ (NSString *) localizedInformativeText
{
	return NSLocalizedString(@"4 buttons and gas/brake pedals\non separate axes.",
							 @"Localized informative text for 2-axis racing wheel.");	
}

+ (NSImage *) icon
{
	return [NSImage imageNamed: @"RacingWheel"];
}

+ (BOOL) requiresFullJoystickSupport { return YES; }


- (NSUInteger) numButtons		{ return 4; }
- (NSUInteger) numAxes			{ return 3; }
- (NSUInteger) numPOVSwitches	{ return 0; }

- (void) xAxisMovedTo: (float)position	{ [self axis: BXEmulatedJoystickAxisX movedTo: position]; }
- (void) xAxisMovedBy: (float)delta		{ [self axis: BXEmulatedJoystickAxisX movedBy: delta]; }

- (void) acceleratorMovedTo: (float)position
{
	position = ABS(position);
	[self axis: BXEmulatedJoystickAxisY2 movedTo: position];
}

- (void) acceleratorMovedBy: (float)delta
{
	float newPosition = [self axisPosition: BXEmulatedJoystickAxisY2] + delta;
	[self acceleratorMovedTo: newPosition];
}

- (void) brakeMovedTo: (float)position
{
	position = ABS(position);
	[self axis: BXEmulatedJoystickAxisX2 movedTo: position];
}

- (void) brakeMovedBy: (float)delta
{
	float newPosition = [self axisPosition: BXEmulatedJoystickAxisX2] + delta;
	[self brakeMovedTo: newPosition];
}

@end