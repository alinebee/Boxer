/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXJoystickController receives joystick input from connected controllers via the DDHidLib toolkit.
//These messages are then translated into a more Boxer-friendly format and sent onwards to the
//active DOS session's input controller.

#import <Foundation/Foundation.h>
#import "ADBHIDMonitor.h"

@class DDHidJoystick;

@interface BXJoystickController: NSObject <ADBHIDMonitorDelegate>
{
	ADBHIDMonitor *_HIDMonitor;
    NSArray *_recentHIDRemappers;
}
@property (readonly, retain, nonatomic) ADBHIDMonitor *HIDMonitor;

//An array of DDHIDJoystick instances for each joystick currently connected.
//Corresponds to hidMonitor matchedDevices.
@property (readonly, nonatomic) NSArray<DDHidJoystick*> *joystickDevices;

//An array of bundle identifiers of known HID remappers that were running last we checked.
//(This will be cached, and the cache cleared whenever Boxer loses the application focus.)
@property (readonly, retain, nonatomic) NSArray<NSString*> *recentHIDRemappers;


#pragma mark -
#pragma mark Helper class methods

/// Returns a set of bundle identifiers for known HID remapper tools that may
/// interfere with/affect Boxer's HID controller support.
+ (NSSet<NSString*> *) HIDRemapperIdentifiers;

/// Returns an array of bundle identifiers for known HID remappers that are currently running.
/// (This call may be expensive, so recentHIDRemappers should be used instead if
/// up-to-the-minute data is not needed.)
+ (NSArray<NSString*> *) runningHIDRemapperIdentifiers;

//Flushes our cache of known HID remappers. Called whenever Boxer loses then regains
//the application focus.
- (void) clearRecentHIDRemappers;

@end
