/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXEmulatedJoystick and its subclasses represent different kinds of emulated gameport devices.
//They translate high-level device instructions into gameport signals.


#import <Cocoa/Cocoa.h>

#pragma mark -
#pragma mark Constants


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
	
	BXCHCombatStickRudderAxis	= BXEmulatedJoystickAxisX2,
	BXCHCombatStickThrottleAxis	= BXEmulatedJoystickAxisY2,
	
	BXThrustmasterFCSRudderAxis		= BXEmulatedJoystickAxisX2,
	BXThrustmasterFCSHatAxis		= BXEmulatedJoystickAxisY2,
	BXThrustmasterWCSThrottleAxis	= BXEmulatedJoystickAxisY2
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


#pragma mark -
#pragma mark Error constants

extern NSString * const BXEmulatedJoystickErrorDomain;

//Class of joystick type, as an Obj-C Class object
extern NSString * const BXEmulatedJoystickClassKey;


enum {
	BXEmulatedJoystickInvalidType,		//Specified class was not a valid joystick class
	BXEmulatedJoystickUnsupportedType	//Current game does not support this joystick
};


#pragma mark -
#pragma mark Joystick protocols

@protocol BXEmulatedJoystick <NSObject>

@property (readonly, nonatomic) NSUInteger numButtons;
@property (readonly, nonatomic) NSUInteger numAxes;
@property (readonly, nonatomic) NSUInteger numPOVSwitches;

//The localized name of this joystick type, for display in the UI.
+ (NSString *) localizedName;

//A localized extended description of this joystick type, for display in the UI along with the localized name.
+ (NSString *) localizedInformativeText;

//An icon representation of this joystick type, for display in the UI.
+ (NSImage *) icon;


//Returns whether this joystick class needs 4-axis, 4-button joystick support in order to function correctly.
//Used for filtering out unsupported joysticks when running games that are known to have problems with them.
+ (BOOL) requiresFullJoystickSupport;


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


@optional

- (void) xAxisMovedTo: (float)position;
- (void) xAxisMovedBy: (float)delta;

- (void) yAxisMovedTo: (float)position;
- (void) yAxisMovedBy: (float)delta;

//4-axis joystick axes
- (void) x2AxisMovedTo: (float)position;
- (void) x2AxisMovedBy: (float)delta;

- (void) y2AxisMovedTo: (float)position;
- (void) y2AxisMovedBy: (float)delta;

//Wheel axes
- (void) wheelMovedTo: (float)direction;
- (void) wheelMovedBy: (float)delta;

- (void) acceleratorMovedTo: (float)position;
- (void) acceleratorMovedBy: (float)delta;

- (void) brakeMovedTo: (float)position;
- (void) brakeMovedBy: (float)delta;

//Flightstick axes and POV hats
- (void) throttleMovedTo: (float)position;
- (void) throttleMovedBy: (float)delta;

- (void) rudderMovedTo: (float)position;
- (void) rudderMovedBy: (float)delta;

- (void) POVChangedTo: (BXEmulatedPOVDirection)direction;
- (BXEmulatedPOVDirection) POVDirection;

- (void) POV2ChangedTo: (BXEmulatedPOVDirection)direction;
- (BXEmulatedPOVDirection) POV2Direction;

@end


#pragma mark -
#pragma mark Joystick classes

@interface BXBaseEmulatedJoystick: NSObject
- (void) clearInput;
- (void) didConnect;
- (void) willDisconnect;

- (void) buttonDown: (BXEmulatedJoystickButton)button;
- (void) buttonUp: (BXEmulatedJoystickButton)button;
- (BOOL) buttonIsDown: (BXEmulatedJoystickButton)button;
- (void) buttonPressed: (BXEmulatedJoystickButton)button;
- (void) buttonPressed: (BXEmulatedJoystickButton)button forDuration: (NSTimeInterval)duration;

- (void) axis: (BXEmulatedJoystickAxis)axis movedTo: (float)position;
- (void) axis: (BXEmulatedJoystickAxis)axis movedBy: (float)delta;
- (float) axisPosition: (BXEmulatedJoystickAxis)axis;
@end

@interface BX2AxisJoystick: BXBaseEmulatedJoystick <BXEmulatedJoystick>

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

@interface BXCHFlightStickPro: BX2AxisJoystick

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

@interface BXThrustmasterFCS: BX2AxisJoystick

- (void) POVChangedTo: (BXEmulatedPOVDirection)direction;
- (BXEmulatedPOVDirection) POVDirection;

- (void) rudderMovedTo: (float)position;
- (void) rudderMovedBy: (float)delta;

@end


//Racing wheel with accelerator and brake on the Y axis
@interface BX2AxisWheel: BXBaseEmulatedJoystick <BXEmulatedJoystick>
{
	float acceleratorComponent;
	float brakeComponent;
}
- (void) wheelMovedTo: (float)position;
- (void) wheelMovedBy: (float)delta;

- (void) acceleratorMovedTo: (float)position;
- (void) acceleratorMovedBy: (float)delta;

- (void) brakeMovedTo: (float)position;
- (void) brakeMovedBy: (float)delta;

@end


//Racing wheel with accelerator on X2 axis and brake on Y2 axis
@interface BX3AxisWheel: BXBaseEmulatedJoystick <BXEmulatedJoystick>

- (void) wheelMovedTo: (float)position;
- (void) wheelMovedBy: (float)delta;

- (void) acceleratorMovedTo: (float)position;
- (void) acceleratorMovedBy: (float)delta;

- (void) brakeMovedTo: (float)position;
- (void) brakeMovedBy: (float)delta;

@end
