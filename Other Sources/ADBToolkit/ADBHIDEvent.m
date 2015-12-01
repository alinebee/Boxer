/*
 *  Copyright (c) 2013, Alun Bestor (alun.bestor@gmail.com)
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *		Redistributions of source code must retain the above copyright notice, this
 *	    list of conditions and the following disclaimer.
 *
 *		Redistributions in binary form must reproduce the above copyright notice,
 *	    this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 *	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 */


#import "ADBHIDEvent.h"
#import <math.h>

@implementation ADBHIDEvent
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

//Normalizes the specified direction to the closest ADBHIDPOVSwitchDirection constant.
+ (ADBHIDPOVSwitchDirection) closest8WayDirectionForPOV: (NSInteger)direction
{
	if (direction < 0 || direction > 36000) return ADBHIDPOVCentered;
	
	NSInteger ordinal = rintf(direction / 4500.0f);
    ordinal = ordinal % 8;
	return ordinal * 4500;
}

//Normalizes the specified direction to the closest cardinal (NSEW) ADBHIDPOVSwitchDirection constant.
+ (ADBHIDPOVSwitchDirection) closest4WayDirectionForPOV: (NSInteger)direction
{
	if (direction < 0 || direction > 36000) return ADBHIDPOVCentered;
	
	NSInteger ordinal = rintf(direction / 9000.0f);
    ordinal = ordinal % 4;
	return ordinal * 9000;
}

//Normalizes the specified direction to the closest cardinal (NSEW) ADBHIDPOVSwitchDirection constant,
//taking into account which cardinal POV direction it was in before.
//This makes the corners 'sticky' so that e.g. N to NE will return N, while E to NE will return E.
//This reduces unintentional switching.
+ (ADBHIDPOVSwitchDirection) closest4WayDirectionForPOV: (NSInteger)direction
										   previousPOV: (ADBHIDPOVSwitchDirection)oldDirection
{
	ADBHIDPOVSwitchDirection closest8WayDirection = [self closest8WayDirectionForPOV: direction];
	ADBHIDPOVSwitchDirection normalizedDirection = closest8WayDirection;
	
	switch (closest8WayDirection)
	{
		case ADBHIDPOVNorthEast:
			normalizedDirection = (oldDirection == ADBHIDPOVNorth) ? ADBHIDPOVNorth : ADBHIDPOVEast;
			break;
			
		case ADBHIDPOVNorthWest:
			normalizedDirection = (oldDirection == ADBHIDPOVNorth) ? ADBHIDPOVNorth : ADBHIDPOVWest;
			break;
			
		case ADBHIDPOVSouthWest:
			normalizedDirection = (oldDirection == ADBHIDPOVSouth) ? ADBHIDPOVSouth : ADBHIDPOVWest;
			break;
			
		case ADBHIDPOVSouthEast:
			normalizedDirection = (oldDirection == ADBHIDPOVSouth) ? ADBHIDPOVSouth : ADBHIDPOVEast;
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
        self.type = ADBHIDUnknownEventType;
        self.POVDirection = ADBHIDPOVCentered;
	}
	return self;
}

- (void) dealloc
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    self.device = nil;
    self.element = nil;
    self.stick = nil;
    
	[super dealloc];
#pragma clang diagnostic pop
}

#pragma mark - Copying

- (id) copyWithZone: (NSZone *)zone
{
    ADBHIDEvent *copy = [[self.class allocWithZone: zone] init];
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
		case ADBHIDJoystickAxisChanged:
		case ADBHIDMouseAxisChanged:
			return self.element.usage.usageId;
			
		default:
			return kHIDUsage_Undefined;
	}
}

- (NSUInteger) buttonNumber
{
	switch (self.type)
	{
		case ADBHIDMouseButtonUp:
		case ADBHIDMouseButtonDown:
		case ADBHIDJoystickButtonDown:
		case ADBHIDJoystickButtonUp:
			return self.element.usage.usageId;
			
		default:
			return kHIDUsage_Undefined;
	}
}

