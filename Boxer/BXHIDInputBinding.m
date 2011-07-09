/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXHIDInputBinding.h"
#import "BXHIDEvent.h"
#import "BXEmulatedJoystick.h"


#define BXDefaultAxisDeadzone 0.25f
#define BXDefaultAxisToButtonThreshold 0.25f


@interface BXBaseHIDInputBinding ()

//A workaround for -performSelector:withObject: only allowing id arguments
- (void) _performSelector: (SEL)selector
				 onTarget: (id)target
				withValue: (void *)value;

//Convert DDHidElement integer axis value into a floating-point range from -1.0 to 1.0.
+ (float) _normalizedAxisValue: (NSInteger)axisValue;

//Convert DDHidElement integer axis value into a floating-point range from 0.0 to 1.0.
+ (float) _normalizedUnidirectionalAxisValue: (NSInteger)axisValue;

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

+ (float) _normalizedAxisValue: (NSInteger)axisValue
{
	return (float)axisValue / (float)DDHID_JOYSTICK_VALUE_MAX;
}

+ (float) _normalizedUnidirectionalAxisValue:(NSInteger)axisValue
{
	float normalizedValue = [self _normalizedAxisValue: axisValue];
	return (normalizedValue + 1.0f) * 0.5f;
}

@end


@implementation BXAxisToAxis
@synthesize deadzone, unidirectional, inverted, axisSelector;

+ (id) bindingWithAxisSelector: (SEL)axis
{
    id binding = [self binding];
    [binding setAxisSelector: axis];
    return binding;
}

- (id) init
{
	if ((self = [super init]))
	{
		[self setDeadzone: BXDefaultAxisDeadzone];
		previousValue = 0.0f;
		unidirectional = NO;
		inverted = NO;
	}
	return self;
}

- (float) _normalizedAxisValue: (NSInteger)axisValue
{	
	float fPosition;
	if ([self isUnidirectional])
	{
		fPosition = [[self class] _normalizedUnidirectionalAxisValue: axisValue];
	}
	else
	{
		fPosition = [[self class] _normalizedAxisValue: axisValue];
	}
	
	//Flip the axis if necessary
	if ([self isInverted]) fPosition *= -1;
	
	//Clamp axis value to 0 if it is within the deadzone.
	if (ABS(fPosition) - [self deadzone] < 0) fPosition = 0;
	
	return fPosition;
}

- (void) processEvent: (BXHIDEvent *)event
			forTarget: (id <BXEmulatedJoystick>)target
{
	float axisValue = [self _normalizedAxisValue: [event axisPosition]];
	if (axisValue != previousValue)
	{
		[self _performSelector: [self axisSelector] onTarget: target withValue: &axisValue];
		previousValue = axisValue;
	}
}

@end


@implementation BXButtonToButton
@synthesize button;

+ (id) bindingWithButton: (NSUInteger)button
{
    id binding = [self binding];
    [binding setButton: button];
    return binding;
}

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

+ (id) bindingWithAxisSelector: (SEL)axis
{
    id binding = [self binding];
    [binding setAxisSelector: axis];
    return binding;
}

- (id) init
{
	if ((self = [super init]))
	{
		[self setPressedValue: 1.0f];
		[self setReleasedValue: 0.0f];
	}
	return self;	
}

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
@synthesize threshold, unidirectional, button;

+ (id) bindingWithButton: (NSUInteger)button
{
    id binding = [self binding];
    [binding setButton: button];
    return binding;
}

- (id) init
{
	if ((self = [super init]))
	{
		[self setThreshold: BXDefaultAxisToButtonThreshold];
		previousValue = NO;
	}
	return self;
}

