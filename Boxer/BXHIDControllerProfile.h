/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Foundation/Foundation.h>
#import "ADBHIDEvent.h"

@class DDHidJoystick;
@class DDHidElement;
@class BXEmulatedKeyboard;
@protocol BXEmulatedJoystick;
@protocol BXHIDInputBinding;

/// Constants used by BXHIDControllerProfile.controllerStyle.
typedef NS_ENUM(NSInteger, BXControllerStyle) {
    BXControllerStyleUnknown,
    BXControllerStyleJoystick,
    BXControllerStyleFlightstick,
    BXControllerStyleGamepad,
    BXControllerStyleWheel,
};


/// \c BXControllerProfile is paired with a \c DDHidDevice and maps actual HID events from that 
/// device into inputs on emulated input devices.
/// The class can programmatically design a suitable control mapping for a specified HID device
/// based on the device's elements; it is also intended to be subclassed for devices that require
/// more specific translation.

/// \c BXControllerProfile is controller- and joystick-specific and each emulation session maintains
/// its own set of active controller profiles.
@interface BXHIDControllerProfile : NSObject
{
	DDHidJoystick *_device;
	id <BXEmulatedJoystick> _emulatedJoystick;
	BXEmulatedKeyboard *_emulatedKeyboard;
	NSMutableDictionary *_bindings;
    BXControllerStyle _controllerStyle;
}

/// The HID controller whose inputs we are converting from.
@property (strong, nonatomic) DDHidJoystick *device;

/// The emulated joystick and keyboard whose inputs we are converting to.
@property (strong, nonatomic) id <BXEmulatedJoystick> emulatedJoystick;
@property (strong, nonatomic) BXEmulatedKeyboard *emulatedKeyboard;

/// A dictionary of DDHidUsage -> BXHIDInputBinding mappings.
@property (readonly, strong, nonatomic) NSMutableDictionary *bindings;

/// The style of this controller. Used for tweaking certain mapping behaviours.
@property (readonly, nonatomic) BXControllerStyle controllerStyle;

/// Returns a BXControllerProfile that maps the specified HID controller
/// to the specified emulated joystick.
+ (id) profileForHIDDevice: (DDHidJoystick *)device
          emulatedJoystick: (id <BXEmulatedJoystick>)joystick
                  keyboard: (BXEmulatedKeyboard *)keyboard;

- (id) initWithHIDDevice: (DDHidJoystick *)device
        emulatedJoystick: (id <BXEmulatedJoystick>)joystick
                keyboard: (BXEmulatedKeyboard *)keyboard;

/// Set/get the specified input binding for the specified element usage
- (id <BXHIDInputBinding>) bindingForElement: (DDHidElement *)element;
- (void) setBinding: (id <BXHIDInputBinding>)binding
         forElement: (DDHidElement *)element;

@end
