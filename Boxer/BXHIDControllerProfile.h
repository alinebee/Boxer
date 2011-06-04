/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXControllerProfile is paired with a DDHidDevice and maps actual HID events from that 
//device into inputs on emulated input devices.
//The class can programmatically design a suitable control mapping for a specified HID device
//based on the device's elements; it is also intended to be subclassed for devices that require
//more specific translation.

//BXControllerProfile is controller- and joystick-specific and each emulation session maintains
//its own set of active controller profiles.


#import <Foundation/Foundation.h>
#import "BXHIDEvent.h"

@class DDHidJoystick;
@class DDHidElement;
@protocol BXEmulatedJoystick;
@protocol BXHIDInputBinding;


@interface BXHIDControllerProfile : NSObject
{
	DDHidJoystick *_HIDController;
	id <BXEmulatedJoystick> _emulatedJoystick;
	NSMutableDictionary *_bindings;
}

//The HID controller whose inputs we are converting from.
@property (retain, nonatomic) DDHidJoystick *HIDController;

//The emulated joystick whose inputs we are converting to.
@property (retain, nonatomic) id <BXEmulatedJoystick> emulatedJoystick;

//A dictionary of DDHidUsage -> BXHIDInputBinding mappings.
@property (readonly, nonatomic) NSMutableDictionary *bindings;

//Returns a BXControllerProfile that maps the specified HID controller
//to the specified emulated joystick.
+ (id) profileForHIDController: (DDHidJoystick *)HIDController
			toEmulatedJoystick: (id <BXEmulatedJoystick>)emulatedJoystick;

- (id) initWithHIDController: (DDHidJoystick *)HIDController
		  toEmulatedJoystick: (id <BXEmulatedJoystick>)emulatedJoystick;

//Set/get the specified input binding for the specified element usage
- (id <BXHIDInputBinding>) bindingForElement: (DDHidElement *)element;
- (void) setBinding: (id <BXHIDInputBinding>)binding forElement: (DDHidElement *)element;

@end
