/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXHIDEvent.h"
#import <math.h>

@implementation BXHIDEvent
@synthesize type;
@synthesize device, element, stick;
@synthesize stickNumber, POVNumber;
@synthesize axisPosition, axisDelta, POVDirection;


#pragma mark -
#pragma mark Helper class methods

//Normalizes the specified direction to the closest BXHIDPOVSwitchDirection constant.
+ (BXHIDPOVSwitchDirection) closest8WayDirectionForPOV: (NSInteger)direction
{
	if (direction < 0 || direction > 36000) return BXHIDPOVCentered;
	
	NSInteger ordinal = rintf(direction / 4500.0f);
	if (ordinal > 7) ordinal = 0;
	return ordinal * 4500;
}

//Normalizes the specified direction to the closest cardinal BXHIDPOVSwitchDirection constant.
+ (BXHIDPOVSwitchDirection) closest4WayDirectionForPOV: (NSInteger)direction
{
	if (direction < 0 || direction > 36000) return BXHIDPOVCentered;
	
	NSInteger ordinal = rintf(direction / 9000.0f);
	if (ordinal > 3) ordinal = 0;
	return ordinal * 9000;
}


#pragma mark -
#pragma mark Initialization and deallocation

- (id) init
{
	if ((self = [super init]))
	{
		[self setType: BXHIDUnknownEventType];
		[self setPOVDirection: BXHIDPOVCentered];
	}
	return self;
}

- (void) dealloc
{
	[self setDevice: nil], [device release];
	[self setElement: nil], [element release];
	[self setStick: nil], [stick release];
	
	[super dealloc];
}


#pragma mark -
#pragma mark Usage reporting

- (NSUInteger) axis
{
	switch (type)
	{
		case BXHIDJoystickAxisChanged:
		case BXHIDMouseAxisChanged:
			return [[element usage] usageId];
			
		default:
			return kHIDUsage_Undefined;
	}
}

- (NSUInteger) buttonNumber
{
	switch (type)
	{
		case BXHIDMouseButtonUp:
		case BXHIDMouseButtonDown:
		case BXHIDJoystickButtonDown:
		case BXHIDJoystickButtonUp:
			return [[element usage] usageId];
			
		default:
			return kHIDUsage_Undefined;
	}
}

- (NSUInteger) key
{
	switch (type)
	{
		case BXHIDKeyUp:
		case BXHIDKeyDown:
			return [[element usage] usageId];
			
		default:
			return kHIDUsage_Undefined;
	}
}


#pragma mark -
#pragma mark Debugging

- (NSString *)description
{
	switch ([self type])
	{
		case BXHIDJoystickButtonDown:
			return [NSString stringWithFormat: @"HID joystick %1$@ %2$@ pressed", [self device], [self element]];
			
		case BXHIDJoystickButtonUp:
			return [NSString stringWithFormat: @"HID joystick %1$@ %2$@ released", [self device], [self element]];
			
		case BXHIDJoystickAxisChanged:
			return [NSString stringWithFormat: @"HID joystick %1$@ %2$@ changed to %3$i", [self device], [self element], [self axisPosition]];
			
		case BXHIDJoystickPOVSwitchChanged:
			return [NSString stringWithFormat: @"HID joystick %1$@ %2$@ changed to %3$i", [self device], [self element], [self POVDirection]];
			
			
		case BXHIDMouseButtonDown:
			return [NSString stringWithFormat: @"HID mouse %1$@ %2$@ pressed", [self device], [self element]];
			
		case BXHIDMouseButtonUp:
			return [NSString stringWithFormat: @"HID mouse %1$@ %2$@ released", [self device], [self element]];

		case BXHIDMouseAxisChanged:
			return [NSString stringWithFormat: @"HID mouse %1$@ %2$@ changed by %3$i", [self device], [self element], [self axisDelta]];

			
		case BXHIDKeyDown:
			return [NSString stringWithFormat: @"HID keyboard %1$@ %2$@ pressed", [self device], [self element]];
			
		case BXHIDKeyUp:
			return [NSString stringWithFormat: @"HID keyboard %1$@ %2$@ released", [self device], [self element]];
		
			
		case BXHIDUnknownEventType:
		default:
			return [NSString stringWithFormat: @"Unknown HID event %1$@", [super description]];
	}
}
@end


@implementation NSObject (BXHIDEventDispatch)

