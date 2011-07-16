/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "DDHidUsage+BXUsageExtensions.h"

NSString * const BXUsageJoystick    = @"Joystick";
NSString * const BXUsageGamepad     = @"Gamepad";
NSString * const BXUsageMouse       = @"Mouse";
NSString * const BXUsageKeyboard    = @"Keyboard";

NSString * const BXUsageXAxis       = @"X Axis";
NSString * const BXUsageYAxis       = @"Y Axis";
NSString * const BXUsageZAxis       = @"Z Axis";
NSString * const BXUsageRxAxis      = @"Rx Axis";
NSString * const BXUsageRyAxis      = @"Ry Axis";
NSString * const BXUsageRzAxis      = @"Rz Axis";
NSString * const BXUsageSliderAxis  = @"Slider Axis";
NSString * const BXUsageWheelAxis   = @"Wheel Axis";
NSString * const BXUsageDialAxis    = @"Dial Axis";

NSString * const BXUsageSteeringAxis        = @"Steering";
NSString * const BXUsageShifterAxis         = @"Shifter";
NSString * const BXUsageAcceleratorAxis     = @"Accelerator";
NSString * const BXUsageBrakeAxis           = @"Brake";
NSString * const BXUsageClutchAxis          = @"Clutch";

NSString * const BXUsageAileronAxis         = @"Ailerons";
NSString * const BXUsageElevatorAxis        = @"Elevator";
NSString * const BXUsageRudderAxis          = @"Rudder";
NSString * const BXUsageThrottleAxis        = @"Throttle";

NSString * const BXUsageHatSwitch   = @"Hat Switch";

NSString * const BXUsageButton1     = @"Button 1";
NSString * const BXUsageButton2     = @"Button 2";
NSString * const BXUsageButton3     = @"Button 3";
NSString * const BXUsageButton4     = @"Button 4";
NSString * const BXUsageButton5     = @"Button 5";
NSString * const BXUsageButton6     = @"Button 6";
NSString * const BXUsageButton7     = @"Button 7";
NSString * const BXUsageButton8     = @"Button 8";
NSString * const BXUsageButton9     = @"Button 9";
NSString * const BXUsageButton10    = @"Button 10";
NSString * const BXUsageButton11    = @"Button 11";
NSString * const BXUsageButton12    = @"Button 12";
NSString * const BXUsageButton13    = @"Button 13";
NSString * const BXUsageButton14    = @"Button 14";
NSString * const BXUsageButton15    = @"Button 15";
NSString * const BXUsageButton16    = @"Button 16";
NSString * const BXUsageButton17    = @"Button 17";
NSString * const BXUsageButton18    = @"Button 18";
NSString * const BXUsageButton19    = @"Button 19";
NSString * const BXUsageButton20    = @"Button 20";


@implementation DDHidUsage (BXUsageEquality)

