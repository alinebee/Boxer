/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//Custom controller profile for the Logitech G25 and G27 wheels.

#import "BXHIDControllerProfilePrivate.h"


#pragma mark -
#pragma mark Private constants

//Use a much smaller than usual deadzone for the G25/G27
#define BXG25WheelDeadzone 0.05f
#define BXG25PedalDeadzone 0.1f


#define BXG25ControllerVendorID             BXHIDVendorIDLogitech
#define BXG25ControllerProductID            0xc299

//It seems at least some G25s identify themselves as this on OS X?
#define BXDrivingForceControllerVendorID    BXHIDVendorIDLogitech
#define BXDrivingForceControllerProductID   0xc294

#define BXG27ControllerVendorID         BXHIDVendorIDLogitech
#define BXG27ControllerProductID        0xc29b

enum {
    BXG25WheelAxis = kHIDUsage_GD_X,
    BXG25PedalAxis = kHIDUsage_GD_Y
};

enum {
	BXG25DashboardButtonBottom = kHIDUsage_Button_1,
	BXG25DashboardButtonLeft,
	BXG25DashboardButtonRight,
	BXG25DashboardButtonTop,
	
	BXG25RightPaddle,
	BXG25LeftPaddle,
    
	BXG25WheelButton1,
	BXG25WheelButton2,
	
	BXG25DashboardButton1,
	BXG25DashboardButton2,
	BXG25DashboardButton3,
	BXG25DashboardButton4,
	
	BXG25ShifterDown = BXG25DashboardButton3,
	BXG25ShifterUp   = BXG25DashboardButton4
    
    //TODO: enumerate the additional buttons on the G27
};



@interface BXG25ControllerProfile: BXHIDControllerProfile
@end


@implementation BXG25ControllerProfile

+ (void) load
{
	[BXHIDControllerProfile registerProfile: self];
}

+ (NSArray *) matchedIDs
{
    return [NSArray arrayWithObjects:
            [self matchForVendorID: BXG25ControllerVendorID productID: BXG25ControllerProductID],
            [self matchForVendorID: BXDrivingForceControllerVendorID productID: BXDrivingForceControllerProductID],
            [self matchForVendorID: BXG27ControllerVendorID productID: BXG27ControllerProductID],
            nil];
}

//Manual binding for G25/G27 buttons
- (id <BXHIDInputBinding>) generatedBindingForButtonElement: (DDHidElement *)element
{
	id binding = nil;
	id joystick = [self emulatedJoystick];
	
	NSUInteger realButton = [[element usage] usageId];
	NSUInteger emulatedButton = BXEmulatedJoystickUnknownButton;
    NSUInteger numEmulatedButtons = [joystick numButtons];
    
    switch (realButton)
    {
        case BXG25RightPaddle:
        case BXG25ShifterUp:
        case BXG25DashboardButtonBottom:
            emulatedButton = BXEmulatedJoystickButton1;
            break;
            
        case BXG25LeftPaddle:
        case BXG25ShifterDown:
        case BXG25DashboardButtonRight:
            emulatedButton = BXEmulatedJoystickButton2;
            break;
            
        case BXG25WheelButton1:
        case BXG25DashboardButtonLeft:
            emulatedButton = BXEmulatedJoystickButton3;
            break;
            
        case BXG25WheelButton2:
        case BXG25DashboardButtonTop:
            emulatedButton = BXEmulatedJoystickButton4;
            break;
        
        //Leave all other buttons unbound
    }
    
    if (emulatedButton != BXEmulatedJoystickUnknownButton && emulatedButton <= numEmulatedButtons)
    {
        binding = [BXButtonToButton binding];
        [binding setButton: emulatedButton];
    }
	
	return binding;
}

//Adjust deadzone for wheel and pedal elements
- (void) bindAxisElementsForWheel: (NSArray *)elements
{
    for (DDHidElement *element in elements)
    {
        id binding;
        switch([[element usage] usageId])
        {
            case BXG25WheelAxis:
                binding = [BXAxisToAxis bindingWithAxis: BXAxisWheel];
                [binding setDeadzone: BXG25WheelDeadzone];
                break;
                
            case BXG25PedalAxis:
                binding = [BXAxisToBindings bindingWithPositiveAxis: BXAxisBrake
                                                       negativeAxis: BXAxisAccelerator];
                
                [binding setDeadzone: BXG25PedalDeadzone];
                break;
                
            default:
                binding = nil;
        }
        
        if (binding)
            [self setBinding: binding forElement: element];
    }
}

@end