/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//Custom controller profile for the PS3 Sixaxis controller, which is all over the goddamn place.

#import "BXHIDControllerProfilePrivate.h"

#pragma mark -
#pragma mark Private constants

//NOTE: while in DirectInput mode, the F310 and F510 report themselves as the older
//Dual-Action and RumblePad 2 models respectively (and presumably, the F710 as the
//Cordless RumblePad 2, though this is not confirmed.) These gamepads only work in
//DirectInput mode on OS X, as the alternative (XInput mode) does not report an HID
//profile.

#define BXDualActionVendorID	BXHIDVendorIDLogitech
#define BXDualActionProductID	0xc216

#define BXRumblePad2VendorID    BXHIDVendorIDLogitech
#define BXRumblePad2ProductID   0xc218

#define BXCordlessRumblePad2VendorID    BXHIDVendorIDLogitech
#define BXCordlessRumblePad2ProductID   0xc219


enum {
    BXDualActionButton1 = kHIDUsage_Button_1,
    BXDualActionButton2,
    BXDualActionButton3,
    BXDualActionButton4,
    
	BXDualActionControllerLeftShoulder,
	BXDualActionControllerRightShoulder,
	BXDualActionControllerLeftTrigger,
	BXDualActionControllerRightTrigger,
    
    BXDualActionControllerBackButton,
	BXDualActionControllerStartButton,
    BXDualActionControllerLeftStickClick,
	BXDualActionControllerRightStickClick,

    //Enumerated and labelled in dumb order, nice one guys!
    BXFx10AButton = BXDualActionButton2,
    BXFx10BButton = BXDualActionButton3,
    BXFx10XButton = BXDualActionButton1,
    BXFx10YButton = BXDualActionButton4
};

@interface BXDualActionControllerProfile : BXHIDControllerProfile
@end


@implementation BXDualActionControllerProfile

+ (void) load
{
	[BXHIDControllerProfile registerProfile: self];
}

+ (NSArray *) matchedIDs
{
    return [NSArray arrayWithObjects:
            [self matchForVendorID: BXDualActionVendorID productID: BXDualActionProductID],
            [self matchForVendorID: BXRumblePad2VendorID productID: BXRumblePad2ProductID],
            [self matchForVendorID: BXCordlessRumblePad2VendorID productID: BXCordlessRumblePad2ProductID],
            nil];
}

//Custom binding for shoulder buttons: bind to buttons 3 & 4 for regular joysticks
//(where the triggers are buttons 1 & 2), or to 1 & 2 for wheel emulation (where the
//triggers are the pedals).
- (id <BXHIDInputBinding>) generatedBindingForButtonElement: (DDHidElement *)element
{
	id binding = nil;
	
	id joystick = [self emulatedJoystick];
	BOOL isWheel =	[joystick conformsToProtocol: @protocol(BXEmulatedWheel)];
    
	switch ([[element usage] usageId])
	{
        case BXDualActionControllerLeftTrigger:
            if (isWheel)
                binding = [BXButtonToAxis bindingWithAxis: BXAxisBrake];
            else
                binding = [BXButtonToButton bindingWithButton: BXEmulatedJoystickButton2];
            break;
            
        case BXDualActionControllerRightTrigger:
            if (isWheel)
                binding = [BXButtonToAxis bindingWithAxis: BXAxisAccelerator];
            else
                binding = [BXButtonToButton bindingWithButton: BXEmulatedJoystickButton1];
            break;
            
		case BXDualActionControllerLeftShoulder:
            binding = [BXButtonToButton bindingWithButton:
                       isWheel ? BXEmulatedJoystickButton2 : BXEmulatedJoystickButton4];
			break;
            
		case BXDualActionControllerRightShoulder:
            binding = [BXButtonToButton bindingWithButton:
                       isWheel ? BXEmulatedJoystickButton1 : BXEmulatedJoystickButton3];
			break;
            
        //Remap the Fx10 face buttons to a more sensible layout.
        //Disabled for now as this would be too disruptive on earlier models.
        //TODO: figure out a heuristic to tell the difference between the two 'eras'.
            /*
        case BXFx10AButton:
            binding = [BXButtonToButton bindingWithButton: BXEmulatedJoystickButton1];
            break;
            
        case BXFx10BButton:
            binding = [BXButtonToButton bindingWithButton: BXEmulatedJoystickButton2];
            break;
            
        case BXFx10XButton:
            binding = [BXButtonToButton bindingWithButton: BXEmulatedJoystickButton3];
            break;
            
        case BXFx10YButton:
            binding = [BXButtonToButton bindingWithButton: BXEmulatedJoystickButton4];
            break;
             */
            
        default:
            binding = [super generatedBindingForButtonElement: element];
	}
	
	return binding;
}

@end
