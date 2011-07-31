/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//Custom controller profile for the Logitech MOMO Racing Force Feedback Wheel, and its earlier
//cousin the MOMO Force (which is the same layout sans shifter, and *probably* the same button
//enumeration order.)

#import "BXHIDControllerProfilePrivate.h"


#pragma mark -
#pragma mark Private constants


//Use a much smaller than usual deadzone for the MOMO
#define BXMOMORacingWheelDeadzone 0.05f
#define BXMOMORacingPedalDeadzone 0.1f


#define BXMOMORacingControllerVendorID        BXHIDVendorIDLogitech
#define BXMOMORacingControllerProductID       0xca03

#define BXMOMOForceControllerVendorID         BXHIDVendorIDLogitech
#define BXMOMOForceControllerProductID        0xc295

enum {
    BXMOMORacingWheelAxis = kHIDUsage_GD_X,
    BXMOMORacingPedalAxis = kHIDUsage_GD_Y
};

enum {
	BXMOMORacingLeftPaddle = kHIDUsage_Button_1,
	BXMOMORacingRightPaddle,
    
    //Numbered from left to right, top to bottom
    BXMOMORacingWheelButton1,
	BXMOMORacingWheelButton2,
	BXMOMORacingWheelButton3,
	BXMOMORacingWheelButton4,
	BXMOMORacingWheelButton5,
	BXMOMORacingWheelButton6,
	
	BXMOMORacingShifterDown,
	BXMOMORacingShifterUp
};



@interface BXMOMORacingControllerProfile: BXHIDControllerProfile
@end


@implementation BXMOMORacingControllerProfile

+ (void) load
{
	[BXHIDControllerProfile registerProfile: self];
}

+ (NSArray *) matchedIDs
{
    return [NSArray arrayWithObjects:
            [self matchForVendorID: BXMOMORacingControllerVendorID productID: BXMOMORacingControllerProductID],
            [self matchForVendorID: BXMOMOForceControllerVendorID productID: BXMOMOForceControllerProductID],
            nil];
}

- (id <BXHIDInputBinding>) generatedBindingForButtonElement: (DDHidElement *)element
{
	id binding = nil;
	id joystick = [self emulatedJoystick];
	
	NSUInteger realButton = [[element usage] usageId];
	NSUInteger emulatedButton = BXEmulatedJoystickUnknownButton;
    NSUInteger numEmulatedButtons = [joystick numButtons];
    
    switch (realButton)
    {
        case BXMOMORacingRightPaddle:
        case BXMOMORacingShifterUp:
            emulatedButton = BXEmulatedJoystickButton1;
            break;
            
        case BXMOMORacingLeftPaddle:
        case BXMOMORacingShifterDown:
            emulatedButton = BXEmulatedJoystickButton2;
            break;
            
        case BXMOMORacingWheelButton1:
            emulatedButton = BXEmulatedJoystickButton3;
            break;
            
        case BXMOMORacingWheelButton2:
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
            case BXMOMORacingWheelAxis:
                binding = [BXAxisToAxis bindingWithAxis: BXAxisWheel];
                [binding setDeadzone: BXMOMORacingWheelDeadzone];
                break;
                
            case BXMOMORacingPedalAxis:
                binding = [BXAxisToBindings bindingWithPositiveAxis: BXAxisBrake
                                                       negativeAxis: BXAxisAccelerator];
                
                [binding setDeadzone: BXMOMORacingPedalDeadzone];
                break;
                
            default:
                binding = nil;
        }
        
        if (binding)
            [self setBinding: binding forElement: element];
    }
}
@end