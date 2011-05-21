/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXInputControllerPrivate.h"
#import "BXAppController.h"
#import "BXJoystickController.h"
#import "DDHidDevice+BXDeviceExtensions.h"


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
	
	NSArray *controllers = [[[NSApp delegate] joystickController] joystickDevices];
	NSUInteger numControllers = [controllers count];
	
	if (numControllers > 0)
	{
		Class joystickClass;
		
		//TODO: more sophisticated heuristics here for determining a suitable joystick type
		if (support == BXJoystickSupportFull) joystickClass = [BX4AxisJoystick class];
		else joystickClass = [BX2AxisJoystick class];
		
		if (![[emulator joystick] isKindOfClass: joystickClass])
			[emulator attachJoystickOfType: joystickClass];
		
		//Record which of the devices will be considered the main input device
		primaryController = [controllers objectAtIndex: 0];
	}
	else
	{
		[emulator detachJoystick];
		primaryController = nil;
	}
}

- (void) HIDJoystickButtonDown: (BXHIDEvent *)event
{
	[self _handleHIDJoystickButtonEvent: event];
}

- (void) HIDJoystickButtonUp: (BXHIDEvent *)event
{
	[self _handleHIDJoystickButtonEvent: event];
}

- (void) _handleHIDJoystickButtonEvent: (BXHIDEvent *)event
{
	id <BXEmulatedJoystick> joystick = [self _emulatedJoystick];
	BOOL isPrimaryController = [[event device] isEqual: primaryController];
	//Disabled for now because it irritates the hell out of me
	BOOL wrapButtons = NO;
	
	NSUInteger numEmulatedButtons = [joystick numButtons];
	NSUInteger realButton = [event buttonNumber];
	
	//Remap buttons 1 and 2 on secondary controllers to buttons 1 and 2 on the second joystick
	//(or buttons 3 and 4 on a 4-button joystick)
	if (!isPrimaryController && (realButton == kHIDUsage_Button_1 || realButton == kHIDUsage_Button_2))
		realButton += 2;
	
	NSUInteger emulatedButton = realButton;
	if (wrapButtons)
	{
		//Wrap controller buttons so that they'll all fit within the number of emulated buttons
		emulatedButton = ((realButton - 1) % numEmulatedButtons) + 1;
	}
	
	if ([event type] == BXHIDJoystickButtonDown)
	{
		[joystick buttonDown: emulatedButton];
	}
	else
	{
		[joystick buttonUp: emulatedButton];
	}	
}

- (NSInteger) _normalizedAxisPositionForEvent: (BXHIDEvent *)event
{
	NSInteger position = [event axisPosition];
	
	//Check if the axis is unidirectional like a trigger;
	//if so, map the axis to a range of 0->65536 instead of -65536->65536,
	//so the axis's resting value will be at 0.
	BOOL isUniDirectional = ([[event element] minValue] == 0);
	
	//Disabled for now because this heuristic isn't good enough: some controllers
	//map their regular axes from 0->[maxvalue] and have their resting value halfway,
	//and we can't detect these.
	isUniDirectional = NO;
	
	if (isUniDirectional)
	{
		position = (DDHID_JOYSTICK_VALUE_MAX + position) / 2.0f;
	}
	
	//Clamp axis value to 0 if it is within the deadzone.
	if (ABS(position) - BXAxisDeadzone < 0) position = 0;
	
	return position;
}

- (void) HIDJoystickAxisChanged: (BXHIDEvent *)event
{
	id <BXEmulatedJoystick> joystick = [self _emulatedJoystick];
	DDHidElement *element = [event element];
	
	BOOL isPrimaryController = [[event device] isEqual: primaryController];
	
	NSInteger position = [self _normalizedAxisPositionForEvent: event];
	NSInteger lastPosition = [lastJoystickValues integerValueForHIDElement: element];
	
	//Only update the joystick if the element's value has changed since last time.
	//(This prevents deadzoned updates from clobbering other inputs if there are
	//multiple inputs mapped to the same emulated axis.)
	if (position != lastPosition)
	{
		//The DOS API takes a floating-point range from -1.0 to +1.0.
		float fPosition = (float)position / (float)DDHID_JOYSTICK_VALUE_MAX;
		
		BXEmulatedJoystickAxis emulatedAxis;
		switch ([event axis])
		{
			case kHIDUsage_GD_X:
				//If the input comes from an additional controller, send it to the second emulated joystick
				if (!isPrimaryController && [joystick numAxes] > 2) emulatedAxis = BXEmulatedJoystick2AxisX;
				else emulatedAxis = BXEmulatedJoystickAxisX;
				[joystick axis: emulatedAxis movedTo: fPosition];
				break;
				
			case kHIDUsage_GD_Y:
				//If the input comes from an additional controller, send it to the second emulated joystick
				if (!isPrimaryController && [joystick numAxes] > 2) emulatedAxis = BXEmulatedJoystick2AxisY;
				else emulatedAxis = BXEmulatedJoystickAxisY;
				[joystick axis: emulatedAxis movedTo: fPosition];
				break;
				
			case kHIDUsage_GD_Rx:
			case kHIDUsage_GD_Z:
				if ([joystick respondsToSelector: @selector(rudderMovedTo:)])
					[(id)joystick rudderMovedTo: fPosition];
				else
					[joystick axis: BXEmulatedJoystickAxisX2 movedTo: fPosition];
				break;
				
			case kHIDUsage_GD_Ry:
			case kHIDUsage_GD_Rz:
			case kHIDUsage_GD_Slider:
				//NOTE: certain joysticks use Rz/Slider as a stick pair, or use Rz as a twist-axis for rudder
				//control and Slider as vertical. We should check for the existence of a Slider axis and map Rz
				//to X2 in that instance.
				
				
				if ([joystick respondsToSelector: @selector(throttleMovedTo:)])
					[(id)joystick throttleMovedTo: fPosition];
				else
					[joystick axis: BXEmulatedJoystickAxisY2 movedTo: fPosition];
				break;
		}
		
		[lastJoystickValues setIntegerValue: position forHIDElement: element];
	}
}

