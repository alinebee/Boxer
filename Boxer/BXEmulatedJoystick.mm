/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXEmulatedJoystickPrivate.h"


#pragma mark -
#pragma mark Implementations

@implementation BXBaseEmulatedJoystick

- (void) didConnect
{
	JOYSTICK_Enable(BXGameportStick1, YES);
	JOYSTICK_Enable(BXGameportStick2, NO);
}

- (void) willDisconnect
{
	JOYSTICK_Enable(BXGameportStick1, NO);
	JOYSTICK_Enable(BXGameportStick2, NO);
}

- (void) clearInput
{
	JOYSTICK_Move_X(BXGameportStick1, BXGameportAxisCentered);
	JOYSTICK_Move_Y(BXGameportStick1, BXGameportAxisCentered);
	JOYSTICK_Move_X(BXGameportStick2, BXGameportAxisCentered);
	JOYSTICK_Move_Y(BXGameportStick2, BXGameportAxisCentered);
	
	[self setPressedButtons: BXNoGameportButtonsMask];
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

- (void) axis: (BXEmulatedJoystickAxis)axis movedBy: (float)delta
{
	float oldPosition = [self axisPosition: axis];
	float newPosition = oldPosition + delta;
	
	[self axis: axis movedTo: newPosition];
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

- (void) buttonPressed: (BXEmulatedJoystickButton)button
{
	[self buttonPressed: button forDuration: BXJoystickButtonPressDurationDefault];
}

- (void) buttonPressed: (BXEmulatedJoystickButton)button forDuration: (NSTimeInterval)duration
{
	[self buttonDown: button];
	[self performSelector: @selector(_releaseButton:)
			   withObject: [NSNumber numberWithUnsignedInteger: button]
			   afterDelay: duration];
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

- (void) xAxisMovedTo: (float)position	{ [self axis: BXEmulatedJoystickAxisX movedTo: position]; }
- (void) xAxisMovedBy: (float)delta		{ [self axis: BXEmulatedJoystickAxisX movedBy: delta]; }

- (void) yAxisMovedTo: (float)position	{ [self axis: BXEmulatedJoystickAxisY movedTo: position]; }
- (void) yAxisMovedBy: (float)delta		{ [self axis: BXEmulatedJoystickAxisY movedBy: delta]; }

@end


@implementation BX4AxisJoystick

- (void) didConnect
{
	JOYSTICK_Enable(BXGameportStick1, YES);
	JOYSTICK_Enable(BXGameportStick2, YES);
}

- (void) willDisconnect
{
	JOYSTICK_Enable(BXGameportStick1, NO);
	JOYSTICK_Enable(BXGameportStick2, NO);
}


- (void) x2AxisMovedTo: (float)position	{ [self axis: BXEmulatedJoystick2AxisX movedTo: position]; }
- (void) x2AxisMovedBy: (float)delta	{ [self axis: BXEmulatedJoystick2AxisX movedBy: delta]; }

- (void) y2AxisMovedTo: (float)position	{ [self axis: BXEmulatedJoystick2AxisY movedTo: position]; }
- (void) y2AxisMovedBy: (float)delta	{ [self axis: BXEmulatedJoystick2AxisY movedBy: delta]; }

@end