- (NSUInteger) key
{
	switch (self.type)
	{
		case ADBHIDKeyUp:
		case ADBHIDKeyDown:
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
		case ADBHIDJoystickButtonDown:
			return [NSString stringWithFormat: @"HID joystick %1$@ %2$@ pressed", self.device, self.element];
			
		case ADBHIDJoystickButtonUp:
			return [NSString stringWithFormat: @"HID joystick %1$@ %2$@ released", self.device, self.element];
			
		case ADBHIDJoystickAxisChanged:
			return [NSString stringWithFormat: @"HID joystick %1$@ %2$@ changed to %3$li", self.device, self.element, (long)self.axisPosition];
			
		case ADBHIDJoystickPOVSwitchChanged:
			return [NSString stringWithFormat: @"HID joystick %1$@ %2$@ changed to %3$li", self.device, self.element, (long)self.POVDirection];
			
			
		case ADBHIDMouseButtonDown:
			return [NSString stringWithFormat: @"HID mouse %1$@ %2$@ pressed", self.device, self.element];
			
		case ADBHIDMouseButtonUp:
			return [NSString stringWithFormat: @"HID mouse %1$@ %2$@ released", self.device, self.element];

		case ADBHIDMouseAxisChanged:
			return [NSString stringWithFormat: @"HID mouse %1$@ %2$@ changed by %3$li", self.device, self.element, (long)self.axisDelta];

			
		case ADBHIDKeyDown:
			return [NSString stringWithFormat: @"HID keyboard %1$@ %2$@ pressed", self.device, self.element];
			
		case ADBHIDKeyUp:
			return [NSString stringWithFormat: @"HID keyboard %1$@ %2$@ released", self.device, self.element];
		
			
		case ADBHIDUnknownEventType:
		default:
			return [NSString stringWithFormat: @"Unknown HID event %1$@", super.description];
	}
}
@end


@implementation NSObject (ADBHIDEventDispatch)

+ (SEL) delegateMethodForHIDEvent: (ADBHIDEvent *)event
{
	switch (event.type)
	{
		case ADBHIDMouseAxisChanged:
			return @selector(HIDMouseAxisChanged:);
		case ADBHIDMouseButtonDown:
			return @selector(HIDMouseButtonDown:);
		case ADBHIDMouseButtonUp:
			return @selector(HIDMouseButtonUp:);
			
		case ADBHIDKeyDown:
			return @selector(HIDKeyDown:);
		case ADBHIDKeyUp:
			return @selector(HIDKeyUp:);
		
		case ADBHIDJoystickAxisChanged:
			return @selector(HIDJoystickAxisChanged:);
		case ADBHIDJoystickPOVSwitchChanged:
			return @selector(HIDJoystickPOVSwitchChanged:);
		case ADBHIDJoystickButtonDown:
			return @selector(HIDJoystickButtonDown:);
		case ADBHIDJoystickButtonUp:
			return @selector(HIDJoystickButtonUp:);
		
		default:
			return NULL;
	}
}

- (void) dispatchHIDEvent: (ADBHIDEvent *)event
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
	ADBHIDEvent *event = [[ADBHIDEvent alloc] init];
    event.type = ADBHIDMouseAxisChanged;
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
	ADBHIDEvent *event = [[ADBHIDEvent alloc] init];
	event.type = ADBHIDMouseButtonDown;
	event.device = mouse;
	event.element = button;
		
	[self dispatchHIDEvent: event];
    [event release];
}

- (void) ddhidMouse: (DDHidMouse *)mouse buttonUp: (unsigned)buttonNumber
{
	DDHidElement *button = [mouse.buttonElements objectAtIndex: buttonNumber];
	ADBHIDEvent *event = [[ADBHIDEvent alloc] init];
    event.type = ADBHIDMouseButtonUp;
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
	ADBHIDEvent *event = [[ADBHIDEvent alloc] init];
    event.type = ADBHIDJoystickAxisChanged;
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
		
	ADBHIDEvent *event = [[ADBHIDEvent alloc] init];
    event.type = ADBHIDJoystickPOVSwitchChanged;
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
	ADBHIDEvent *event = [[ADBHIDEvent alloc] init];
    event.type = ADBHIDJoystickButtonDown;
    event.device = joystick;
    event.element = button;
    
	[self dispatchHIDEvent: event];
    [event release];
}

- (void) ddhidJoystick: (DDHidJoystick *)joystick
              buttonUp: (unsigned)buttonNumber
{
	DDHidElement *button = [joystick.buttonElements objectAtIndex: buttonNumber];
	ADBHIDEvent *event = [[ADBHIDEvent alloc] init];
    event.type = ADBHIDJoystickButtonUp;
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
		ADBHIDEvent *event = [[ADBHIDEvent alloc] init];
        event.type = pressed ? ADBHIDKeyDown : ADBHIDKeyUp;
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
