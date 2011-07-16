/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXUsageExtensions adds helper methods to DDHidUsage for comparing HID usages
//and translating them to/from string constants. It also provides shortcut functions
//for retrieving usages, to allow them to be treated like language-level constructs.


#import <DDHidLib/DDHidLib.h>
#import <IOKit/hid/IOHIDLib.h>


#pragma mark -
#pragma mark Constants

//Named usages, for use with DDHidUsage +usageWithName: and BXUsageFromName
extern NSString * const BXUsageJoystick;
extern NSString * const BXUsageGamepad;
extern NSString * const BXUsageMouse;
extern NSString * const BXUsageKeyboard;


extern NSString * const BXUsageXAxis;
extern NSString * const BXUsageYAxis;
extern NSString * const BXUsageZAxis;
extern NSString * const BXUsageRxAxis;
extern NSString * const BXUsageRyAxis;
extern NSString * const BXUsageRzAxis;
extern NSString * const BXUsageSliderAxis;
extern NSString * const BXUsageWheelAxis;
extern NSString * const BXUsageDialAxis;

extern NSString * const BXUsageSteeringAxis;
extern NSString * const BXUsageShifterAxis;
extern NSString * const BXUsageAcceleratorAxis;
extern NSString * const BXUsageBrakeAxis;
extern NSString * const BXUsageClutchAxis;

extern NSString * const BXUsageAileronAxis;
extern NSString * const BXUsageElevatorAxis;
extern NSString * const BXUsageRudderAxis;
extern NSString * const BXUsageThrottleAxis;

extern NSString * const BXUsageHatSwitch;

extern NSString * const BXUsageButton1;
extern NSString * const BXUsageButton2;
extern NSString * const BXUsageButton3;
extern NSString * const BXUsageButton4;
extern NSString * const BXUsageButton5;
extern NSString * const BXUsageButton6;
extern NSString * const BXUsageButton7;
extern NSString * const BXUsageButton8;
extern NSString * const BXUsageButton9;
extern NSString * const BXUsageButton10;
extern NSString * const BXUsageButton11;
extern NSString * const BXUsageButton12;
extern NSString * const BXUsageButton13;
extern NSString * const BXUsageButton14;
extern NSString * const BXUsageButton15;
extern NSString * const BXUsageButton16;
extern NSString * const BXUsageButton17;
extern NSString * const BXUsageButton18;
extern NSString * const BXUsageButton19;
extern NSString * const BXUsageButton20;


#pragma mark -
#pragma mark Shortcut functions

//Shortcut function for returning an autoreleased usage with the specified page and ID.
DDHidUsage * BXUsageFromID(unsigned int usagePage, unsigned int usageID);
//Shortcut function for returning an autoreleased usage with the specified constant name.
DDHidUsage * BXUsageFromName(NSString *usageName);


#pragma mark -
#pragma mark Interface declaration

@interface DDHidUsage (BXUsageEquality)

//Returns an autoreleased usage corresponding to a predefined usage-name constant.
+ (id) usageWithName: (NSString *)usageName;

//Compares equality between usages.
- (BOOL) isEqualToUsage: (DDHidUsage *)usage;

@end

@interface DDHidUsage (BXUsageExtensions)

@end
