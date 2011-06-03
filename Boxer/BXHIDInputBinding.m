/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXHIDInputBinding.h"
#import "BXHIDEvent.h"
#import "BXEmulatedJoystick.h"

@interface BXBaseHIDInputBinding ()

//A workaround for -performSelector:withObject: only allowing id arguments
- (void) _performSelector: (SEL)selector
				 onTarget: (id)target
				withValue: (void *)value;

@end

@implementation BXBaseHIDInputBinding

+ (id) binding
{
	return [[[self alloc] init] autorelease];
}

- (void) _performSelector: (SEL)selector
				 onTarget: (id)target
				withValue: (void *)value
{
	NSMethodSignature *signature = [target methodSignatureForSelector: selector];
	NSInvocation *action = [NSInvocation invocationWithMethodSignature: signature];
	[action setSelector: selector];
	[action setTarget: target];
	[action setArgument: value atIndex: 2];
	[action invoke];
}

- (void) processEvent: (BXHIDEvent *)event
			forTarget: (id <BXEmulatedJoystick>)target
{
	//Unimplemented at this level, must be overridden in subclasses
	[self doesNotRecognizeSelector: _cmd];
}

@end


@implementation BXAxisToAxis
@synthesize deadzone, axisSelector;

- (id) init
{
	if ((self = [super init]))
	{
		deadzone = 0.25f;
		previousValue = 0.0f;
	}
	return self;
}

- (float) _normalizedAxisPosition: (NSInteger)axisPosition
{	
	//BXEmulatedJoystick takes a floating-point range from -1.0 to +1.0.
	float fPosition = (float)axisPosition / (float)DDHID_JOYSTICK_VALUE_MAX;
	
	//Clamp axis value to 0 if it is within the deadzone.
	if (ABS(fPosition) - [self deadzone] < 0) fPosition = 0;
	
	return fPosition;
}

- (void) processEvent: (BXHIDEvent *)event
			forTarget: (id <BXEmulatedJoystick>)target
{
	float axisValue = [self _normalizedAxisPosition: [event axisPosition]];
	if (axisValue != previousValue)
	{
		[self _performSelector: [self axisSelector] onTarget: target withValue: &axisValue];
		previousValue = axisValue;
	}
}

@end


@implementation BXButtonToButton
@synthesize button;

- (void) processEvent: (BXHIDEvent *)event
			forTarget: (id <BXEmulatedJoystick>)target
{
	BOOL buttonDown = ([event type] == BXHIDJoystickButtonDown);
	if (buttonDown)
		[target buttonDown: [self button]];
	else
		[target buttonUp: [self button]];
}

@end


@implementation BXButtonToAxis
@synthesize pressedValue, releasedValue, axisSelector;

- (void) processEvent: (BXHIDEvent *)event
			forTarget: (id <BXEmulatedJoystick>)target
{
	float axisValue;
	if ([event type] == BXHIDJoystickButtonDown)
		axisValue = [self pressedValue];
	else
		axisValue = [self releasedValue];
	
	[self _performSelector: [self axisSelector] onTarget: target withValue: &axisValue];
}

@end



@implementation BXAxisToButton
@synthesize threshold, button;

- (id) init
{
	if ((self = [super init]))
	{
		threshold = 0.5f;
		previousValue = NO;
	}
	return self;
}

- (BOOL) _buttonDown: (NSInteger)axisPosition
{
	if (axisPosition > threshold) return YES;
	return NO;
}

- (void) processEvent: (BXHIDEvent *)event
			forTarget: (id <BXEmulatedJoystick>)target
{
	BOOL buttonDown = [self _buttonDown: [event axisPosition]];
	
	if (buttonDown != previousValue)
	{
		if (buttonDown)
			[target buttonDown: [self button]];
		else
			[target buttonUp: [self button]];
		
		previousValue = buttonDown;
	}
}

@end


@implementation BXPOVToPOV
@synthesize POVSelector;

- (void) processEvent: (BXHIDEvent *)event
			forTarget: (id <BXEmulatedJoystick>)target
{
	BXEmulatedPOVDirection direction = [event POVDirection];
	
	[self _performSelector: [self POVSelector] onTarget: target withValue: &direction];
}

@end


@implementation BXButtonsToPOV
@synthesize POVSelector, northButton, southButton, eastButton, westButton;

- (void) _syncButtonState: (DDHidElement *)button isDown: (BOOL)down
{
	if		([button isEqual: [self northButton]])	northDown = down;
	else if	([button isEqual: [self southButton]])	southDown = down;
	else if	([button isEqual: [self eastButton]])	eastDown = down;
	else if	([button isEqual: [self westButton]])	westDown = down;
}

- (BXEmulatedPOVDirection) _POVDirection
{
	//Surely there's a more elegant way than this, but doing it with bitflags just ended up being more code
	if (northDown && eastDown)	return BXEmulatedPOVNorthEast;
	if (northDown && westDown)	return BXEmulatedPOVNorthWest;
	if (southDown && westDown)	return BXEmulatedPOVSouthWest;
	if (southDown && eastDown)	return BXEmulatedPOVSouthEast;
	
	if (northDown)				return BXEmulatedPOVNorth;
	if (southDown)				return BXEmulatedPOVSouth;
	if (eastDown)				return BXEmulatedPOVEast;
	if (westDown)				return BXEmulatedPOVWest;
}

- (void) processEvent: (BXHIDEvent *)event
			forTarget: (id <BXEmulatedJoystick>)target
{
	DDHidElement *button = [event element];
	BOOL down = ([event type] == BXHIDJoystickButtonDown);
	[self _syncButtonState: button isDown: down];
	
	BXEmulatedPOVDirection direction = [self _POVDirection];
	
	[self _performSelector: [self POVSelector] onTarget: target withValue: &direction];
}

@end


@implementation BXPOVToAxes
@synthesize xAxisSelector, yAxisSelector;

- (void) processEvent: (BXHIDEvent *)event
			forTarget: (id <BXEmulatedJoystick>)target
{
	BXHIDPOVSwitchDirection direction = [event POVDirection];
	
	float x, y;
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

	[self _performSelector: [self xAxisSelector] onTarget: target withValue: &x];
	[self _performSelector: [self yAxisSelector] onTarget: target withValue: &y];
}

@end