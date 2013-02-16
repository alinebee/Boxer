/*
 *  Copyright (c) 2013, Alun Bestor (alun.bestor@gmail.com)
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *		Redistributions of source code must retain the above copyright notice, this
 *	    list of conditions and the following disclaimer.
 *
 *		Redistributions in binary form must reproduce the above copyright notice,
 *	    this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 *	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 */


//ADBHIDEvent is a high-level replacement for DDHidEvent, modelled after NSEvents and passed
//to ADBHIDDeviceDelegate delegates instead of the old DDHidLib delegate methods.
//(At some point this will be factored into DDHidLib to become the standard delegate interface.)


#import <DDHidLib/DDHidLib.h>

typedef enum {
	ADBHIDUnknownEventType = -1,
	ADBHIDKeyDown,
	ADBHIDKeyUp,
	
	ADBHIDMouseButtonDown,
	ADBHIDMouseButtonUp,
	ADBHIDMouseAxisChanged,
	
	ADBHIDJoystickButtonDown,
	ADBHIDJoystickButtonUp,
	ADBHIDJoystickAxisChanged,
	ADBHIDJoystickPOVSwitchChanged
} ADBHIDEventType;

enum {
	ADBHIDPOVCentered	= -1,
	ADBHIDPOVNorth		= 0,
	ADBHIDPOVNorthEast	= 45 * 100,
	ADBHIDPOVEast		= 90 * 100,
	ADBHIDPOVSouthEast	= 135 * 100,
	ADBHIDPOVSouth		= 180 * 100,
	ADBHIDPOVSouthWest	= 225 * 100,
	ADBHIDPOVWest		= 270 * 100,
	ADBHIDPOVNorthWest	= 315 * 100
};

typedef NSInteger ADBHIDPOVSwitchDirection;


@interface ADBHIDEvent : NSObject <NSCopying>
{
	ADBHIDEventType _type;
	DDHidDevice *_device;
	DDHidElement *_element;
	DDHidJoystickStick *_stick;
	
	NSUInteger _stickNumber;
	NSUInteger _POVNumber;
	
	NSInteger _axisDelta;
	NSInteger _axisPosition;
	NSInteger _POVDirection;
}

#pragma mark -
#pragma mark Properties

//The type of the event, as one of the above constants.
@property (assign, nonatomic) ADBHIDEventType type;

//The device on which the element that triggered the event is located.
@property (retain, nonatomic) DDHidDevice *device;

//The element that triggered the event.
@property (retain, nonatomic) DDHidElement *element;

//The stick on which the element that triggered the event is located.
//Only relevant for joystick events.
@property (retain, nonatomic) DDHidJoystickStick *stick;

//The order of the stick in the device's enumeration order.
//Only relevant for joystick events.
@property (assign, nonatomic) NSUInteger stickNumber;

//The order of the POV switch in the device's enumeration order.
//Only relevant for POV events.
@property (assign, nonatomic) NSUInteger POVNumber;


//The following three variables all correspond to the usage ID of the element in question.

//The joystick or mouse axis that triggered the event.
//Corresponds to one of the kHIDUsage_GD_X, kHIDUsage_GD_Y etc. constants.
//(Note that for joysticks, this may be unique only in combination with stick.)
@property (readonly, nonatomic) NSUInteger axis;

//The device keycode that triggered the event.
//Corresponds to one of the kHIDUsage_KeyboardA etc. constants.
@property (readonly, nonatomic) NSUInteger key;

//The number of the button that triggered the event.
//Corresponds to one of the kHIDUsage_Button_1 etc. constants.
@property (readonly, nonatomic) NSUInteger buttonNumber;


//The absolute position of the axis: normalized to within -65535 to +65535 (where 0 is centered).
//Will be 0 if no absolute position is available or absolute position is meaningless (e.g. mouse axes).
@property (assign, nonatomic) NSInteger axisPosition;

//The delta of the axis since the last event. Will be 0 if no delta information is available.
@property (assign, nonatomic) NSInteger axisDelta;

//The angle of the POV switch: normalized to within 0-35999 (clockwise from north) or ADBHIDPOVCentered for centered.
@property (assign, nonatomic) NSInteger POVDirection;


#pragma mark -
#pragma mark Helper class methods

//Returns the closest ADBHIDPOVSwitchDirection constant for the specified POV direction.
+ (ADBHIDPOVSwitchDirection) closest8WayDirectionForPOV: (NSInteger)direction;

//Normalizes the specified direction to the closest cardinal (NSEW) ADBHIDPOVSwitchDirection constant.
+ (ADBHIDPOVSwitchDirection) closest4WayDirectionForPOV: (NSInteger)direction;

//Normalizes the specified direction to the closest cardinal (NSEW) ADBHIDPOVSwitchDirection constant,
//taking into account which cardinal POV direction it was in before. This makes the corners
//'sticky' to avoid unintentional switching.
+ (ADBHIDPOVSwitchDirection) closest4WayDirectionForPOV: (NSInteger)direction
										   previousPOV: (ADBHIDPOVSwitchDirection)oldDirection;
@end


@protocol ADBHIDDeviceDelegate <NSObject>

@optional
- (void) HIDMouseAxisChanged: (ADBHIDEvent *)event;
- (void) HIDMouseButtonDown: (ADBHIDEvent *)event;
- (void) HIDMouseButtonUp: (ADBHIDEvent *)event;

- (void) HIDJoystickButtonDown: (ADBHIDEvent *)event;
- (void) HIDJoystickButtonUp: (ADBHIDEvent *)event;
- (void) HIDJoystickAxisChanged: (ADBHIDEvent *)event;
- (void) HIDJoystickPOVSwitchChanged: (ADBHIDEvent *)event;

- (void) HIDKeyDown: (ADBHIDEvent *)event;
- (void) HIDKeyUp: (ADBHIDEvent *)event;

@end


@interface NSObject (ADBHIDEventDispatch)

//Returns the appropriate ADBHIDDeviceDelegate selector to handle the specified HID event.
+ (SEL) delegateMethodForHIDEvent: (ADBHIDEvent *)event;

//Dispatches the specified event to the appropriate ADBHIDDeviceDelegate method.
- (void) dispatchHIDEvent: (ADBHIDEvent *)event;

@end