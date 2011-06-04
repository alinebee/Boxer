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
#define BX360ControllerLeftTrigger		kHIDUsage_GD_Z
#define BX360ControllerRightTrigger		kHIDUsage_GD_Rz
#define BX360ControllerLeftShoulder		kHIDUsage_Button_4+1
#define BX360ControllerRightShoulder	kHIDUsage_Button_4+2
#define BX360ControllerDPadUp			kHIDUsage_Button_4+8
#define BX360ControllerDPadDown			kHIDUsage_Button_4+9
#define BX360ControllerDPadLeft			kHIDUsage_Button_4+10
#define BX360ControllerDPadRight		kHIDUsage_Button_4+11



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

//Overridden to bind the 360's D-pad buttons to either a POV switch or X and Y axes.
- (void) bindButtonElements: (NSArray *)elements
{
	NSMutableArray *filteredElements = [elements mutableCopy];
	
	BOOL asPOV = [[self emulatedJoystick] respondsToSelector: @selector(POVChangedTo:)];
	if (asPOV)
	{
		id binding = [BXButtonsToPOV binding];
		
		for (DDHidElement *element in elements)
		{
			BOOL matchedPOV = YES;
			switch ([[element usage] usageId])
			{
				case BX360ControllerDPadUp:
					[binding setNorthButton: element];
					break;
				
				case BX360ControllerDPadDown:
					[binding setSouthButton: element];
					break;
					
				case BX360ControllerDPadLeft:
					[binding setWestButton: element];
					break;
				
				case BX360ControllerDPadRight:
					[binding setEastButton: element];
					break;
				default:
					matchedPOV = NO;
			}
			
			//Take the D-pad buttons out of the running so they won't get bound to something else later
			if (matchedPOV)
			{
				[self setBinding: binding forElement: element];
				[filteredElements removeObject: element];
			}
		}
	}
	else
	{
		SEL x = @selector(xAxisMovedTo:),
			y = @selector(yAxisMovedTo:);
		
		id joystick = [self emulatedJoystick];
		if ([joystick respondsToSelector: x] && [joystick respondsToSelector: y])
		{
			for (DDHidElement *element in elements)
			{
				float pressedValue = 0;
				SEL axis = NULL;
				
				switch ([[element usage] usageId])
				{
					case BX360ControllerDPadUp:
						pressedValue = -1.0f;
						axis = y;
						break;
					
					case BX360ControllerDPadDown:
						pressedValue = 1.0f;
						axis = y;
						break;
						
					case BX360ControllerDPadLeft:
						pressedValue = -1.0f;
						axis = x;
						break;
					
					case BX360ControllerDPadRight:
						pressedValue = 1.0f;
						axis = x;
						break;
				}
				
				if (axis)
				{
					id binding = [BXButtonToAxis binding];
					[binding setPressedValue: pressedValue];
					[binding setAxisSelector: axis];
					
					//Take the D-pad buttons out of the running so they won't get bound to something else later
					[self setBinding: binding forElement: element];
					[filteredElements removeObject: element];
				}
			}
		}
	}
	
	//Bind the remaining buttons as usual
	[super bindButtonElements: filteredElements];
	[filteredElements release];
}

- (id <BXHIDInputBinding>) generatedBindingForAxisElement: (DDHidElement *)element
{
	NSUInteger axis = [[element usage] usageId];
	id joystick = [self emulatedJoystick];
	
	SEL accelerator = @selector(acceleratorMovedTo:),
		brake		= @selector(brakeMovedTo:);
	
	id binding = nil;
	
	//Custom binding for 360 triggers: bound to buttons 1 & 2 for regular joysticks,
	//or to brake/accelerator for wheel emulation.
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
			break;
			
		default:
			binding = [super generatedBindingForAxisElement: element];
	}
	return binding;
}

- (id <BXHIDInputBinding>) generatedBindingForButtonElement: (DDHidElement *)element
{
	id binding = nil;
	
	NSUInteger realButton = [[element usage] usageId];
	NSUInteger emulatedButton = BXEmulatedJoystickUnknownButton;
	
	//Custom binding for 360 shoulder buttons: bound to buttons 3 & 4 for regular joysticks,
	//or to 1 & 2 for wheel emulation.
	id joystick = [self emulatedJoystick];
	BOOL isWheel =	[joystick respondsToSelector: @selector(acceleratorMovedTo:)] &&
					[joystick respondsToSelector: @selector(brakeMovedTo:)];
					 
	switch (realButton)
	{
		case BX360ControllerLeftShoulder:
			emulatedButton = isWheel ? BXEmulatedJoystickButton2 : BXEmulatedJoystickButton4;
			break;
		case BX360ControllerRightShoulder: //Right shoulder
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

- (void) dispatchHIDEvent: (BXHIDEvent *)event
{
	//Override the HID framework's treatment of the 360's trigger axes,
	//so that they are centered when released rather than at minimum.
	if ([event type] == BXHIDJoystickAxisChanged)
	{
		if ([event axis] == BX360ControllerLeftTrigger || [event axis] == BX360ControllerRightTrigger)
		{
			//Remaps trigger axis range from DDHID_JOYSTICK_VALUE_MIN -> DDHID_JOYSTICK_VALUE_MAX
			//to 0 -> DDHID_JOYSTICK_VALUE_MAX
			NSInteger normalizedPosition = ([event axisPosition] + DDHID_JOYSTICK_VALUE_MAX) / 2;
			[event setAxisPosition: normalizedPosition];
		}
	}
	[super dispatchHIDEvent: event];
}

@end