/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXHIDEvent.h"
#import <math.h>

@implementation BXHIDEvent
@synthesize type = _type;
@synthesize device = _device;
@synthesize element = _element;
@synthesize stick = _stick;
@synthesize stickNumber = _stickNumber;
@synthesize POVNumber = _POVNumber;
@synthesize axisPosition = _axisPosition;
@synthesize axisDelta = _axisDelta;
@synthesize POVDirection = _POVDirection;


#pragma mark -
#pragma mark Helper class methods

//Normalizes the specified direction to the closest BXHIDPOVSwitchDirection constant.
+ (BXHIDPOVSwitchDirection) closest8WayDirectionForPOV: (NSInteger)direction
{
	if (direction < 0 || direction > 36000) return BXHIDPOVCentered;
	
	NSInteger ordinal = rintf(direction / 4500.0f);
    ordinal = ordinal % 8;
	return ordinal * 4500;
}

//Normalizes the specified direction to the closest cardinal (NSEW) BXHIDPOVSwitchDirection constant.
+ (BXHIDPOVSwitchDirection) closest4WayDirectionForPOV: (NSInteger)direction
{
	if (direction < 0 || direction > 36000) return BXHIDPOVCentered;
	
	NSInteger ordinal = rintf(direction / 9000.0f);
    ordinal = ordinal % 4;
	return ordinal * 9000;
}

//Normalizes the specified direction to the closest cardinal (NSEW) BXHIDPOVSwitchDirection constant,
//taking into account which cardinal POV direction it was in before.
//This makes the corners 'sticky' so that e.g. N to NE will return N, while E to NE will return E.
//This reduces unintentional switching.
+ (BXHIDPOVSwitchDirection) closest4WayDirectionForPOV: (NSInteger)direction
										   previousPOV: (BXHIDPOVSwitchDirection)oldDirection
{
	BXHIDPOVSwitchDirection closest8WayDirection = [self closest8WayDirectionForPOV: direction];
	BXHIDPOVSwitchDirection normalizedDirection = closest8WayDirection;
	
	switch (closest8WayDirection)
	{
		case BXHIDPOVNorthEast:
			normalizedDirection = (oldDirection == BXHIDPOVNorth) ? BXHIDPOVNorth : BXHIDPOVEast;
			break;
			
		case BXHIDPOVNorthWest:
			normalizedDirection = (oldDirection == BXHIDPOVNorth) ? BXHIDPOVNorth : BXHIDPOVWest;
			break;
			
		case BXHIDPOVSouthWest:
			normalizedDirection = (oldDirection == BXHIDPOVSouth) ? BXHIDPOVSouth : BXHIDPOVWest;
			break;
			
		case BXHIDPOVSouthEast:
			normalizedDirection = (oldDirection == BXHIDPOVSouth) ? BXHIDPOVSouth : BXHIDPOVEast;
			break;
	}
	return normalizedDirection;
}


#pragma mark -
#pragma mark Initialization and deallocation

- (id) init
{
    self = [super init];
	if (self)
	{
        self.type = BXHIDUnknownEventType;
        self.POVDirection = BXHIDPOVCentered;
	}
	return self;
}

- (void) dealloc
{
    self.device = nil;
    self.element = nil;
    self.stick = nil;
    
	[super dealloc];
}

#pragma mark - Copying

- (id) copyWithZone: (NSZone *)zone
{
    BXHIDEvent *copy = [[self.class allocWithZone: zone] init];
    copy.type = self.type;
    
    copy.device = self.device;
    copy.element = self.element;
    
    copy.stick = self.stick;
    copy.stickNumber = self.stickNumber;
    
    copy.axisDelta = self.axisDelta;
    copy.axisPosition = self.axisPosition;
    
    copy.POVNumber = self.POVNumber;
    copy.POVDirection = self.POVDirection;
    
    return copy;
}


#pragma mark - Usage reporting

