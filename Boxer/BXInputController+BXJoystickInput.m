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
#import <IOKit/hid/IOHIDLib.h>


//The multiplier to use when adding a joystick axis's positional input (for e.g. throttle impulses)
//rather than using it as the absolute axis position.
#define BXAdditiveAxisStrength 0.1f

//Default to a 30% deadzone.
#define BXAxisDeadzone 0.3f


@implementation BXInputController (BXJoystickInput)

- (void) _syncJoystickType
{
	NSArray *joysticks = [[[NSApp delegate] joystickController] joystickDevices];

	NSUInteger numJoysticks = [joysticks count];
	BXDOSJoystickType type = (numJoysticks > 0) ? BXCHFlightstickPro : BXDOSJoystickTypeNone;
	[[self representedObject] setJoystickType: type];
}



- (void) HIDJoystickButtonDown: (BXHIDEvent *)event
{
	BXInputHandler *handler = [self representedObject];
	switch ([event buttonNumber])
	{
		case kHIDUsage_Button_1:
			return [handler joystickButtonPressed: BXDOSJoystickButton1];
			
		case kHIDUsage_Button_2:
			return [handler joystickButtonPressed: BXDOSJoystickButton2];
			
		case kHIDUsage_Button_3:
			return [handler joystickButtonPressed: BXDOSJoystickButton3];
			
		case kHIDUsage_Button_4:
			return [handler joystickButtonPressed: BXDOSJoystickButton4];
	}
	//Ignore all other buttons
}

- (void) HIDJoystickButtonUp: (BXHIDEvent *)event
{
	BXInputHandler *handler = [self representedObject];
	switch ([event buttonNumber])
	{
		case kHIDUsage_Button_1:
			return [handler joystickButtonReleased: BXDOSJoystickButton1];
			
		case kHIDUsage_Button_2:
			return [handler joystickButtonReleased: BXDOSJoystickButton2];
			
		case kHIDUsage_Button_3:
			return [handler joystickButtonReleased: BXDOSJoystickButton3];
			
		case kHIDUsage_Button_4:
			return [handler joystickButtonReleased: BXDOSJoystickButton4];
		
		//TODO: add emulation for CH F-16 Combat Stick buttons 5-6 
	}
	//Ignore all other buttons
}

- (void) HIDJoystickAxisChanged: (BXHIDEvent *)event
{
	BXInputHandler *handler = [self representedObject];
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
			[handler joystickAxisChanged: BXDOSJoystickAxisX toPosition: fPosition];
			break;
			
		case kHIDUsage_GD_Y:
			[handler joystickAxisChanged: BXDOSJoystickAxisY toPosition: fPosition];
			break;
			
		case kHIDUsage_GD_Rx:
		case kHIDUsage_GD_Z:
			[handler joystickAxisChanged: BXDOSJoystick2AxisX toPosition: fPosition];
			break;
			
		case kHIDUsage_GD_Ry:
		case kHIDUsage_GD_Rz:
			[handler joystickAxisChanged: BXDOSJoystick2AxisY toPosition: fPosition];
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
			//Invert the throttle axis
			[handler joystickAxisChanged: BXCHFlightstickThrottleAxis toPosition: -fPosition];
			break;
	}
}

- (void) HIDJoystickPOVSwitchChanged: (BXHIDEvent *)event
{
	BXHIDPOVSwitchDirection direction = [BXHIDEvent closest4WayDirectionForPOV: [event POVDirection]];
	
	//FIXME: why are we using different constants and converting between them
	BXDOSFlightstickPOVDirection dosDirection = BXDOSFlightstickPOVCentered;
	if (direction != BXHIDPOVCentered)
	{
		dosDirection = (direction / 9000) + 1;
	}
	
	[[self representedObject] joystickPOVSwitchChangedToDirection: dosDirection];
}

@end
