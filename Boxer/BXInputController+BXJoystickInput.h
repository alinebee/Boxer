/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXJoysticks extends BXInputController with delegate methods for handling HID joystick input
//from BXJoystickController. These are translated into emulated joystick responses and passed
//to BXInputHandler.

#import "BXInputController.h"
#import "BXHIDEvent.h"

@interface BXInputController (BXJoystickInput) <BXHIDDeviceDelegate>

//Whether to use the standard (BXGameportPollBasedTiming) or strict (BXGameportClockBasedTiming) gameport timing mode.
@property (assign, nonatomic) BOOL strictGameportTiming;

//Which joystick type to use if supported, specified as a class conforming to the BXEmulatedJoystick protocol.
@property (copy, nonatomic) Class preferredJoystickType;

//The joystick types available to choose from, represented as an array of BXEmulatedJoystick-conforming classes.
//Used by the joystick type picker in the Inspector UI.
@property (readonly, retain, nonatomic) NSArray *availableJoystickTypes;


//The index of the currently selected joystick type from availableJoystickTypes.
//Used by the joystick type picker in the Inspector UI.
@property (assign, nonatomic) NSIndexSet *selectedJoystickTypeIndexes;


//Whether any HID joystick/gamepad controller devices are currently available.
@property (readonly, nonatomic) BOOL joystickControllersAvailable;

//Whether there are currently any supported controllers (either HID joysticks or Joypads)
//connected to the Mac. Used by the joystick type picker in the Inspector UI.
@property (readonly, nonatomic) BOOL controllersAvailable;

@end
