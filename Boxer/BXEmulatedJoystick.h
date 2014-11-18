/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXEmulatedJoystick and its subclasses represent different kinds of emulated gameport devices.
//They translate high-level device instructions into gameport signals.


#import <Cocoa/Cocoa.h>

#pragma mark -
#pragma mark Constants


//How long buttonPressed: should pretend to hold the specified button down before releasing.
#define BXJoystickButtonPressDefaultDuration 0.25


extern NSString * const BXAxisX;
extern NSString * const BXAxisY;
extern NSString * const BXAxisX2;
extern NSString * const BXAxisY2;
extern NSString * const BXAxisThrottle;
extern NSString * const BXAxisRudder;
extern NSString * const BXAxisWheel;
extern NSString * const BXAxisAccelerator;
extern NSString * const BXAxisBrake;


typedef NS_ENUM(NSUInteger, BXEmulatedJoystickButton) {
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


//Unlike BXHIDPOVxxx constants, these are bitmasks
typedef NS_OPTIONS(NSUInteger, BXEmulatedPOVDirection) {
	BXEmulatedPOVCentered	= 0,
	BXEmulatedPOVNorth		= 1U << 0,
	BXEmulatedPOVEast		= 1U << 1,
	BXEmulatedPOVSouth		= 1U << 2,
	BXEmulatedPOVWest		= 1U << 3,
    
    BXEmulatedPOVNorthEast  = BXEmulatedPOVNorth | BXEmulatedPOVEast,
    BXEmulatedPOVNorthWest  = BXEmulatedPOVNorth | BXEmulatedPOVWest,
    BXEmulatedPOVSouthEast  = BXEmulatedPOVSouth | BXEmulatedPOVEast,
    BXEmulatedPOVSouthWest  = BXEmulatedPOVSouth | BXEmulatedPOVWest
};


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

@protocol BXEmulatedJoystickUIDescriptor <NSObject>

//The localized name of this joystick type, for display in the UI.
+ (NSString *) localizedName;

//A localized extended description of this joystick type, for display in the UI along with the localized name.
+ (NSString *) localizedInformativeText;

//An icon representation of this joystick type, for display in the UI.
+ (NSImage *) icon;

@end

@protocol BXEmulatedJoystick <BXEmulatedJoystickUIDescriptor>

//Returns whether this joystick class needs 4-axis, 4-button joystick support in order to function correctly.
//Used for filtering out unsupported joysticks when running games that are known to have problems with them.
+ (BOOL) requiresFullJoystickSupport;

//The number of buttons and axes that joysticks of this type respond to.
+ (NSUInteger) numButtons;
+ (NSUInteger) numAxes;

//Called by BXEmulator when the device is plugged/unplugged.
- (void) didConnect;
- (void) willDisconnect;

//Release all joystick input, as if the user let go of the joystick. 
- (void) clearInput;

//Press/release the specified button.
- (void) buttonDown: (BXEmulatedJoystickButton)button;
- (void) buttonUp: (BXEmulatedJoystickButton)button;

//Report the current state of the specified button or axis.
- (BOOL) buttonIsDown: (BXEmulatedJoystickButton)button;

//Imitates the specified button being pressed and released after the default/specified delay.
- (void) buttonPressed: (BXEmulatedJoystickButton)button;
- (void) buttonPressed: (BXEmulatedJoystickButton)button forDuration: (NSTimeInterval)duration;


//Returns whether the joystick type supports the specified axis (as a property name).
+ (BOOL) instancesSupportAxis: (NSString *)axis;
- (BOOL) supportsAxis: (NSString *)axis;

//Sets/gets the current value for the specified axis property name.
//It is quicker and easier to use the direct axis properties where available (xAxis etc.)
- (float) positionForAxis: (NSString *)axis;
- (void) setPosition: (float)position forAxis: (NSString *)axis;


@optional

@property (assign) float xAxis;
@property (assign) float yAxis;
@property (assign) float x2Axis;
@property (assign) float y2Axis;

@end


@protocol BXEmulatedWheel <BXEmulatedJoystick>

@property (assign) float wheelAxis;
@property (assign) float acceleratorAxis;
@property (assign) float brakeAxis;

@end


@protocol BXEmulatedFlightstick <BXEmulatedJoystick>

//The number of POV switches the joystick responds to.
+ (NSUInteger) numPOVSwitches;

- (void) POV: (NSUInteger)POVNumber changedTo: (BXEmulatedPOVDirection)direction;

- (void) POV: (NSUInteger)POVNumber directionDown: (BXEmulatedPOVDirection)direction;
- (void) POV: (NSUInteger)POVNumber directionUp: (BXEmulatedPOVDirection)direction;

- (BOOL) POV: (NSUInteger)POVNumber directionIsDown: (BXEmulatedPOVDirection)direction;
- (BXEmulatedPOVDirection) directionForPOV: (NSUInteger)POVNumber;

@optional

@property (assign) float throttleAxis;
@property (assign) float rudderAxis;

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

+ (BOOL) instancesSupportAxis: (NSString *)axisName;
- (BOOL) supportsAxis: (NSString *)axisName;

- (float) positionForAxis: (NSString *)axis;
- (void) setPosition: (float)position forAxis: (NSString *)axis;
@end


@interface BX2AxisJoystick: BXBaseEmulatedJoystick <BXEmulatedJoystick>

@property (assign) float xAxis;
@property (assign) float yAxis;

@end


@interface BX4AxisJoystick: BX2AxisJoystick

@property (assign) float x2Axis;
@property (assign) float y2Axis;

@end


@interface BXCHFlightStickPro: BX2AxisJoystick <BXEmulatedFlightstick>
{
    BXEmulatedPOVDirection povDirectionMask;
}

@property (assign) float throttleAxis;
@property (assign) float rudderAxis;

@end

@interface BXCHCombatStick: BXCHFlightStickPro
{
    BXEmulatedPOVDirection pov2DirectionMask;
}
@end


@interface BXThrustmasterFCS: BX2AxisJoystick <BXEmulatedFlightstick>
{
    BXEmulatedPOVDirection povDirectionMask;
}

@property (assign) float rudderAxis;

@end


//Racing wheel with accelerator and brake on the Y axis
@interface BX2AxisWheel: BXBaseEmulatedJoystick <BXEmulatedWheel>
{
	float acceleratorComponent;
	float brakeComponent;
}
@end


//Racing wheel with accelerator on X2 axis and brake on Y2 axis,
//as well as combined input on the Y axis
@interface BX4AxisWheel: BX2AxisWheel
@end

