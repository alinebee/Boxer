/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//Custom controller profile for the wired and wireless 360 controller using Tattiebogle's
//3rd-party driver: http://tattiebogle.net/index.php/ProjectRoot/Xbox360Controller/OsxDriver


#import "BXHIDControllerProfilePrivate.h"


#pragma mark -
#pragma mark Private constants

#define BXHIDVendorIDMicrosoft 0x45e

#define BX360ControllerVendorID			BXHIDVendorIDMicrosoft
#define BX360ControllerProductID		0x028e

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

+ (BOOL) matchesHIDController: (DDHidJoystick *)HIDController
{
	if ([HIDController vendorId] == BX360ControllerVendorID &&
		[HIDController productId] == BX360ControllerProductID) return YES;
	
	return NO;
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

//Custom binding for 360 triggers: bind to buttons 1 & 2 for regular joysticks,
//or to brake/accelerator for wheel emulation.
- (id <BXHIDInputBinding>) generatedBindingForAxisElement: (DDHidElement *)element
{
	NSUInteger axis = [[element usage] usageId];
	id joystick = [self emulatedJoystick];
	
	SEL accelerator = @selector(acceleratorMovedTo:),
		brake		= @selector(brakeMovedTo:);
	
	id binding = nil;
	
	switch (axis)
	{
		case BX360ControllerLeftTrigger:
			if ([joystick respondsToSelector: brake])
			{
				binding = [BXAxisToAxis binding];
				[binding setAxisSelector: brake];
			}
			else
			{
				binding = [BXAxisToButton binding];
				[binding setButton: BXEmulatedJoystickButton2];
			}
			[binding setUnidirectional: YES];
			break;
		
		case BX360ControllerRightTrigger:
			if ([joystick respondsToSelector: accelerator])
			{
				binding = [BXAxisToAxis binding];
				[binding setAxisSelector: accelerator];
			}
			else
			{
				binding = [BXAxisToButton binding];
				[binding setButton: BXEmulatedJoystickButton1];
			}
			[binding setUnidirectional: YES];
			break;
			
		default:
			binding = [super generatedBindingForAxisElement: element];
	}
	return binding;
}

@end