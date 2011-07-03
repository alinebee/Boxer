/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXJoyPadController listens for and receives input from iOS devices running JoyPad.
//q.v. http://getjoypad.com/ and https://github.com/lzell/JoypadSDK#readme

#import <Foundation/Foundation.h>

@class JoypadManager;
@class JoypadControllerLayout;

@interface BXJoypadController : NSObject
{
    JoypadManager *joypadManager;
    BOOL suppressReconnectionNotifications;
    JoypadControllerLayout *currentLayout;
}
@property (readonly, nonatomic) JoypadManager *joypadManager;
@property (readonly, nonatomic) NSArray *joypadDevices;
@property (retain, nonatomic) JoypadControllerLayout *currentLayout;

@end
