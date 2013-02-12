/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//The BXJoypadInput category handles JoyPad iOS app input passed on from BXJoypadController.

#import "BXInputController.h"
#import "JoypadSDK.h"

@interface BXInputController (BXJoypadInput) <JoypadDeviceDelegate, JoypadManagerDelegate>

//Returns a custom Joypad layout appropriate for the currently-selected joystick type.
@property (readonly, nonatomic) JoypadControllerLayout *currentJoypadLayout;

//Whether any joypad controller devices are currently available.
@property (readonly, nonatomic) BOOL joypadControllersAvailable;

@end
