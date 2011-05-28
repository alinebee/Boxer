/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXEmulatedJoystickPrivate.h"

//Button masks for CH POV hats and additional buttons, according to:
//http://www.epanorama.net/documents/joystick/pc_special.html#chflightpro
enum {
	BXCHPOVNorthMask	= BXAllGameportButtonsMask,
	BXCHPOVEastMask		= BXGameportButton1Mask | BXGameportButton2Mask | BXGameportButton4Mask,
	BXCHPOVSouthMask	= BXGameportButton1Mask | BXGameportButton2Mask | BXGameportButton3Mask,
	BXCHPOVWestMask		= BXGameportButton1Mask | BXGameportButton2Mask,
	
	BXCHPOV2NorthMask	= BXGameportButton2Mask | BXGameportButton3Mask | BXGameportButton4Mask,
	BXCHPOV2EastMask	= BXGameportButton2Mask | BXGameportButton4Mask,
	BXCHPOV2SouthMask	= BXGameportButton2Mask | BXGameportButton3Mask,
	BXCHPOV2WestMask	= BXGameportButton3Mask | BXGameportButton4Mask,
	
	BXCHCombatStickButton5Mask = BXGameportButton1Mask | BXGameportButton3Mask,
	BXCHCombatStickButton6Mask = BXGameportButton1Mask | BXGameportButton4Mask
};


@implementation BXCHFlightStickPro

+ (BOOL) requiresFullJoystickSupport { return YES; }

+ (NSString *) localizedName
{
	return NSLocalizedString(@"CH Flightstick Pro", @"Localized name for CH Flightstick Pro joystick type.");
}

- (NSUInteger) numButtons		{ return 4; }
- (NSUInteger) numAxes			{ return 4; }
- (NSUInteger) numPOVSwitches	{ return 1; }

- (void) clearInput
{
	JOYSTICK_Move_X(BXGameportStick1, BXGameportAxisCentered);
	JOYSTICK_Move_Y(BXGameportStick1, BXGameportAxisCentered);
	JOYSTICK_Move_X(BXGameportStick2, BXGameportAxisCentered);
	//Preserve the value of the throttle axis, because it does not snap back to center
	
	[self setPressedButtons: BXNoGameportButtonsMask];
}

- (void) POVChangedTo: (BXEmulatedPOVDirection)direction
{
	BXEmulatedPOVDirection normalizedDirection = [BXHIDEvent closest4WayDirectionForPOV: direction
																			previousPOV: [self POVDirection]];
	
	BXGameportButtonMask buttonMask = BXNoGameportButtonsMask;
	switch (normalizedDirection)
	{
		case BXEmulatedPOVNorth:
			buttonMask = BXCHPOVNorthMask;
			break;
			
		case BXEmulatedPOVEast:
			buttonMask = BXCHPOVEastMask;
			break;
		
		case BXEmulatedPOVSouth:
			buttonMask = BXCHPOVSouthMask;
			break;
			
		case BXEmulatedPOVWest:
			buttonMask = BXCHPOVWestMask;
			break;
	}
	
	[self setPressedButtons: buttonMask];
}


- (BXEmulatedPOVDirection) POVDirection
{
	switch ([self pressedButtons])
	{
		case BXCHPOVNorthMask:
			return BXEmulatedPOVNorth;
			break;
			
		case BXCHPOVEastMask:
			return BXEmulatedPOVEast;
			break;
			
		case BXCHPOVSouthMask:
			return BXEmulatedPOVSouth;
			break;
			
		case BXCHPOVWestMask:
			return BXEmulatedPOVWest;
			break;
			
		default:
			return BXEmulatedPOVCentered;
	}
}


- (void) throttleMovedTo: (float)position	{ [self axis: BXCHCombatStickThrottleAxis movedTo: position]; }
- (void) throttleMovedBy: (float)delta		{ [self axis: BXCHCombatStickThrottleAxis movedBy: delta]; }

- (void) rudderMovedTo: (float)position		{ [self axis: BXCHCombatStickRudderAxis movedTo: position]; }
- (void) rudderMovedBy: (float)delta		{ [self axis: BXCHCombatStickRudderAxis movedBy: delta]; }