- (BOOL) _buttonDown: (NSInteger)axisPosition
{
	float fPosition;
	if ([self isUnidirectional])
	{
		fPosition = [[self class] _normalizedUnidirectionalAxisValue: axisPosition];
	}
	else
	{
		fPosition = [[self class] _normalizedAxisValue: axisPosition];
	}

	//Ignore polarity when checking whether the axis is over the threshold:
	//This makes both directions on a bidirectional axis act the same.
	if (ABS(fPosition) > threshold) return YES;
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

- (id) init
{
	if ((self = [super init]))
	{
		[self setPOVSelector: @selector(POVChangedTo:)];
	}
	return self;
}

- (void) processEvent: (BXHIDEvent *)event
			forTarget: (id <BXEmulatedJoystick>)target
{
	BXEmulatedPOVDirection direction = [event POVDirection];
	
	[self _performSelector: [self POVSelector] onTarget: target withValue: &direction];
}

@end


enum {
	BXButtonsToPOVNoButtons = 0,
	BXButtonsToPOVNorthMask	= 1 << 0,
	BXButtonsToPOVSouthMask	= 1 << 1,
	BXButtonsToPOVEastMask	= 1 << 2,
	BXButtonsToPOVWestMask	= 1 << 3
};

@implementation BXButtonsToPOV
@synthesize POVSelector, northButton, southButton, eastButton, westButton;

- (id) init
{
	if ((self = [super init]))
	{
		[self setPOVSelector: @selector(POVChangedTo:)];
	}
	return self;
}

- (void) _syncButtonState: (DDHidElement *)button isDown: (BOOL)down
{
	NSUInteger mask = BXButtonsToPOVNoButtons;
	if		([button isEqual: [self northButton]])	mask = BXButtonsToPOVNorthMask;
	else if	([button isEqual: [self southButton]])	mask = BXButtonsToPOVSouthMask;
	else if	([button isEqual: [self eastButton]])	mask = BXButtonsToPOVEastMask;
	else if	([button isEqual: [self westButton]])	mask = BXButtonsToPOVWestMask;
	
	if (down) buttonStates |= mask;
	else buttonStates &= ~mask;
}

- (BXEmulatedPOVDirection) _POVDirection
{
	BXEmulatedPOVDirection direction = BXEmulatedPOVCentered;
	switch (buttonStates)
	{
		case BXButtonsToPOVNorthMask:
			direction = BXEmulatedPOVNorth; break;
		
		case BXButtonsToPOVSouthMask:
			direction = BXEmulatedPOVSouth; break;
		
		case BXButtonsToPOVEastMask:
			direction = BXEmulatedPOVEast; break;
			
		case BXButtonsToPOVWestMask:
			direction = BXEmulatedPOVWest; break;
			
		case BXButtonsToPOVNorthMask | BXButtonsToPOVEastMask:
			direction = BXEmulatedPOVNorthEast; break;
			
		case BXButtonsToPOVNorthMask | BXButtonsToPOVWestMask:
			direction = BXEmulatedPOVNorthWest; break;
			
		case BXButtonsToPOVSouthMask | BXButtonsToPOVEastMask:
			direction = BXEmulatedPOVSouthEast; break;
			
		case BXButtonsToPOVSouthMask | BXButtonsToPOVWestMask:
			direction = BXEmulatedPOVSouthWest; break;
			
		//All other directions are deliberately ignored,
		//so that mashing all the buttons won't produce odd results
	}
	return direction;
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

+ (id) bindingWithXAxisSelector: (SEL)x
                  YAxisSelector: (SEL)y
{
    id binding = [self binding];
    [binding setXAxisSelector: x];
    [binding setYAxisSelector: y];
    return binding;
}

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

    if ([self xAxisSelector])
        [self _performSelector: [self xAxisSelector] onTarget: target withValue: &x];
    
    if ([self yAxisSelector])
        [self _performSelector: [self yAxisSelector] onTarget: target withValue: &y];
}

@end

@implementation BXAxisToBindings
@synthesize positiveBinding, negativeBinding;

+ (id) bindingWithPositiveAxisSelector: (SEL)positive
                  negativeAxisSelector: (SEL)negative
{
    id binding = [self binding];
    [binding setPositiveBinding: [BXAxisToAxis bindingWithAxisSelector: positive]];
    [binding setNegativeBinding: [BXAxisToAxis bindingWithAxisSelector: negative]];
    return binding;
}

+ (id) bindingWithPositiveButton: (NSUInteger)positive
                  negativeButton: (NSUInteger)negative
{
    id binding = [self binding];
    [binding setPositiveBinding: [BXAxisToButton bindingWithButton: positive]];
    [binding setNegativeBinding: [BXAxisToButton bindingWithButton: negative]];
    return binding;
}                          
                                 
- (id) init
{
    if ((self = [super init]))
    {
		previousValue = 0.0f;
    }
    return self;
}

- (void) dealloc
{
    [self setPositiveBinding: nil], [positiveBinding release];
    [self setNegativeBinding: nil], [negativeBinding release];
    
    [super dealloc];
}

- (void) processEvent: (BXHIDEvent *)event
			forTarget: (id <BXEmulatedJoystick>)target
{
    NSInteger rawValue = [event axisPosition];
	NSInteger positiveValue = (rawValue > 0) ? rawValue : 0;
	NSInteger negativeValue = (rawValue < 0) ? rawValue : 0;

    //A bit ugly - we should clone the event instead - but oh well 
    [event setAxisPosition: positiveValue];
    [[self positiveBinding] processEvent: event forTarget: target];
    
    [event setAxisPosition: negativeValue];
    [[self negativeBinding] processEvent: event forTarget: target];
    
    [event setAxisPosition: rawValue];
}

@end