+ (SEL) delegateMethodForHIDEvent: (BXHIDEvent *)event
{
	switch ([event type])
	{
		case BXHIDMouseAxisChanged:
			return @selector(HIDMouseAxisChanged:);
		case BXHIDMouseButtonDown:
			return @selector(HIDMouseButtonDown:);
		case BXHIDMouseButtonUp:
			return @selector(HIDMouseButtonUp:);
			
		case BXHIDKeyDown:
			return @selector(HIDKeyDown:);
		case BXHIDKeyUp:
			return @selector(HIDKeyUp:);
		
		case BXHIDJoystickAxisChanged:
			return @selector(HIDJoystickAxisChanged:);
		case BXHIDJoystickPOVSwitchChanged:
			return @selector(HIDJoystickPOVSwitchChanged:);
		case BXHIDJoystickButtonDown:
			return @selector(HIDJoystickButtonDown:);
		case BXHIDJoystickButtonUp:
			return @selector(HIDJoystickButtonUp:);
		
		default:
			return NULL;
	}
}

- (void) dispatchHIDEvent: (BXHIDEvent *)event
{
	SEL selector = [[self class] delegateMethodForHIDEvent: event];
	
	if (selector && [self respondsToSelector: selector])
		[self performSelector: selector withObject: event];
}

#pragma mark -
#pragma mark DDHidMouseDelegate methods

- (void) _mouse: (DDHidMouse *)mouse
		   axis: (DDHidElement *)axis
		  delta: (SInt32)value
{
	BXHIDEvent *event = [[BXHIDEvent alloc] init];
	[event setType: BXHIDMouseAxisChanged];
	[event setDevice: mouse];
	[event setElement: axis];
	[event setAxisDelta: value];
	
	[self dispatchHIDEvent: [event autorelease]];
}

- (void) ddhidMouse: (DDHidMouse *)mouse xChanged: (SInt32)deltaX
{
	DDHidElement *axis = [mouse xElement];
	[self _mouse: mouse axis: axis delta: deltaX];
}

- (void) ddhidMouse: (DDHidMouse *)mouse yChanged: (SInt32)deltaY
{
	DDHidElement *axis = [mouse yElement];
	[self _mouse: mouse axis: axis delta: deltaY];
}

- (void) ddhidMouse: (DDHidMouse *)mouse wheelChanged: (SInt32)deltaWheel
{
	DDHidElement *axis = [mouse wheelElement];
	[self _mouse: mouse axis: axis delta: deltaWheel];
}

- (void) ddhidMouse: (DDHidMouse *)mouse buttonDown: (unsigned)buttonNumber
{
	DDHidElement *button = [[mouse buttonElements] objectAtIndex: buttonNumber];
	BXHIDEvent *event = [[BXHIDEvent alloc] init];
	[event setType: BXHIDMouseButtonDown];
	[event setDevice: mouse];
	[event setElement: button];
		
	[self dispatchHIDEvent: [event autorelease]];
}

- (void) ddhidMouse: (DDHidMouse *)mouse buttonUp: (unsigned)buttonNumber
{
	DDHidElement *button = [[mouse buttonElements] objectAtIndex: buttonNumber];
	BXHIDEvent *event = [[BXHIDEvent alloc] init];
	[event setType: BXHIDMouseButtonUp];
	[event setDevice: mouse];
	[event setElement: button];
		
	[self dispatchHIDEvent: [event autorelease]];
}


#pragma mark -
#pragma mark DDHidJoystickDelegate methods

- (void) _joystick: (DDHidJoystick *)joystick
			 stick: (DDHidJoystickStick *)stick
	   stickNumber: (NSUInteger)stickNumber
			  axis: (DDHidElement *)axis
	  valueChanged: (int)value
{
	BXHIDEvent *event = [[BXHIDEvent alloc] init];
	[event setType: BXHIDJoystickAxisChanged];
	[event setDevice: joystick];
	[event setStick: stick];
	[event setStickNumber: stickNumber];
	[event setElement: axis];
	[event setAxisPosition: value];
		
	[self dispatchHIDEvent: [event autorelease]];
}

- (void) ddhidJoystick: (DDHidJoystick *)joystick
                 stick: (unsigned)stickNumber
              xChanged: (int)value
{
	DDHidJoystickStick *stick = [joystick objectInSticksAtIndex: stickNumber];
	DDHidElement *axis = [stick xAxisElement];
	[self _joystick: joystick stick: stick stickNumber: stickNumber axis: axis valueChanged: value];
}

