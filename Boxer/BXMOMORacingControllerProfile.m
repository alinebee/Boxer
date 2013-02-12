/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//Custom controller profile for the Logitech MOMO Racing Force Feedback Wheel.
//This happily uses a common Logitech layout that also applies to:
//- MOMO Force (same sans shifter)
//- Wingman Formula GP and Formula Force GP (same sans shifter, and only 4 wheel buttons)
//- Wingman Formula and Formula Force (earlier models of the above)


#import "BXHIDControllerProfilePrivate.h"


#pragma mark -
#pragma mark Private constants


//Use a much smaller than usual deadzone for the MOMO
#define BXMOMORacingWheelDeadzone 0.05f
#define BXMOMORacingPedalDeadzone 0.1f


#define BXMOMORacingControllerVendorID      BXHIDVendorIDLogitech
#define BXMOMORacingControllerProductID     0xca03

#define BXMOMOForceControllerVendorID       BXHIDVendorIDLogitech
#define BXMOMOForceControllerProductID      0xc295

#define BXFormulaForceGPControllerVendorID  BXHIDVendorIDLogitech
#define BXFormulaForceGPControllerProductID 0xc293

#define BXFormulaGPControllerVendorID       BXHIDVendorIDLogitech
#define BXFormulaGPControllerProductID      0xc202

#define BXFormulaForceControllerVendorID    BXHIDVendorIDLogitech
#define BXFormulaForceControllerProductID   0xc291

#define BXFormulaControllerVendorID         BXHIDVendorIDLogitech
#define BXFormulaControllerProductID        0xc20e

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
	
    //Not present on MOMO Force/Formula Force GP
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
            [self matchForVendorID: BXMOMORacingControllerVendorID      productID: BXMOMORacingControllerProductID],
            [self matchForVendorID: BXMOMOForceControllerVendorID       productID: BXMOMOForceControllerProductID],
            [self matchForVendorID: BXFormulaForceGPControllerVendorID  productID: BXFormulaForceGPControllerProductID],
            [self matchForVendorID: BXFormulaGPControllerVendorID       productID: BXFormulaGPControllerProductID],
            [self matchForVendorID: BXFormulaForceControllerVendorID    productID: BXFormulaForceControllerProductID],
            [self matchForVendorID: BXFormulaControllerVendorID         productID: BXFormulaControllerProductID],
            nil];
}

- (BXControllerStyle) controllerStyle { return BXControllerStyleWheel; }

- (id <BXHIDInputBinding>) generatedBindingForButtonElement: (DDHidElement *)element
{	
	NSUInteger emulatedButton, realButton = element.usage.usageId;
    
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
            
        //Leave all other wheel buttons unbound for now
        default:
            emulatedButton = BXEmulatedJoystickUnknownButton;
            break;
    }
    
	BXHIDButtonBinding *binding = nil;
    NSUInteger numEmulatedButtons = [self.emulatedJoystick.class numButtons];
    if (emulatedButton != BXEmulatedJoystickUnknownButton && emulatedButton <= numEmulatedButtons)
    {
        binding = [self bindingFromButtonElement: element toButton: emulatedButton];
    }
	
	return binding;
}

//Adjust deadzone for wheel and pedal elements
- (void) bindAxisElementsForWheel: (NSArray *)elements
{
    for (DDHidElement *element in elements)
    {
        BXHIDAxisBinding *binding;
        switch (element.usage.usageId)
        {
            case BXMOMORacingWheelAxis:
                binding = [self bindingFromAxisElement: element toAxis: BXAxisWheel];
                binding.deadzone = BXMOMORacingWheelDeadzone;
                break;
                
            case BXMOMORacingPedalAxis:
                binding = [self bindingFromAxisElement: element
                                        toPositiveAxis: BXAxisBrake
                                          negativeAxis: BXAxisAccelerator];
                
                binding.deadzone = BXMOMORacingPedalDeadzone;
                break;
                
            default:
                binding = nil;
        }
        
        if (binding)
            [self setBinding: binding forElement: element];
    }
}
@end