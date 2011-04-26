/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXEmulatedJoystick and its subclasses represent different kinds of emulated gameport devices.
//They translate high-level device instructions into gameport signals.


#import <Foundation/Foundation.h>

//How long buttonPressed: should pretend to hold the specified button down before releasing.
#define BXJoystickButtonPressDurationDefault 0.25


enum {
	BXEmulatedJoystickUnknownAxis = 0,
	BXEmulatedJoystickAxisX,
	BXEmulatedJoystickAxisY,
	BXEmulatedJoystickAxisX2,
	BXEmulatedJoystickAxisY2,
	
	BXEmulatedJoystick2AxisX = BXEmulatedJoystickAxisX2,
	BXEmulatedJoystick2AxisY = BXEmulatedJoystickAxisY2,
	
	BXCHCombatStickRudderAxis = BXEmulatedJoystick2AxisX,
	BXThrustmasterFCSRudderAxis = BXEmulatedJoystick2AxisX,
	BXCHCombatStickThrottleAxis = BXEmulatedJoystick2AxisY
};

typedef NSUInteger BXEmulatedJoystickAxis;


enum {
	BXEmulatedJoystickUnknownButton = 0,
	BXEmulatedJoystickButton1,
	BXEmulatedJoystickButton2,
	BXEmulatedJoystickButton3,
	BXEmulatedJoystickButton4,
	
	BXCHCombatStickButton5,
	BXCHCombatStickButton6,
	
	BXEmulatedJoystick2Button1 = BXEmulatedJoystickButton3,
	BXEmulatedJoystick2Button2 = BXEmulatedJoystickButton4
};

typedef NSUInteger BXEmulatedJoystickButton;


//These correspond exactly to the BXHIDPOVxxx constants
enum {
	BXEmulatedPOVCentered	= -1,
	BXEmulatedPOVNorth		= 0,
	BXEmulatedPOVNorthEast	= 45 * 100,
	BXEmulatedPOVEast		= 90 * 100,
	BXEmulatedPOVSouthEast	= 135 * 100,
	BXEmulatedPOVSouth		= 180 * 100,
	BXEmulatedPOVSouthWest	= 225 * 100,
	BXEmulatedPOVWest		= 270 * 100,
	BXEmulatedPOVNorthWest	= 315 * 100
};

typedef NSInteger BXEmulatedPOVDirection;


@protocol BXEmulatedJoystick <NSObject>

//Called by BXEmulator when the device is plugged/unplugged.
- (void) didConnect;
- (void) willDisconnect;

//Release all joystick input, as if the user let go of the joystick. 
- (void) clearInput;

//Press/release the specified button.
- (void) buttonDown: (BXEmulatedJoystickButton)button;
- (void) buttonUp: (BXEmulatedJoystickButton)button;

//Imitates the specified button being pressed and released after the default/specified delay.
- (void) buttonPressed: (BXEmulatedJoystickButton)button;
- (void) buttonPressed: (BXEmulatedJoystickButton)button forDuration: (NSTimeInterval)duration;

//Move the specified axis to the specified position.
- (void) axis: (BXEmulatedJoystickAxis)axis movedTo: (float)position;

//Move the specified axis by the specified relative amount.
- (void) axis: (BXEmulatedJoystickAxis)axis movedBy: (float)delta;

//Report the current state of the specified button or axis.
- (BOOL) buttonIsDown: (BXEmulatedJoystickButton)button;
- (float) axisPosition: (BXEmulatedJoystickAxis)axis;

@end

@interface BXBaseEmulatedJoystick: NSObject <BXEmulatedJoystick>
@end

@interface BX2AxisJoystick: BXBaseEmulatedJoystick

- (void) xAxisMovedTo: (float)position;
- (void) xAxisMovedBy: (float)delta;

- (void) yAxisMovedTo: (float)position;
- (void) yAxisMovedBy: (float)delta;

@end

@interface BX4AxisJoystick: BX2AxisJoystick

- (void) x2AxisMovedTo: (float)position;
- (void) x2AxisMovedBy: (float)delta;

- (void) y2AxisMovedTo: (float)position;
- (void) y2AxisMovedBy: (float)delta;

@end

@interface BXCHFlightStickPro: BX4AxisJoystick

- (void) POVChangedTo: (BXEmulatedPOVDirection)direction;
- (BXEmulatedPOVDirection) POVDirection;

- (void) throttleMovedTo: (float)position;
- (void) throttleMovedBy: (float)delta;

- (void) rudderMovedTo: (float)position;
- (void) rudderMovedBy: (float)delta;

@end

@interface BXCHCombatStick: BXCHFlightStickPro

//Secondary hat switch
- (void) POV2ChangedTo: (BXEmulatedPOVDirection)direction;
- (BXEmulatedPOVDirection) POV2Direction;

@end

@interface BXThrustmaserFCS: BX4AxisJoystick

- (void) POVChangedTo: (BXEmulatedPOVDirection)direction;
- (BXEmulatedPOVDirection) POVDirection;

- (void) rudderMovedTo: (float)position;
- (void) rudderMovedBy: (float)delta;

@end