- (void) setButton: (BXEmulatedJoystickButton)button toState: (BOOL)pressed
{
	//The CH Flightstick Pro could only represent one button-press at a time,
	//so unset all the other buttons before handling the new button-press
	[self setPressedButtons: BXNoGameportButtonsMask];
	
	if (pressed) [super setButton: button toState: pressed];
}


- (BOOL) buttonIsDown: (BXEmulatedJoystickButton)button
{
	//Because the CH series uses button bitmasks for POV hat states,
	//we have to be more precise about whether a button is pressed or not
	switch (button)
	{
		case BXEmulatedJoystickButton1:
			return [self pressedButtons] == BXGameportButton1Mask;
			break;
			
		case BXEmulatedJoystickButton2:
			return [self pressedButtons] == BXGameportButton2Mask;
			break;
			
		case BXEmulatedJoystickButton3:
			return [self pressedButtons] == BXGameportButton3Mask;
			break;
			
		case BXEmulatedJoystickButton4:
			return [self pressedButtons] == BXGameportButton4Mask;
			break;
			
		default:
			return NO;
	}
}

@end


@implementation BXCHCombatStick

+ (NSString *) localizedName
{
	return NSLocalizedString(@"CH F-16 Combatstick", @"Localized name for CH F-16 Combatstick joystick type.");
}

- (NSUInteger) numButtons		{ return 6; }
- (NSUInteger) numAxes			{ return 4; }
- (NSUInteger) numPOVSwitches	{ return 2; }


- (void) POV2ChangedTo: (BXEmulatedPOVDirection)direction
{
	BXEmulatedPOVDirection normalizedDirection = [BXHIDEvent closest4WayDirectionForPOV: direction
																			previousPOV: [self POV2Direction]];
	
	BXGameportButtonMask buttonMask = BXNoGameportButtonsMask;
	switch (normalizedDirection)
	{
		case BXEmulatedPOVNorth:
			buttonMask = BXCHPOV2NorthMask;
			break;
			
		case BXEmulatedPOVEast:
			buttonMask = BXCHPOV2EastMask;
			break;
		
		case BXEmulatedPOVSouth:
			buttonMask = BXCHPOV2SouthMask;
			break;
			
		case BXEmulatedPOVWest:
			buttonMask = BXCHPOV2WestMask;
			break;
	}
	
	[self setPressedButtons: buttonMask];
}

- (BXEmulatedPOVDirection) POV2Direction
{
	switch ([self pressedButtons])
	{
		case BXCHPOV2NorthMask:
			return BXEmulatedPOVNorth;
			break;
			
		case BXCHPOV2EastMask:
			return BXEmulatedPOVEast;
			break;
			
		case BXCHPOV2SouthMask:
			return BXEmulatedPOVSouth;
			break;
			
		case BXCHPOV2WestMask:
			return BXEmulatedPOVWest;
			break;
		
		default:
			return BXEmulatedPOVCentered;
	}
}

- (void) setButton: (BXEmulatedJoystickButton)button toState: (BOOL)pressed
{
	[super setButton: button toState: pressed];
	
	if (pressed)
	{
		//Handle the additional 5 and 6 buttons
		switch (button)
		{
			case BXCHCombatStickButton5:
				[self setPressedButtons: BXCHCombatStickButton5Mask];
				break;
				
			case BXCHCombatStickButton6:
				[self setPressedButtons: BXCHCombatStickButton6Mask];
				break;
		}
	}
}

- (BOOL) buttonIsDown: (BXEmulatedJoystickButton)button
{
	//Handle the additional 5 and 6 buttons
	switch (button)
	{
		case BXCHCombatStickButton5:
			return [self pressedButtons] == BXCHCombatStickButton5Mask;
			break;
			
		case BXCHCombatStickButton6:
			return [self pressedButtons] == BXCHCombatStickButton6Mask;
			break;
		
		default:
			return [super buttonIsDown: button];
	}
}

@end