- (NSUInteger) axis
{
	switch (self.type)
	{
		case BXHIDJoystickAxisChanged:
		case BXHIDMouseAxisChanged:
			return self.element.usage.usageId;
			
		default:
			return kHIDUsage_Undefined;
	}
}

- (NSUInteger) buttonNumber
{
	switch (self.type)
	{
		case BXHIDMouseButtonUp:
		case BXHIDMouseButtonDown:
		case BXHIDJoystickButtonDown:
		case BXHIDJoystickButtonUp:
			return self.element.usage.usageId;
			
		default:
			return kHIDUsage_Undefined;
	}
}

- (NSUInteger) key
{
	switch (self.type)
	{
		case BXHIDKeyUp:
		case BXHIDKeyDown:
			return self.element.usage.usageId;
			
		default:
			return kHIDUsage_Undefined;
	}
}


#pragma mark -
#pragma mark Debugging

- (NSString *)description
{
	switch (self.type)
	{
		case BXHIDJoystickButtonDown:
			return [NSString stringWithFormat: @"HID joystick %1$@ %2$@ pressed", self.device, self.element];
			
		case BXHIDJoystickButtonUp:
			return [NSString stringWithFormat: @"HID joystick %1$@ %2$@ released", self.device, self.element];
			
		case BXHIDJoystickAxisChanged:
			return [NSString stringWithFormat: @"HID joystick %1$@ %2$@ changed to %3$li", self.device, self.element, (long)self.axisPosition];
			
		case BXHIDJoystickPOVSwitchChanged:
			return [NSString stringWithFormat: @"HID joystick %1$@ %2$@ changed to %3$li", self.device, self.element, (long)self.POVDirection];
			
			
		case BXHIDMouseButtonDown:
			return [NSString stringWithFormat: @"HID mouse %1$@ %2$@ pressed", self.device, self.element];
			
		case BXHIDMouseButtonUp:
			return [NSString stringWithFormat: @"HID mouse %1$@ %2$@ released", self.device, self.element];

		case BXHIDMouseAxisChanged:
			return [NSString stringWithFormat: @"HID mouse %1$@ %2$@ changed by %3$li", self.device, self.element, (long)self.axisDelta];

			
		case BXHIDKeyDown:
			return [NSString stringWithFormat: @"HID keyboard %1$@ %2$@ pressed", self.device, self.element];
			
		case BXHIDKeyUp:
			return [NSString stringWithFormat: @"HID keyboard %1$@ %2$@ released", self.device, self.element];
		
			
		case BXHIDUnknownEventType:
		default:
			return [NSString stringWithFormat: @"Unknown HID event %1$@", super.description];
	}
}
@end


@implementation NSObject (BXHIDEventDispatch)

+ (SEL) delegateMethodForHIDEvent: (BXHIDEvent *)event
{
	switch (event.type)
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
	SEL selector = [self.class delegateMethodForHIDEvent: event];
	
	if (selector && [self respondsToSelector: selector])
		[self performSelector: selector withObject: event];
}

#pragma mark - DDHidMouseDelegate methods

- (void) _mouse: (DDHidMouse *)mouse
		   axis: (DDHidElement *)axis
		  delta: (SInt32)value
{
	BXHIDEvent *event = [[BXHIDEvent alloc] init];
    event.type = BXHIDMouseAxisChanged;
	event.device = mouse;
	event.element = axis;
	event.axisDelta = value;
	
	[self dispatchHIDEvent: event];
    [event release];
}

- (void) ddhidMouse: (DDHidMouse *)mouse xChanged: (SInt32)deltaX
{
	DDHidElement *axis = mouse.xElement;
	[self _mouse: mouse axis: axis delta: deltaX];
}

- (void) ddhidMouse: (DDHidMouse *)mouse yChanged: (SInt32)deltaY
{
	DDHidElement *axis = mouse.yElement;
	[self _mouse: mouse axis: axis delta: deltaY];
}