- (void) ddhidJoystick: (DDHidJoystick *)joystick
                 stick: (unsigned)stickNumber
              yChanged: (int)value
{
	DDHidJoystickStick *stick = [joystick objectInSticksAtIndex: stickNumber];
	DDHidElement *axis = [stick yAxisElement];
	[self _joystick: joystick stick: stick stickNumber: stickNumber axis: axis valueChanged: value];
}

- (void) ddhidJoystick: (DDHidJoystick *)joystick
                 stick: (unsigned)stickNumber
             otherAxis: (unsigned)otherAxis
          valueChanged: (int)value
{
	DDHidJoystickStick *stick = [joystick objectInSticksAtIndex: stickNumber];
	DDHidElement *axis = [stick objectInStickElementsAtIndex: otherAxis];
	[self _joystick: joystick stick: stick stickNumber: stickNumber axis: axis valueChanged: value];
}

- (void) ddhidJoystick: (DDHidJoystick *)joystick
                 stick: (unsigned)stickNumber
             povNumber: (unsigned)povNumber
          valueChanged: (int)value
{	
	DDHidJoystickStick *stick = [joystick objectInSticksAtIndex: stickNumber];
	DDHidElement *pov = [stick objectInPovElementsAtIndex: povNumber];
		
	BXHIDEvent *event = [[BXHIDEvent alloc] init];
	[event setType: BXHIDJoystickPOVSwitchChanged];
	[event setDevice: joystick];
	[event setStick: stick];
	[event setStickNumber: stickNumber];
	[event setElement: pov];
	[event setPOVNumber: povNumber];
	[event setPOVDirection: value];

	[self dispatchHIDEvent: [event autorelease]];
}

- (void) ddhidJoystick: (DDHidJoystick *)joystick
            buttonDown: (unsigned)buttonNumber
{
	DDHidElement *button = [[joystick buttonElements] objectAtIndex: buttonNumber];
	BXHIDEvent *event = [[BXHIDEvent alloc] init];
	[event setType: BXHIDJoystickButtonDown];
	[event setDevice: joystick];
	[event setElement: button];
		
	[self dispatchHIDEvent: [event autorelease]];
}

- (void) ddhidJoystick: (DDHidJoystick *)joystick
              buttonUp: (unsigned)buttonNumber
{
	DDHidElement *button = [[joystick buttonElements] objectAtIndex: buttonNumber];
	BXHIDEvent *event = [[BXHIDEvent alloc] init];
	[event setType: BXHIDJoystickButtonUp];
	[event setDevice: joystick];
	[event setElement: button];
		
	[self dispatchHIDEvent: [event autorelease]];
}

#pragma mark -
#pragma mark DDHidKeyboardDelegate methods

- (void) _keyboard:(DDHidKeyboard *)keyboard
		  keyUsage: (unsigned)usageID
		wasPressed: (BOOL)pressed
{
	//FIXME: hugely inefficient. This really demands proper integration with DDHidDevice.
	DDHidElement *matchingKey = nil;
	for (DDHidElement *keyElement in [keyboard keyElements])
	{
		if ([[keyElement usage] usageId] == usageID)
		{
			matchingKey = keyElement;
			break;
		}
	}
	
	if (matchingKey)
	{
		BXHIDEvent *event = [[BXHIDEvent alloc] init];
		[event setType: pressed ? BXHIDKeyDown : BXHIDKeyUp];
		[event setDevice: keyboard];
		[event setElement: matchingKey];
		
		[self dispatchHIDEvent: [event autorelease]];
	}
}

- (void) ddhidKeyboard: (DDHidKeyboard *)keyboard
               keyDown: (unsigned)usageId
{
	if ([self respondsToSelector: @selector(HIDKeyDown:)])
	{
		[self _keyboard: keyboard keyUsage: usageId wasPressed: YES];
	}
}

- (void) ddhidKeyboard: (DDHidKeyboard *) keyboard
                 keyUp: (unsigned) usageId
{
	
	if ([self respondsToSelector: @selector(HIDKeyUp:)])
	{
		[self _keyboard: keyboard keyUsage: usageId wasPressed: NO];
	}
}
		 
@end
