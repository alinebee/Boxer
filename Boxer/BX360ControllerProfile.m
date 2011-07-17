/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//Custom controller profile for the wired and wireless 360 controller using Tattiebogle's
//3rd-party driver: http://tattiebogle.net/index.php/ProjectRoot/Xbox360Controller/OsxDriver


#import "BXHIDControllerProfilePrivate.h"
#import "DDHidUsage+BXUsageExtensions.h"


#pragma mark -
#pragma mark Private constants

//These constants were taken from the Info.plist for Tattiebogle’s 3rd-party 360 controller driver.

#define BXHIDVendorIDMicrosoft 0x045e
#define BXHIDVendorIDMadCatz 0x0738
#define BXHIDVendorIDHori 0x0f0d
#define BXHIDVendorIDJoyTek 0x162e
#define BXHIDVendorIDPelican 0x0e6f
#define BXHIDVendorIDBigBen 0x146b

//The official Microsoft 360 controller
#define BX360ControllerVendorID         BXHIDVendorIDMicrosoft
#define BX360ControllerProductID        0x028e

//3rd-party 360 peripherals
#define BXJoyTek360ControllerVendorID	BXHIDVendorIDJoyTek
#define BXJoyTek360ControllerProductID  0xbeef //no seriously

#define BXBigBen360ControllerVendorID   BXHIDVendorIDBigBen
#define BXBigBen360ControllerProductID  0x0601

#define BXPelican360ControllerVendorID  BXHIDVendorIDPelican
#define BXPelican360ControllerProductID 0x0201

#define BXMadCatzGamepadVendorID        BXHIDVendorIDMadCatz
#define BXMadCatzGamepadProductID       0x4716

#define BXMadCatzProGamepadVendorID     BXHIDVendorIDMadCatz
#define BXMadCatzProGamepadProductID    0x4726

#define BXMadCatzMicroConVendorID       BXHIDVendorIDMadCatz
#define BXMadCatzMicroConProductID      0x4736

#define BXDOA4StickVendorID             BXHIDVendorIDHori
#define BXDOA4StickProductID            0x000a


enum {
	BX360ControllerLeftStickX		= kHIDUsage_GD_X,
	BX360ControllerLeftStickY		= kHIDUsage_GD_Y,
	BX360ControllerRightStickX		= kHIDUsage_GD_Rx,
	BX360ControllerRightStickY		= kHIDUsage_GD_Ry,
	BX360ControllerLeftTrigger		= kHIDUsage_GD_Z,
	BX360ControllerRightTrigger		= kHIDUsage_GD_Rz
};

enum {
	BX360ControllerAButton			= kHIDUsage_Button_1,
	BX360ControllerBButton,
	BX360ControllerXButton,
	BX360ControllerYButton,
	
	BX360ControllerLeftShoulder,
	BX360ControllerRightShoulder,
	
	BX360ControllerLeftStickClick,
	BX360ControllerRightStickClick,
	
	BX360ControllerStartButton,
	BX360ControllerBackButton,
	BX360ControllerXBoxButton,
	
	BX360ControllerDPadUp,
	BX360ControllerDPadDown,
	BX360ControllerDPadLeft,
	BX360ControllerDPadRight
};



@interface BX360ControllerProfile: BXHIDControllerProfile
@end


@implementation BX360ControllerProfile

+ (void) load
{
	[BXHIDControllerProfile registerProfile: self];
}

+ (NSArray *) matchedIDs
{
    static NSArray *matches = nil;
    if (!matches)
    {
        matches = [NSArray arrayWithObjects:
                   [self matchForVendorID: BX360ControllerVendorID           productID: BX360ControllerProductID],
                   [self matchForVendorID: BXJoyTek360ControllerVendorID     productID: BXJoyTek360ControllerProductID],
                   [self matchForVendorID: BXBigBen360ControllerVendorID     productID: BXBigBen360ControllerProductID],
                   [self matchForVendorID: BXPelican360ControllerVendorID    productID: BXPelican360ControllerProductID],
                   [self matchForVendorID: BXMadCatzGamepadVendorID          productID: BXMadCatzGamepadProductID],
                   [self matchForVendorID: BXMadCatzProGamepadVendorID       productID: BXMadCatzProGamepadProductID],
                   [self matchForVendorID: BXMadCatzMicroConVendorID         productID: BXMadCatzMicroConProductID],
                   [self matchForVendorID: BXDOA4StickVendorID               productID: BXDOA4StickProductID],
                   nil];
    }
    return matches;
}

