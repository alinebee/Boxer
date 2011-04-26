/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXEmulatedJoystick.h"
#import "BXHIDEvent.h"
#import "config.h"
#import "joystick.h"

enum
{
	BXGameportStick1,
	BXGameportStick2
};

enum
{	
	BXGameportButton1,
	BXGameportButton2
};

enum
{	
	BXGameportXAxis,
	BXGameportYAxis
};

enum
{
	BXNoGameportButtonsMask = 0,
	BXGameportButton1Mask = 1U << 0,
	BXGameportButton2Mask = 1U << 1,
	BXGameportButton3Mask = 1U << 2,
	BXGameportButton4Mask = 1U << 3,
	BXAllGameportButtonsMask = BXGameportButton1Mask | BXGameportButton2Mask | BXGameportButton3Mask | BXGameportButton4Mask
};

typedef NSUInteger BXGameportButtonMask;


#define BXGameportAxisMin -1.0f
#define BXGameportAxisMax 1.0f
#define BXGameportAxisCentered 0.0f


#pragma mark -
#pragma mark Private method declarations

@interface BXBaseEmulatedJoystick ()

//The pressed/released state of all emulated buttons
@property (assign) BXGameportButtonMask pressedButtons;

//Process the press/release of a joystick button.
- (void) _setButton: (BXEmulatedJoystickButton)button
			toState: (BOOL)pressed;

//Called by buttonPressed: after a delay to release the pressed button.
- (void) _releaseButton: (NSNumber *)button;
@end



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
	[self _setButton: button toState: YES];
}

- (void) buttonUp: (BXEmulatedJoystickButton)button
{
	[self _setButton: button toState: NO];
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
	switch (axis)
	{
		case BXEmulatedJoystickAxisX:
			return JOYSTICK_Move_X(BXGameportStick1, position);
			break;
		
		case BXEmulatedJoystickAxisY:
			return JOYSTICK_Move_Y(BXGameportStick1, position);
			break;
			
		case BXEmulatedJoystick2AxisX:
			return JOYSTICK_Move_X(BXGameportStick2, position);
			break;
			
		case BXEmulatedJoystick2AxisY:
			return JOYSTICK_Move_Y(BXGameportStick2, position);
			break;
	}
}

- (void) axis: (BXEmulatedJoystickAxis)axis movedBy: (float)delta
{
	float oldPosition = [self axisPosition: axis];
	
	//Apply the delta and clamp the result to fit within -1.0 to +1.0
	float newPosition = oldPosition + delta;
	newPosition = fmaxf(fminf(newPosition, BXGameportAxisMax), BXGameportAxisMin);
	
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

- (void) _setButton: (BXEmulatedJoystickButton)button toState: (BOOL)pressed
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


//FIXME: this is a naive implementation of the CH series' button-handling behaviour.
//Copy sdl_mapper's implementation to make it behave more accurately.
@implementation BXCHFlightStickPro

- (void) clearInput
{
	//Preserve the value of the throttle axis, because it does not snap back to center
	JOYSTICK_Move_X(BXGameportStick1, BXGameportAxisCentered);
	JOYSTICK_Move_Y(BXGameportStick1, BXGameportAxisCentered);
	JOYSTICK_Move_X(BXGameportStick2, BXGameportAxisCentered);
	
	[self setPressedButtons: BXNoGameportButtonsMask];
}

- (void) POVChangedTo: (BXEmulatedPOVDirection)direction
{
	BXEmulatedPOVDirection normalizedDirection = [BXHIDEvent closest4WayDirectionForPOV: direction];
	
	//Bitflags according to:
	//http://www.epanorama.net/documents/joystick/pc_special.html#chflightpro
	BXGameportButtonMask buttonMask = 0;
	switch (normalizedDirection)
	{
		case BXEmulatedPOVNorth:
			buttonMask = BXAllGameportButtonsMask;
			break;
			
		case BXEmulatedPOVEast:
			buttonMask = BXGameportButton1Mask | BXGameportButton2Mask | BXGameportButton4Mask;
			break;
		
		case BXEmulatedPOVSouth:
			buttonMask = BXGameportButton1Mask | BXGameportButton2Mask | BXGameportButton3Mask;
			break;
			
		case BXEmulatedPOVWest:
			buttonMask = BXGameportButton1Mask | BXGameportButton2Mask;
			break;
	}
	
	[self setPressedButtons: buttonMask];
}

- (void) throttleMovedTo: (float)position	{ [self axis: BXCHCombatStickThrottleAxis movedTo: position]; }
- (void) throttleMovedBy: (float)delta		{ [self axis: BXCHCombatStickThrottleAxis movedBy: delta]; }

- (void) rudderMovedTo: (float)position		{ [self axis: BXCHCombatStickRudderAxis movedTo: position]; }
- (void) rudderMovedBy: (float)delta		{ [self axis: BXCHCombatStickRudderAxis movedBy: delta]; }


#pragma mark -
#pragma mark Private methods

- (void) _setButton: (BXEmulatedJoystickButton)button toState: (BOOL)pressed
{
	//The CH Flightstick Pro could only represent one button-press at a time,
	//so unset all the other buttons before handling the new button-press
	[self setPressedButtons: BXNoGameportButtonsMask];
	
	if (pressed) [super _setButton: button toState: pressed];
}

@end


@implementation BXCHCombatStick

- (void) POV2ChangedTo: (BXEmulatedPOVDirection)direction
{
	BXEmulatedPOVDirection normalizedDirection = [BXHIDEvent closest4WayDirectionForPOV: direction];
	
	//Bitflags according to:
	//http://www.epanorama.net/documents/joystick/pc_special.html#chflightpro
	BXGameportButtonMask buttonMask = 0;
	switch (normalizedDirection)
	{
		case BXEmulatedPOVNorth:
			buttonMask = BXGameportButton2Mask | BXGameportButton3Mask | BXGameportButton4Mask;
			break;
			
		case BXEmulatedPOVEast:
			buttonMask = BXGameportButton2Mask | BXGameportButton4Mask;
			break;
		
		case BXEmulatedPOVSouth:
			buttonMask = BXGameportButton2Mask | BXGameportButton3Mask;
			break;
			
		case BXEmulatedPOVWest:
			buttonMask = BXGameportButton2Mask | BXGameportButton4Mask;
			break;
	}
	
	[self setPressedButtons: buttonMask];
}

#pragma mark -
#pragma mark Private methods

- (void) _setButton: (BXEmulatedJoystickButton)button toState: (BOOL)pressed
{
	//Clear active buttons first
	[super _setButton: button toState: pressed];
	
	if (pressed)
	{
		//Handle the additional 5 and 6 buttons
		switch (button)
		{
			case BXCHCombatStickButton5:
				[self setPressedButtons: BXGameportButton1Mask | BXGameportButton3Mask];
				break;
				
			case BXCHCombatStickButton6:
				[self setPressedButtons: BXGameportButton1Mask | BXGameportButton4Mask];
				break;
		}
	}
}

@end