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
@class BXEmulatedKeyboard;
@protocol BXEmulatedJoystick;
@protocol BXHIDInputBinding;

//Constants used by BXHIDControllerProfile.controllerStyle.
typedef enum {
    BXControllerStyleUnknown,
    BXControllerStyleJoystick,
    BXControllerStyleFlightstick,
    BXControllerStyleGamepad,
    BXControllerStyleWheel,
} BXControllerStyle;


@interface BXHIDControllerProfile : NSObject
{
	DDHidJoystick *_device;
	id <BXEmulatedJoystick> _emulatedJoystick;
	BXEmulatedKeyboard *_emulatedKeyboard;
	NSMutableDictionary *_bindings;
    BXControllerStyle _controllerStyle;
}

//The HID controller whose inputs we are converting from.
@property (retain, nonatomic) DDHidJoystick *device;

//The emulated joystick and keyboard whose inputs we are converting to.
@property (retain, nonatomic) id <BXEmulatedJoystick> emulatedJoystick;
@property (retain, nonatomic) BXEmulatedKeyboard *emulatedKeyboard;

//A dictionary of DDHidUsage -> BXHIDInputBinding mappings.
@property (readonly, retain, nonatomic) NSMutableDictionary *bindings;

//The style of this controller. Used for tweaking certain mapping behaviours.
@property (readonly, nonatomic) BXControllerStyle controllerStyle;

//Returns a BXControllerProfile that maps the specified HID controller
//to the specified emulated joystick.
+ (id) profileForHIDDevice: (DDHidJoystick *)device
          emulatedJoystick: (id <BXEmulatedJoystick>)joystick
                  keyboard: (BXEmulatedKeyboard *)keyboard;

- (id) initWithHIDDevice: (DDHidJoystick *)device
        emulatedJoystick: (id <BXEmulatedJoystick>)joystick
                keyboard: (BXEmulatedKeyboard *)keyboard;

//Set/get the specified input binding for the specified element usage
- (id <BXHIDInputBinding>) bindingForElement: (DDHidElement *)element;
- (void) setBinding: (id <BXHIDInputBinding>)binding
         forElement: (DDHidElement *)element;

@end
