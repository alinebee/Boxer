/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "JoypadSDK.h"

//BXJoypadLayot is a base class for our custom joypad controller layouts.
//It mostly provides functions to register layouts for particular joystick types.

@protocol BXEmulatedJoystick;

@interface BXJoypadLayout : JoypadControllerLayout

//Register a Joypad controller layout as matching the specified joystick type.
//Used by BXJoypadLayout subclasses to register themeselves.
+ (void) registerLayout: (Class)layoutClass forJoystickType: (Class)joystickType;

//Returns the registered layout class appropriate for the specified joystick type,
//or nil if none has been registered.
+ (Class) layoutClassForJoystickType: (Class)joystickType;

//Returns a fully prepared custom joystick controller layout for the specified
//joystick type, suitable for passing to JoypadManager.
+ (JoypadControllerLayout *) layoutForJoystickType: (Class)joystickType;

//Returns an empty JoypadControllerLayout. Intended to be overridden by subclasses
//to provide fully-configured layouts.
//NOTE: we must provide instances of JoypadControllerLayout because the Joypad SDK
//does not support subclassing JoypadControllerLayout.
+ (JoypadControllerLayout *) layout;

@end
