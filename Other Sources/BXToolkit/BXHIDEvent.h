/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXHIDEvent is a high-level replacement for DDHidEvent, modelled after NSEvents and passed
//to BXHIDDeviceDelegate delegates instead of the old DDHidLib delegate methods.
//(At some point this will be factored into DDHidLib to become the standard delegate interface.)


#import <DDHidLib/DDHidLib.h>

typedef enum {
	BXHIDUnknownEventType = -1,
	BXHIDKeyDown,
	BXHIDKeyUp,
	
	BXHIDMouseButtonDown,
	BXHIDMouseButtonUp,
	BXHIDMouseAxisChanged,
	
	BXHIDJoystickButtonDown,
	BXHIDJoystickButtonUp,
	BXHIDJoystickAxisChanged,
	BXHIDJoystickPOVSwitchChanged
} BXHIDEventType;

enum {
	BXHIDPOVCentered	= -1,
	BXHIDPOVNorth		= 0,
	BXHIDPOVNorthEast	= 45 * 100,
	BXHIDPOVEast		= 90 * 100,
	BXHIDPOVSouthEast	= 135 * 100,
	BXHIDPOVSouth		= 180 * 100,
	BXHIDPOVSouthWest	= 225 * 100,
	BXHIDPOVWest		= 270 * 100,
	BXHIDPOVNorthWest	= 315 * 100
};

typedef NSInteger BXHIDPOVSwitchDirection;


@interface BXHIDEvent : NSObject <NSCopying>
{
	BXHIDEventType _type;
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
@property (assign, nonatomic) BXHIDEventType type;

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

//The angle of the POV switch: normalized to within 0-35999 (clockwise from north) or BXHIDPOVCentered for centered.
@property (assign, nonatomic) NSInteger POVDirection;


#pragma mark -
#pragma mark Helper class methods

//Returns the closest BXHIDPOVSwitchDirection constant for the specified POV direction.
+ (BXHIDPOVSwitchDirection) closest8WayDirectionForPOV: (NSInteger)direction;

//Normalizes the specified direction to the closest cardinal (NSEW) BXHIDPOVSwitchDirection constant.
+ (BXHIDPOVSwitchDirection) closest4WayDirectionForPOV: (NSInteger)direction;

//Normalizes the specified direction to the closest cardinal (NSEW) BXHIDPOVSwitchDirection constant,
//taking into account which cardinal POV direction it was in before. This makes the corners
//'sticky' to avoid unintentional switching.
+ (BXHIDPOVSwitchDirection) closest4WayDirectionForPOV: (NSInteger)direction
										   previousPOV: (BXHIDPOVSwitchDirection)oldDirection;
@end


@protocol BXHIDDeviceDelegate <NSObject>

@optional
- (void) HIDMouseAxisChanged: (BXHIDEvent *)event;
- (void) HIDMouseButtonDown: (BXHIDEvent *)event;
- (void) HIDMouseButtonUp: (BXHIDEvent *)event;

- (void) HIDJoystickButtonDown: (BXHIDEvent *)event;
- (void) HIDJoystickButtonUp: (BXHIDEvent *)event;
- (void) HIDJoystickAxisChanged: (BXHIDEvent *)event;
- (void) HIDJoystickPOVSwitchChanged: (BXHIDEvent *)event;

- (void) HIDKeyDown: (BXHIDEvent *)event;
- (void) HIDKeyUp: (BXHIDEvent *)event;

@end


@interface NSObject (BXHIDEventDispatch)

//Returns the appropriate BXHIDDeviceDelegate selector to handle the specified HID event.
+ (SEL) delegateMethodForHIDEvent: (BXHIDEvent *)event;

//Dispatches the specified event to the appropriate BXHIDDeviceDelegate method.
- (void) dispatchHIDEvent: (BXHIDEvent *)event;

@end