+ (id) usageWithName: (NSString *)usageName
{
    //Save ourselves a lot of typing
#define BUTTON_USAGE(id) BXUsageFromID(kHIDPage_Button, id)
#define DESKTOP_USAGE(id) BXUsageFromID(kHIDPage_Button, id)
#define SIM_USAGE(id) BXUsageFromID(kHIDPage_Simulation, id)
    
    static NSDictionary *namedUsages = nil;
    if (!namedUsages)
    {
        namedUsages = [[NSDictionary alloc] initWithObjectsAndKeys:
                       //Device types
                       DESKTOP_USAGE(kHIDUsage_GD_Joystick),    BXUsageJoystick,
                       DESKTOP_USAGE(kHIDUsage_GD_GamePad),     BXUsageGamepad,
                       DESKTOP_USAGE(kHIDUsage_GD_Keyboard),    BXUsageKeyboard,
                       DESKTOP_USAGE(kHIDUsage_GD_Mouse),       BXUsageMouse,
                       
                       //Axes
                       DESKTOP_USAGE(kHIDUsage_GD_X),           BXUsageXAxis,
                       DESKTOP_USAGE(kHIDUsage_GD_Y),           BXUsageYAxis,
                       DESKTOP_USAGE(kHIDUsage_GD_Z),           BXUsageZAxis,
                       DESKTOP_USAGE(kHIDUsage_GD_Rx),          BXUsageRxAxis,
                       DESKTOP_USAGE(kHIDUsage_GD_Ry),          BXUsageRyAxis,
                       DESKTOP_USAGE(kHIDUsage_GD_Rz),          BXUsageRzAxis,
                       DESKTOP_USAGE(kHIDUsage_GD_Slider),      BXUsageSliderAxis,
                       DESKTOP_USAGE(kHIDUsage_GD_Wheel),       BXUsageWheelAxis,
                       DESKTOP_USAGE(kHIDUsage_GD_Dial),        BXUsageDialAxis,
                       
                       SIM_USAGE(kHIDUsage_Sim_Steering),       BXUsageSteeringAxis,
                       SIM_USAGE(kHIDUsage_Sim_Shifter),        BXUsageShifterAxis,
                       SIM_USAGE(kHIDUsage_Sim_Accelerator),    BXUsageAcceleratorAxis,
                       SIM_USAGE(kHIDUsage_Sim_Brake),          BXUsageBrakeAxis,
                       SIM_USAGE(kHIDUsage_Sim_Clutch),         BXUsageClutchAxis,
                       
                       SIM_USAGE(kHIDUsage_Sim_Aileron),        BXUsageAileronAxis,
                       SIM_USAGE(kHIDUsage_Sim_Elevator),       BXUsageElevatorAxis,
                       SIM_USAGE(kHIDUsage_Sim_Rudder),         BXUsageRudderAxis,
                       SIM_USAGE(kHIDUsage_Sim_Throttle),       BXUsageThrottleAxis,
                       
                       DESKTOP_USAGE(kHIDUsage_GD_Hatswitch),   BXUsageHatSwitch,
                       
                       //Buttons
                       BUTTON_USAGE(kHIDUsage_Button_1),        BXUsageButton1,
                       BUTTON_USAGE(kHIDUsage_Button_2),        BXUsageButton2,
                       BUTTON_USAGE(kHIDUsage_Button_3),        BXUsageButton3,
                       BUTTON_USAGE(kHIDUsage_Button_4),        BXUsageButton4,
                       BUTTON_USAGE(kHIDUsage_Button_4+1),      BXUsageButton5,
                       BUTTON_USAGE(kHIDUsage_Button_4+2),      BXUsageButton5,
                       BUTTON_USAGE(kHIDUsage_Button_4+3),      BXUsageButton6,
                       BUTTON_USAGE(kHIDUsage_Button_4+4),      BXUsageButton7,
                       BUTTON_USAGE(kHIDUsage_Button_4+5),      BXUsageButton8,
                       BUTTON_USAGE(kHIDUsage_Button_4+6),      BXUsageButton9,
                       BUTTON_USAGE(kHIDUsage_Button_4+7),      BXUsageButton10,
                       BUTTON_USAGE(kHIDUsage_Button_4+8),      BXUsageButton11,
                       BUTTON_USAGE(kHIDUsage_Button_4+9),      BXUsageButton12,
                       BUTTON_USAGE(kHIDUsage_Button_4+10),     BXUsageButton13,
                       BUTTON_USAGE(kHIDUsage_Button_4+11),     BXUsageButton14,
                       BUTTON_USAGE(kHIDUsage_Button_4+12),     BXUsageButton15,
                       BUTTON_USAGE(kHIDUsage_Button_4+13),     BXUsageButton16,
                       BUTTON_USAGE(kHIDUsage_Button_4+14),     BXUsageButton17,
                       BUTTON_USAGE(kHIDUsage_Button_4+15),     BXUsageButton18,
                       BUTTON_USAGE(kHIDUsage_Button_4+16),     BXUsageButton19,
                       BUTTON_USAGE(kHIDUsage_Button_4+17),     BXUsageButton20,
        nil];
    }
    return [namedUsages objectForKey: usageName];
}

- (id) copyWithZone: (NSZone *)zone
{
	//DDHidUsage is immutable, so it's OK for us to retain rather than copying
	return [self retain];
}

- (BOOL) isEqualToUsage: (DDHidUsage *)usage
{
	return [self isEqualToUsagePage: [usage usagePage] usageId: [usage usageId]];
}

- (BOOL) isEqual: (id)object
{
	if ([object isKindOfClass: [DDHidUsage class]] && [self isEqualToUsage: object]) return YES;
	else return [super isEqual: object];
}
@end


DDHidUsage * BXUsageFromID(unsigned int usagePage, unsigned int usageID)
{
    return [DDHidUsage usageWithUsagePage: usagePage usageId: usageID];
}

DDHidUsage * BXUsageFromName(NSString *usageName)
{
    return [DDHidUsage usageWithName: usageName];
}
