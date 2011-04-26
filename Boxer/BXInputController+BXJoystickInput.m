/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXInputControllerPrivate.h"
#import "BXInputHandler.h"
#import "BXAppController.h"
#import "BXJoystickController.h"
#import "BXEmulatedJoystick.h"
#import <IOKit/hid/IOHIDLib.h>


//The multiplier to use when adding a joystick axis's positional input (for e.g. throttle impulses)
//rather than using it as the absolute axis position.
#define BXAdditiveAxisStrength 0.1f

//Default to a 30% deadzone.
#define BXAxisDeadzone 0.3f


@implementation BXInputController (BXJoystickInput)

- (id <BXEmulatedJoystick>) _joystick
{
	return [[[[self controller] document] emulator] joystick];
}

- (void) _syncJoystickType
{
	NSArray *joysticks = [[[NSApp delegate] joystickController] joystickDevices];
	BXEmulator *emulator = [[[self controller] document] emulator];
	
	NSUInteger numJoysticks = [joysticks count];
	if (numJoysticks > 0) [emulator attachJoystickOfType: [BXCHCombatStick class]];
	else [emulator detachJoystick];
}

- (void) HIDJoystickButtonDown: (BXHIDEvent *)event
{
	//BXInputHandler *handler = [self representedObject];
	id <BXEmulatedJoystick> joystick = [self _joystick];
	
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
	}
	//Ignore all other buttons
}

- (void) HIDJoystickButtonUp: (BXHIDEvent *)event
{
	//BXInputHandler *handler = [self representedObject];
	id <BXEmulatedJoystick> joystick = [self _joystick];
	
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
	//BXInputHandler *handler = [self representedObject];
	id <BXEmulatedJoystick> joystick = [self _joystick];
	NSInteger position = [event axisPosition];
	
	//If the current position of the axis falls within the deadzone, then set it to 0
	
	//The DOS API takes a floating-point range from -1.0 to +1.0
	float fPosition = (float)position / (float)DDHID_JOYSTICK_VALUE_MAX;
	
	//Clamp axis value to 0 if it is within the deadzone
	if (ABS(fPosition) - BXAxisDeadzone < 0.0f) fPosition = 0.0f;
	
	//NSLog(@"Axis %@ position: %f", [event element], fPosition);
	
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
			/*
			if (position != 0)
			{
				delta = fPosition * BXAdditiveAxisStrength;
				return [handler joystickAxisChanged: BXDOSFlightstickThrottleAxis byAmount: -delta];
			}
			else return;
			 */
			
		case kHIDUsage_GD_Slider:
			if ([joystick respondsToSelector:@selector(throttleMovedTo:)])
			{
				//Invert the throttle axis
				[(id)joystick throttleMovedTo: -fPosition];
			}
			break;
	}
}

- (void) HIDJoystickPOVSwitchChanged: (BXHIDEvent *)event
{
	id <BXEmulatedJoystick> joystick = [self _joystick];
	if ([joystick respondsToSelector: @selector(POVChangedTo:)])
	{
		BXEmulatedPOVDirection direction = (BXEmulatedPOVDirection)[event POVDirection];
		[(id)joystick POVChangedTo: direction];
	}
}

@end