- (void) ddhidMouse: (DDHidMouse *)mouse wheelChanged: (SInt32)deltaWheel
{
	DDHidElement *axis = mouse.wheelElement;
	[self _mouse: mouse axis: axis delta: deltaWheel];
}

- (void) ddhidMouse: (DDHidMouse *)mouse buttonDown: (unsigned)buttonNumber
{
	DDHidElement *button = [mouse.buttonElements objectAtIndex: buttonNumber];
	BXHIDEvent *event = [[BXHIDEvent alloc] init];
	event.type = BXHIDMouseButtonDown;
	event.device = mouse;
	event.element = button;
		
	[self dispatchHIDEvent: event];
    [event release];
}

- (void) ddhidMouse: (DDHidMouse *)mouse buttonUp: (unsigned)buttonNumber
{
	DDHidElement *button = [mouse.buttonElements objectAtIndex: buttonNumber];
	BXHIDEvent *event = [[BXHIDEvent alloc] init];
    event.type = BXHIDMouseButtonUp;
    event.device = mouse;
    event.element = button;
    
	[self dispatchHIDEvent: event];
    [event release];
}


#pragma mark - DDHidJoystickDelegate methods

- (void) _joystick: (DDHidJoystick *)joystick
			 stick: (DDHidJoystickStick *)stick
	   stickNumber: (NSUInteger)stickNumber
			  axis: (DDHidElement *)axis
	  valueChanged: (int)value
{
	BXHIDEvent *event = [[BXHIDEvent alloc] init];
    event.type = BXHIDJoystickAxisChanged;
    event.device = joystick;
    event.stick = stick;
    event.stickNumber = stickNumber;
    event.element = axis;
    event.axisPosition = value;
    
	[self dispatchHIDEvent: event];
    [event release];
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
    event.type = BXHIDJoystickPOVSwitchChanged;
    event.device = joystick;
    event.stick = stick;
    event.stickNumber = stickNumber;
    event.element = pov;
    event.POVNumber = povNumber;
    event.POVDirection = value;

	[self dispatchHIDEvent: event];
    [event release];
}

- (void) ddhidJoystick: (DDHidJoystick *)joystick
            buttonDown: (unsigned)buttonNumber
{
	DDHidElement *button = [joystick.buttonElements objectAtIndex: buttonNumber];
	BXHIDEvent *event = [[BXHIDEvent alloc] init];
    event.type = BXHIDJoystickButtonDown;
    event.device = joystick;
    event.element = button;
    
	[self dispatchHIDEvent: event];
    [event release];
}

- (void) ddhidJoystick: (DDHidJoystick *)joystick
              buttonUp: (unsigned)buttonNumber
{
	DDHidElement *button = [joystick.buttonElements objectAtIndex: buttonNumber];
	BXHIDEvent *event = [[BXHIDEvent alloc] init];
    event.type = BXHIDJoystickButtonUp;
    event.device = joystick;
    event.element = button;
    
	[self dispatchHIDEvent: event];
    [event release];
}

#pragma mark -
#pragma mark DDHidKeyboardDelegate methods

- (void) _keyboard:(DDHidKeyboard *)keyboard
		  keyUsage: (unsigned)usageID
		wasPressed: (BOOL)pressed
{
	//FIXME: hugely inefficient. This really demands proper integration with DDHidDevice.
	DDHidElement *matchingKey = nil;
	for (DDHidElement *keyElement in keyboard.keyElements)
	{
		if (keyElement.usage.usageId == usageID)
		{
			matchingKey = keyElement;
			break;
		}
	}
	
	if (matchingKey)
	{
		BXHIDEvent *event = [[BXHIDEvent alloc] init];
        event.type = pressed ? BXHIDKeyDown : BXHIDKeyUp;
        event.device = keyboard;
        event.element = matchingKey;
        
        [self dispatchHIDEvent: event];
        [event release];
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
