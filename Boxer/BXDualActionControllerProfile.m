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

#define BXVendorIDLogitech 0x046d

//NOTE: while in DirectInput mode, the F310 and F510 report themselves as the older
//dual-action and rumblepad 2 models respectively. These gamepads only work in DirectInput
//mode on OS X, as the alternative (XInput mode) does not report an HID profile.

#define BXDualActionVendorID	BXVendorIDLogitech
#define BXDualActionProductID	0xc216

#define BXRumblePad2VendorID    BXVendorIDLogitech
#define BXRumblePad2ProductID   0xc218


//Shoulder and trigger buttons
enum {
	BXDualActionControllerLeftShoulder	= kHIDUsage_Button_4+1,
	BXDualActionControllerRightShoulder,
	BXDualActionControllerLeftTrigger,
	BXDualActionControllerRightTrigger
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
            
        default:
            binding = [super generatedBindingForButtonElement: element];
	}
	
	return binding;
}

@end
