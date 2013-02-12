/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//Custom controller profile for the PS3 Sixaxis controller, which is all over the goddamn place.

#import "BXHIDControllerProfilePrivate.h"
#import "BXSession+BXUIControls.h"


#pragma mark -
#pragma mark Private constants

#define BXSixaxisControllerVendorID		BXHIDVendorIDSony
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
	BXSixaxisControllerDPadRight,
	BXSixaxisControllerDPadDown,
	BXSixaxisControllerDPadLeft,
		
	//Unlike the 360 controller, the Sixaxis triggers are represented
	//as buttons rather than analog axes
	BXSixaxisControllerLeftTrigger,
	BXSixaxisControllerRightTrigger,
	BXSixaxisControllerLeftShoulder,
	BXSixaxisControllerRightShoulder,
	
	BXSixaxisControllerTriangleButton,
	BXSixaxisControllerCircleButton,
	BXSixaxisControllerXButton,
	BXSixaxisControllerSquareButton,
    BXSixaxisControllerHomeButton
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

- (BXControllerStyle) controllerStyle { return BXControllerStyleGamepad; }

- (NSDictionary *) DPadElementsFromButtons: (NSArray *)buttons
{
	NSMutableDictionary *padElements = [NSMutableDictionary dictionaryWithCapacity: 4];
	for (DDHidElement *element in self.device.buttonElements)
	{
		switch (element.usage.usageId)
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
		if (padElements.count == 4) break;
	}
	return padElements;
}

//Manual binding for Sixaxis buttons because they're numbered in a crazy-ass order.
- (id <BXHIDInputBinding>) generatedBindingForButtonElement: (DDHidElement *)element
{
	id <BXHIDInputBinding> binding;
	
	BOOL isWheel = [self.emulatedJoystick conformsToProtocol: @protocol(BXEmulatedWheel)];

    switch (element.usage.usageId)
    {
        case BXSixaxisControllerXButton:
            binding = [self bindingFromButtonElement: element toButton: BXEmulatedJoystickButton1];
            break;
            
        case BXSixaxisControllerCircleButton:
            binding = [self bindingFromButtonElement: element toButton: BXEmulatedJoystickButton2];
            break;
        
        case BXSixaxisControllerSquareButton:
            binding = [self bindingFromButtonElement: element toButton: BXEmulatedJoystickButton3];
            break;
        
        case BXSixaxisControllerTriangleButton:
            binding = [self bindingFromButtonElement: element toButton: BXEmulatedJoystickButton4];
            break;
            
        case BXSixaxisControllerLeftTrigger:
            if (isWheel)
                binding = [self bindingFromButtonElement: element toAxis: BXAxisBrake polarity: kBXAxisPositive];
            else
                binding = [self bindingFromButtonElement: element toButton: BXEmulatedJoystickButton2];
            break;
            
        case BXSixaxisControllerRightTrigger:
            if (isWheel)
                binding = [self bindingFromButtonElement: element toAxis: BXAxisAccelerator polarity: kBXAxisPositive];
            else
                binding = [self bindingFromButtonElement: element toButton: BXEmulatedJoystickButton1];
            break;
            
        case BXSixaxisControllerLeftShoulder:
            binding = [self bindingFromButtonElement: element
                                            toButton: (isWheel ? BXEmulatedJoystickButton2 : BXEmulatedJoystickButton4)];
            break;
            
        case BXSixaxisControllerRightShoulder:
            binding = [self bindingFromButtonElement: element
                                            toButton: (isWheel ? BXEmulatedJoystickButton1 : BXEmulatedJoystickButton3)];
            break;
            
        case BXSixaxisControllerStartButton:
            binding = [self bindingFromButtonElement: element toTarget: nil action: @selector(togglePaused:)];
            break;
            
        case BXSixaxisControllerSelectButton:
            binding = [self bindingFromButtonElement: element toKeyCode: KBD_esc];
            break;
        
        default:
            //Leave all other buttons unbound
            binding = nil;
    }
	
	return binding;
}
@end
