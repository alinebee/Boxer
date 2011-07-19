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

#define BXVendorIDSony 0x054C

#define BXSixaxisControllerVendorID		BXVendorIDSony
#define BXSixaxisControllerProductID	0x0268

enum {
	BXSixaxisControllerLeftStickX		= kHIDUsage_GD_X,
	BXSixaxisControllerLeftStickY		= kHIDUsage_GD_Y,
	BXSixaxisControllerRightStickX		= kHIDUsage_GD_Rx,
	BXSixaxisControllerRightStickY		= kHIDUsage_GD_Ry
};

//That's right, the Sixaxis' buttons are numbered in a crazy-ass order. Thanks guys!
enum {
	BXSixaxisControllerSelectButton		= kHIDUsage_Button_1,
	BXSixaxisControllerLeftStickClick,
	BXSixaxisControllerRightStickClick,
	BXSixaxisControllerStartButton,

	BXSixaxisControllerDPadUp,
	BXSixaxisControllerDPadDown,
	BXSixaxisControllerDPadLeft,
	BXSixaxisControllerDPadRight,
		
	//Unlike the 360 controller, the Sixaxis triggers are represented
	//as buttons rather than analog axes
	BXSixaxisControllerLeftTrigger,
	BXSixaxisControllerRightTrigger,
	BXSixaxisControllerLeftShoulder,
	BXSixaxisControllerRightShoulder,
	
	BXSixaxisControllerTriangleButton,
	BXSixaxisControllerCircleButton,
	BXSixaxisControllerXButton,
	BXSixaxisControllerSquareButton
};


@interface BXSixaxisControllerProfile: BXHIDControllerProfile
@end



@implementation BXSixaxisControllerProfile

+ (void) load
{
	[BXHIDControllerProfile registerProfile: self];
}

+ (NSArray *) matchedIDs
{
    return [NSArray arrayWithObjects:
            [self matchForVendorID: BXSixaxisControllerVendorID productID: BXSixaxisControllerProductID],
            nil];
}

- (NSDictionary *) DPadElementsFromButtons: (NSArray *)buttons
{
	NSMutableDictionary *padElements = [[NSMutableDictionary alloc] initWithCapacity: 4];
	for (DDHidElement *element in [[self HIDController] buttonElements])
	{
		switch ([[element usage] usageId])
		{
			case BXSixaxisControllerDPadUp:
				[padElements setObject: element forKey: BXControllerProfileDPadUp];
				break;
				
			case BXSixaxisControllerDPadDown:
				[padElements setObject: element forKey: BXControllerProfileDPadDown];
				break;
				
			case BXSixaxisControllerDPadLeft:
				[padElements setObject: element forKey: BXControllerProfileDPadLeft];
				break;
			
			case BXSixaxisControllerDPadRight:
				[padElements setObject: element forKey: BXControllerProfileDPadRight];
				break;
		}
		//Stop looking once we've found all the D-pad buttons
		if ([padElements count] == 4) break;
	}
	return [padElements autorelease];
}

//Manual binding for Sixaxis buttons because they're numbered in a crazy-ass order.
- (id <BXHIDInputBinding>) generatedBindingForButtonElement: (DDHidElement *)element
{
	id binding;
	id joystick = [self emulatedJoystick];
	
	BOOL isWheel =	[joystick respondsToSelector: @selector(acceleratorMovedTo:)] &&
					[joystick respondsToSelector: @selector(brakeMovedTo:)];

    switch ([[element usage] usageId])
    {
        case BXSixaxisControllerXButton:
            binding = [BXButtonToButton bindingWithButton: BXEmulatedJoystickButton1];
            break;
            
        case BXSixaxisControllerCircleButton:
            binding = [BXButtonToButton bindingWithButton: BXEmulatedJoystickButton2];
            break;
        
        case BXSixaxisControllerSquareButton:
            binding = [BXButtonToButton bindingWithButton: BXEmulatedJoystickButton3];
            break;
        
        case BXSixaxisControllerTriangleButton:
            binding = [BXButtonToButton bindingWithButton: BXEmulatedJoystickButton4];
            break;
            
        case BXSixaxisControllerLeftTrigger:
            if (isWheel)
                binding = [BXButtonToAxis bindingWithAxisSelector: @selector(brakeMovedTo:)];
            else
                binding = [BXButtonToButton bindingWithButton: BXEmulatedJoystickButton2];
            break;
            
        case BXSixaxisControllerRightTrigger:
            if (isWheel)
                binding = [BXButtonToAxis bindingWithAxisSelector: @selector(acceleratorMovedTo:)];
            else
                binding = [BXButtonToButton bindingWithButton: BXEmulatedJoystickButton1];
            break;
            
        case BXSixaxisControllerLeftShoulder:
            binding = [BXButtonToButton bindingWithButton:
                       isWheel ? BXEmulatedJoystickButton2 : BXEmulatedJoystickButton4];
            break;
            
        case BXSixaxisControllerRightShoulder:
            binding = [BXButtonToButton bindingWithButton:
                       isWheel ? BXEmulatedJoystickButton1 : BXEmulatedJoystickButton3];
            break;
        
        default:
            //Leave all other buttons unbound
            binding = nil;
    }
	
	return binding;
}
@end