- (NSDictionary *) DPadElementsFromButtons: (NSArray *)buttons
{
	NSMutableDictionary *padElements = [[NSMutableDictionary alloc] initWithCapacity: 4];
	
	for (DDHidElement *element in buttons)
	{
		switch ([[element usage] usageId])
		{
			case BX360ControllerDPadUp:
				[padElements setObject: element forKey: BXControllerProfileDPadUp];
				break;
				
			case BX360ControllerDPadDown:
				[padElements setObject: element forKey: BXControllerProfileDPadDown];
				break;
				
			case BX360ControllerDPadLeft:
				[padElements setObject: element forKey: BXControllerProfileDPadLeft];
				break;
			
			case BX360ControllerDPadRight:
				[padElements setObject: element forKey: BXControllerProfileDPadRight];
				break;
		}
		//Stop looking once we've found all the D-pad buttons
		if ([padElements count] == 4) break;
	}
	
	return [padElements autorelease];
}


//Custom binding for 360 shoulder buttons: bind to buttons 3 & 4 for regular joysticks
//(where the triggers are buttons 1 & 2), or to 1 & 2 for wheel emulation (where the
//triggers are the pedals).
- (id <BXHIDInputBinding>) generatedBindingForButtonElement: (DDHidElement *)element
{
	id binding = nil;
	
	NSUInteger realButton = [[element usage] usageId];
	NSUInteger emulatedButton = BXEmulatedJoystickUnknownButton;
	
	id joystick = [self emulatedJoystick];
	BOOL isWheel =	[joystick respondsToSelector: @selector(acceleratorMovedTo:)] &&
					[joystick respondsToSelector: @selector(brakeMovedTo:)];
					 
	switch (realButton)
	{
		case BX360ControllerLeftShoulder:
			emulatedButton = isWheel ? BXEmulatedJoystickButton2 : BXEmulatedJoystickButton4;
			break;
		case BX360ControllerRightShoulder:
			emulatedButton = isWheel ? BXEmulatedJoystickButton1 : BXEmulatedJoystickButton3;
			break;
	}
	
	if (emulatedButton != BXEmulatedJoystickUnknownButton)
	{
		binding = [BXButtonToButton binding];
		[binding setButton: emulatedButton];
	}
	else binding = [super generatedBindingForButtonElement: element];
	
	return binding;
}

//Bind triggers to buttons 1 & 2 for regular joystick emulation.
- (id <BXHIDInputBinding>) generatedBindingForAxisElement: (DDHidElement *)element
{
	NSUInteger axis = [[element usage] usageId];
	id binding = nil;
	
	switch (axis)
	{
		case BX360ControllerLeftTrigger:
			binding = [BXAxisToButton bindingWithButton: BXEmulatedJoystickButton2];
			[binding setUnidirectional: YES];
			break;
		
		case BX360ControllerRightTrigger:
			binding = [BXAxisToButton bindingWithButton: BXEmulatedJoystickButton1];
			[binding setUnidirectional: YES];
			break;
			
		default:
			binding = [super generatedBindingForAxisElement: element];
	}
	return binding;
}

//Bind triggers to brake/accelerator for wheel emulation.
- (void) bindAxisElementsForWheel: (NSArray *)elements
{
    //Apply regular controller-to-wheel binding behaviour,
    //which will otherwise suit the 360 just fine.
    [super bindAxisElementsForWheel: elements];
    
    //Add the triggers as additional pedal inputs.
    for (DDHidElement *element in elements)
    {
        id binding;
        switch([[element usage] usageId])
        {
            case BX360ControllerLeftTrigger:
                binding = [BXAxisToAxis bindingWithAxisSelector: @selector(brakeMovedTo:)];
                [binding setUnidirectional: YES];
                break;
                
            case BX360ControllerRightTrigger:
                binding = [BXAxisToAxis bindingWithAxisSelector: @selector(acceleratorMovedTo:)];
                [binding setUnidirectional: YES];
                break;
            default:
                binding = nil;
        }
        if (binding)
            [self setBinding: binding forElement: element];
    }
}

@end