- (void) HIDJoystickPOVSwitchChanged: (BXHIDEvent *)event
{
	id <BXEmulatedJoystick> joystick = [self _emulatedJoystick];
	BOOL isPrimaryController = [[event device] isEqual: primaryController];
	
	//If the emulated joystick has a POV switch, send the signal to the joystick as-is
	if ([joystick respondsToSelector: @selector(POVChangedTo:)])
	{
		BXEmulatedPOVDirection direction = (BXEmulatedPOVDirection)[event POVDirection];
		[(id)joystick POVChangedTo: direction];
	}
	//Otherwise, make the POV switch simulate the X and Y axes instead
	//(This makes sense because gamepads often map their D-pad as a POV switch)
	else
	{
		BXEmulatedJoystickAxis xAxis = BXEmulatedJoystickAxisX;
		BXEmulatedJoystickAxis yAxis = BXEmulatedJoystickAxisY;
		
		//Map secondary controller hats or secondary POV switches to the 2nd joystick's axes instead
		if (!isPrimaryController || [event POVNumber] > 0)
		{
			xAxis = BXEmulatedJoystick2AxisX;
			yAxis = BXEmulatedJoystick2AxisY;
		}
		
		float x, y;
		
		NSInteger direction = [BXHIDEvent closest8WayDirectionForPOV: [event POVDirection]];

		//Would return much the same result as the switch statement below,
		//but is more expensive to compute and doesn't handle corners well.
		//This would handle POV switches that return arbitrary angles however.
		//if (direction != BXHIDPOVCentered)
//		{
//			float radians = (float)(((direction / 100) + 90) * (M_PI / 180.0f));
//			x = -cosf(radians);
//			y = -sinf(radians);
//		}
		
		switch (direction)
		{
			case BXHIDPOVNorth:
				x=0.0f, y=-1.0f;
				break;
			case BXHIDPOVNorthEast:
				x=1.0f, y=-1.0f;
				break;
			case BXHIDPOVEast:
				x=1.0f, y=0.0f;
				break;
			case BXHIDPOVSouthEast:
				x=1.0f, y=1.0f;
				break;
			case BXHIDPOVSouth:
				x=0.0f, y=1.0f;
				break;
			case BXHIDPOVSouthWest:
				x=-1.0f, y=1.0f;
				break;
			case BXHIDPOVWest:
				x=-1.0f, y=0.0f;
				break;
			case BXHIDPOVNorthWest:
				x=-1.0f, y=-1.0f;
				break;
			case BXHIDPOVCentered:
			default:
				x= 0.0f, y=0.0f;
		}
		
		[joystick axis: xAxis movedTo: x];
		[joystick axis: yAxis movedTo: y];
	}
}

@end



//Some extension methods to NSDictionary to make it easier for us to record and retrieve
//controller values from our lastJoystickValues dictionary
@implementation NSMutableDictionary (BXHIDElementValueRecording)

- (id) keyForHIDElement:  (DDHidElement *)element
{
	return [NSNumber numberWithUnsignedInt: [element cookieAsUnsigned]];
}

- (NSInteger) integerValueForHIDElement: (DDHidElement *)element
{
	id elementKey = [self keyForHIDElement: element];
	return [[self objectForKey: elementKey] integerValue];
}

- (void) setIntegerValue: (NSInteger)value forHIDElement: (DDHidElement *)element
{
	NSNumber *number = [NSNumber numberWithInteger: value];
	id elementKey = [self keyForHIDElement: element];
	[self setObject: number forKey: elementKey];
}
@end
