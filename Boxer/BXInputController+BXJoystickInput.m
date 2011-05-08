/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXInputControllerPrivate.h"
#import "BXAppController.h"
#import "BXJoystickController.h"
#import <IOKit/hid/IOHIDLib.h>


//The multiplier to use when adding a joystick axis's positional input (for e.g. throttle impulses)
//rather than using it as the absolute axis position.
#define BXAdditiveAxisStrength 0.1f

//Default to a 25% deadzone.
#define BXAxisDeadzone 0.25f * DDHID_JOYSTICK_VALUE_MAX


@implementation BXInputController (BXJoystickInput)

- (void) _syncJoystickType
{
	BXEmulator *emulator = [[self representedObject] emulator];
	BXJoystickSupportLevel support = [emulator joystickSupport];
	
	if (support == BXNoJoystickSupport)
	{
		[emulator detachJoystick];
		return;
	}
	
	NSArray *joysticks = [[[NSApp delegate] joystickController] joystickDevices];
	NSUInteger numJoysticks = [joysticks count];
	
	if (numJoysticks > 0)
	{
		Class joystickClass = (support == BXJoystickSupportSimple) ? [BX2AxisJoystick class] : [BX4AxisJoystick class];
		
		if (![[emulator joystick] isKindOfClass: joystickClass])
			[emulator attachJoystickOfType: joystickClass];
	}
	else [emulator detachJoystick];
}

- (void) HIDJoystickButtonDown: (BXHIDEvent *)event
{
	id <BXEmulatedJoystick> joystick = [self _emulatedJoystick];
	
	switch ([event buttonNumber])
	{
		case kHIDUsage_Button_1:
			[joystick buttonDown: BXEmulatedJoystickButton1];
			break;
			
		case kHIDUsage_Button_2:
			[joystick buttonDown: BXEmulatedJoystickButton2];
			break;
			
		case kHIDUsage_Button_3:
			[joystick buttonDown: BXEmulatedJoystickButton3];
			break;
			
		case kHIDUsage_Button_4:
			[joystick buttonDown: BXEmulatedJoystickButton4];
			break;
			
		case kHIDUsage_Button_4+1:
			[joystick buttonDown: BXCHCombatStickButton5];
			break;
			
		case kHIDUsage_Button_4+2:
			[joystick buttonDown: BXCHCombatStickButton6];
			break;
	}
	//Ignore all other buttons
}

- (void) HIDJoystickButtonUp: (BXHIDEvent *)event
{
	id <BXEmulatedJoystick> joystick = [self _emulatedJoystick];
	
	switch ([event buttonNumber])
	{
		case kHIDUsage_Button_1:
			[joystick buttonUp: BXEmulatedJoystickButton1];
			break;
			
		case kHIDUsage_Button_2:
			[joystick buttonUp: BXEmulatedJoystickButton2];
			break;
			
		case kHIDUsage_Button_3:
			[joystick buttonUp: BXEmulatedJoystickButton3];
			break;
			
		case kHIDUsage_Button_4:
			[joystick buttonUp: BXEmulatedJoystickButton4];
			break;
			
		case kHIDUsage_Button_4+1:
			[joystick buttonUp: BXCHCombatStickButton5];
			break;
			
		case kHIDUsage_Button_4+2:
			[joystick buttonUp: BXCHCombatStickButton5];
			break;
	}
	//Ignore all other buttons
}

- (void) HIDJoystickAxisChanged: (BXHIDEvent *)event
{
	id <BXEmulatedJoystick> joystick = [self _emulatedJoystick];
	DDHidElement *element = [event element];
	NSInteger position = [event axisPosition];

	
	//Check if the axis is unidirectional like a trigger;
	//if so, map the axis to a range of -65536->0 instead of -65536->65536,
	//where the axis's resting value will be at 0.
	
	BOOL isUniDirectional = ![element minValue] || ![element maxValue];
	if (isUniDirectional)
	{
		position = -(DDHID_JOYSTICK_VALUE_MAX + position) / 2.0f;
	}
	
	//Clamp axis value to 0 if it is within the deadzone.
	if (ABS(position) - BXAxisDeadzone < 0) position = 0;
	
	
	//If the normalized deadzoned position hasn't changed since last time,
	//then ignore this event.
	//(This prevents spurious updates from clobbering other inputs, in the
	//case where multiple inputs are mapped to the same emulated axis.)
	
	NSNumber *hash			= [NSNumber numberWithUnsignedInt: [element cookieAsUnsigned]];
	NSNumber *currentValue	= [NSNumber numberWithInteger: position];
	NSNumber *lastValue		= [lastJoystickValues objectForKey: hash];
	
	if (![lastValue isEqualToNumber: currentValue])
	{
		//The DOS API takes a floating-point range from -1.0 to +1.0.
		float fPosition = (float)position / (float)DDHID_JOYSTICK_VALUE_MAX;
		
		switch ([event axis])
		{
			case kHIDUsage_GD_X:
				[joystick axis: BXEmulatedJoystickAxisX movedTo: fPosition];
				break;
				
			case kHIDUsage_GD_Y:
				[joystick axis: BXEmulatedJoystickAxisY movedTo: fPosition];
				break;
				
			case kHIDUsage_GD_Rx:
			case kHIDUsage_GD_Z:
				[joystick axis: BXEmulatedJoystick2AxisX movedTo: fPosition];
				break;
				
			case kHIDUsage_GD_Ry:
			case kHIDUsage_GD_Rz:
				[joystick axis: BXEmulatedJoystick2AxisY movedTo: fPosition];
				break;
			
			case kHIDUsage_GD_Slider:
				if ([joystick respondsToSelector: @selector(throttleMovedTo:)])
					[(id)joystick throttleMovedTo: fPosition];
				break;
		}
		
		[lastJoystickValues setObject: currentValue forKey: hash];
	}
}

- (void) HIDJoystickPOVSwitchChanged: (BXHIDEvent *)event
{
	id <BXEmulatedJoystick> joystick = [self _emulatedJoystick];
	if ([joystick respondsToSelector: @selector(POVChangedTo:)])
	{
		BXEmulatedPOVDirection direction = (BXEmulatedPOVDirection)[event POVDirection];
		[(id)joystick POVChangedTo: direction];
	}
}

@end
