/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXHIDInputBinding.h"
#import "BXHIDEvent.h"
#import "BXEmulatedJoystick.h"
#import "DDHidUsage+BXUsageExtensions.h"


#define BXDefaultAxisDeadzone 0.15f
#define BXDefaultAxisToButtonThreshold 0.25f
#define BXDefaultButtonToAxisPressedValue 1.0f
#define BXDefaultButtonToAxisReleasedValue 0.0f

#define BXDefaultAdditiveAxisEmulatedDeadzone 0.05f
#define BXDefaultAdditiveAxisRate 2.0f //Go from 0 to max in half a second
#define BXDefaultAdditiveAxisInputRate 30.0 //30 frames per second


@interface BXBaseHIDInputBinding ()

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

//Empty implementations to respect the NSCoding protocol.
//These must be overridden in subclasses.
- (id) initWithCoder: (NSCoder *)coder
{
    return [self init];
}

- (void) encodeWithCoder: (NSCoder *)coder
{
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

+ (float) _normalizedUnidirectionalAxisValue: (NSInteger)axisValue
{
	float normalizedValue = [self _normalizedAxisValue: axisValue];
	return (normalizedValue + 1.0f) * 0.5f;
}

@end


@implementation BXAxisToAxis
@synthesize deadzone, unidirectional, inverted, axis;

+ (id) bindingWithAxis: (NSString *)axisName
{
    id binding = [self binding];
    [binding setAxis: axisName];
    return binding;
}

- (id) init
{
	if ((self = [super init]))
	{
		[self setDeadzone: BXDefaultAxisDeadzone];
        [self setUnidirectional: NO];
        [self setInverted: NO];
        
		previousValue = 0.0f;
	}
	return self;
}

- (void) dealloc
{
    [self setAxis: nil], [axis release];
    [super dealloc];
}

- (id) initWithCoder: (NSCoder *)coder
{
    if ((self = [super initWithCoder: coder]))
    {
        [self setAxis: [coder decodeObjectForKey: @"axis"]];
         
        if ([coder containsValueForKey: @"deadzone"])
            [self setDeadzone: [coder decodeFloatForKey: @"deadzone"]];
        
        [self setInverted: [coder decodeBoolForKey: @"inverted"]];
        [self setUnidirectional: [coder decodeBoolForKey: @"trigger"]];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
    [super encodeWithCoder: coder];
    
    [coder encodeObject: [self axis] forKey: @"axis"];
    
    //Don’t persist defaults
    if ([self deadzone] != BXDefaultAxisDeadzone)
        [coder encodeFloat: [self deadzone] forKey: @"deadzone"];
    
    if ([self isInverted] != NO) 
        [coder encodeBool: [self isInverted] forKey: @"inverted"];
    
    if ([self isUnidirectional] != NO) 
        [coder encodeBool: [self isUnidirectional] forKey: @"trigger"];
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
        [(id)target setValue: [NSNumber numberWithFloat: axisValue] forKey: [self axis]];
		previousValue = axisValue;
	}
}

@end


@implementation BXAxisToAxisAdditive
@synthesize ratePerSecond, delegate, emulatedDeadzone;

- (id) init
{
	if ((self = [super init]))
	{
		[self setRatePerSecond: BXDefaultAdditiveAxisRate];
        [self setEmulatedDeadzone: BXDefaultAdditiveAxisEmulatedDeadzone];
	}
	return self;
}

- (id) initWithCoder: (NSCoder *)coder
{
    if ((self = [super initWithCoder: coder]))
    {
        if ([coder containsValueForKey: @"strength"])
            [self setRatePerSecond: [coder decodeFloatForKey: @"strength"]];
        
        if ([coder containsValueForKey: @"emulated deadzone"])
            [self setEmulatedDeadzone: [coder decodeFloatForKey: @"emulated deadzone"]];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
    [super encodeWithCoder: coder];
    
    //Don’t persist defaults
    if ([self ratePerSecond] != BXDefaultAdditiveAxisRate)
        [coder encodeFloat: [self ratePerSecond] forKey: @"strength"];
    
    if ([self emulatedDeadzone] != BXDefaultAdditiveAxisEmulatedDeadzone)
        [coder encodeFloat: [self emulatedDeadzone] forKey: @"emulated deadzone"];
        
}

#pragma mark -
#pragma mark Timed updates

- (void) _updateWithTimer: (NSTimer *)timer
{
    if (previousValue != 0.0f)
    {
        id target = [timer userInfo];
 
        float increment = ([self ratePerSecond] * previousValue) / (float)BXDefaultAdditiveAxisInputRate;
    
        float currentValue = [[target valueForKey: [self axis]] floatValue];
        float newValue = currentValue + increment;
        
        //Apply a deadzone to the incremeneted value to snap very low values to 0.
        //This make it easier to center the input.
        if ((ABS(newValue) - [self emulatedDeadzone]) < 0) newValue = 0;
        
        [target setValue: [NSNumber numberWithFloat: newValue] forKey: [self axis]];
        
        [[self delegate] binding: self didSendInputToTarget: target];
    }
}

- (void) _stopUpdating
{
    if (inputTimer)
    {
        [inputTimer invalidate];
        [inputTimer release];
        inputTimer = nil;
    }
}

- (void) _startUpdatingTarget: (id <BXEmulatedJoystick>)target
{
    if (!inputTimer || [inputTimer userInfo] != target)
    {
        [self _stopUpdating];
        
        inputTimer = [NSTimer scheduledTimerWithTimeInterval: (1.0f / BXDefaultAdditiveAxisInputRate)
                                                      target: self
                                                    selector: @selector(_updateWithTimer:)
                                                    userInfo: target
                                                     repeats: YES];
        
        [inputTimer retain];
    }
}

- (void) processEvent: (BXHIDEvent *)event
			forTarget: (id <BXEmulatedJoystick>)target
{
	previousValue = [self _normalizedAxisValue: [event axisPosition]];
    
    //EXPLANATION: BXAxisToAxisAdditive gradually increments/decrements
    //its emulated axis when the input axis is outside its deadzone.
    //Because we may not receive ongoing input signals from the axis
    //(e.g. if it is being held at maximum), we use a timer to update
    //the emulated axis periodically with whatever the latest value
    //of the input axis is.
    
    //Once the input axis returns to center, we cancel the timer: this
    //leaves the emulated axis at whatever value it had reached.
    
    if (previousValue != 0.0f)  [self _startUpdatingTarget: target];
    else                        [self _stopUpdating];
}

- (void) dealloc
{
    [self _stopUpdating];
    
    [super dealloc];
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

- (id) initWithCoder: (NSCoder *)coder
{
    if ((self = [super initWithCoder: coder]))
    {
        [self setButton: [coder decodeIntegerForKey: @"button"]];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
    [super encodeWithCoder: coder];
    [coder encodeInteger: [self button] forKey: @"button"];
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
@synthesize pressedValue, releasedValue, axis;

+ (id) bindingWithAxis: (NSString *)axisName
{
    id binding = [self binding];
    [binding setAxis: axisName];
    return binding;
}

- (id) init
{
	if ((self = [super init]))
	{
		[self setPressedValue: BXDefaultButtonToAxisPressedValue];
		[self setReleasedValue: BXDefaultButtonToAxisReleasedValue];
	}
	return self;	
}

- (void) dealloc
{
    [self setAxis: nil], [axis release];
    [super dealloc];
}

- (id) initWithCoder: (NSCoder *)coder
{
    if ((self = [super initWithCoder: coder]))
    {
        [self setAxis: [coder decodeObjectForKey: @"axis"]];
        
        if ([coder containsValueForKey: @"pressed"])
            [self setPressedValue: [coder decodeFloatForKey: @"pressed"]];
        if ([coder containsValueForKey: @"released"])
            [self setReleasedValue: [coder decodeFloatForKey: @"released"]];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
    [super encodeWithCoder: coder];
    
    [coder encodeObject: [self axis] forKey: @"axis"];
    
    //Don’t persist defaults
    if ([self pressedValue] != BXDefaultButtonToAxisPressedValue)
        [coder encodeFloat: [self pressedValue] forKey: @"pressed"];
    
    if ([self releasedValue] != BXDefaultButtonToAxisReleasedValue) 
        [coder encodeFloat: [self releasedValue] forKey: @"released"];
}

- (void) processEvent: (BXHIDEvent *)event
			forTarget: (id <BXEmulatedJoystick>)target
{
	float axisValue;
	if ([event type] == BXHIDJoystickButtonDown)
		axisValue = [self pressedValue];
	else
		axisValue = [self releasedValue];
	
    [(id)target setValue: [NSNumber numberWithFloat: axisValue] forKey: [self axis]];
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
        [self setUnidirectional: NO];
		previousValue = NO;
	}
	return self;
}

- (id) initWithCoder: (NSCoder *)coder
{
    if ((self = [super initWithCoder: coder]))
    {
        [self setButton: [coder decodeIntegerForKey: @"button"]];
        
        if ([coder containsValueForKey: @"threshold"])
            [self setThreshold: [coder decodeFloatForKey: @"threshold"]];
        
        [self setUnidirectional: [coder decodeBoolForKey: @"trigger"]];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
    [super encodeWithCoder: coder];
    
    [coder encodeInteger: [self button] forKey: @"button"];
    
    //Don’t persist defaults
    if ([self threshold] != BXDefaultAxisToButtonThreshold) 
        [coder encodeFloat: [self threshold] forKey: @"threshold"];
    
    if ([self isUnidirectional] != NO)
        [coder encodeBool: [self isUnidirectional] forKey: @"trigger"];
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
@synthesize POVNumber;

- (id) init
{
	if ((self = [super init]))
	{
		[self setPOVNumber: 0];
	}
	return self;
}

- (id) initWithCoder: (NSCoder *)coder
{
    if ((self = [super initWithCoder: coder]))
    {
        [self setPOVNumber: [coder decodeIntegerForKey: @"pov"]];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
    [super encodeWithCoder: coder];
    [coder encodeInteger: [self POVNumber] forKey: @"pov"];
}

+ (BXEmulatedPOVDirection) emulatedDirectionForHIDDirection: (BXHIDPOVSwitchDirection)direction
{
    BXHIDPOVSwitchDirection normalizedDirection = [BXHIDEvent closest8WayDirectionForPOV: direction];
    switch (normalizedDirection)
    {
        case BXHIDPOVNorth:
            return BXEmulatedPOVNorth;
            break;
        case BXHIDPOVEast:
            return BXEmulatedPOVEast;
            break;
        case BXHIDPOVSouth:
            return BXEmulatedPOVSouth;
            break;
        case BXHIDPOVWest:
            return BXEmulatedPOVWest;
            break;
        
        case BXHIDPOVNorthWest:
            return BXEmulatedPOVNorthWest;
            break;
        case BXHIDPOVNorthEast:
            return BXEmulatedPOVNorthEast;
            break;
        case BXHIDPOVSouthEast:
            return BXEmulatedPOVSouthEast;
            break;
        case BXHIDPOVSouthWest:
            return BXEmulatedPOVSouthWest;
            break;
            
        default:
            return BXEmulatedPOVCentered;
    }
}

- (void) processEvent: (BXHIDEvent *)event
			forTarget: (id <BXEmulatedJoystick>)target
{
	BXEmulatedPOVDirection direction = [[self class] emulatedDirectionForHIDDirection: [event POVDirection]];
	
    [(id <BXEmulatedFlightstick>)target POV: [self POVNumber] changedTo: direction];
}

@end


@implementation BXButtonToPOV
@synthesize POVNumber, direction;

+ (id) bindingWithDirection: (BXEmulatedPOVDirection) direction
{
    id binding = [[self alloc] init];
    [binding setDirection: direction];
    return [binding autorelease];
}

- (id) init
{
	if ((self = [super init]))
	{
		[self setPOVNumber: 0];
	}
	return self;
}

- (id) initWithCoder: (NSCoder *)coder
{
    if ((self = [super initWithCoder: coder]))
    {
        [self setPOVNumber: [coder decodeIntegerForKey: @"pov"]];
        [self setDirection: [coder decodeIntegerForKey: @"direction"]];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
    [super encodeWithCoder: coder];
    [coder encodeInteger: [self POVNumber] forKey: @"pov"];
    [coder encodeInteger: [self direction] forKey: @"direction"];
}

- (void) processEvent: (BXHIDEvent *)event
			forTarget: (id <BXEmulatedJoystick>)target
{
	if ([event type] == BXHIDJoystickButtonDown)
        [(id <BXEmulatedFlightstick>)target POV: [self POVNumber] directionDown: [self direction]];
	else
        [(id <BXEmulatedFlightstick>)target POV: [self POVNumber] directionUp: [self direction]];
}

@end

@implementation BXPOVToAxes
@synthesize xAxis, yAxis;

+ (id) bindingWithXAxis: (NSString *)x
                  YAxis: (NSString *)y
{
    BXPOVToAxes *binding = [self binding];
    [binding setXAxis: x];
    [binding setYAxis: y];
    return binding;
}

- (void) dealloc
{
    [self setXAxis: nil], [xAxis release];
    [self setYAxis: nil], [yAxis release];
    [super dealloc];
}

- (id) initWithCoder: (NSCoder *)coder
{
    if ((self = [super initWithCoder: coder]))
    {
        [self setXAxis: [coder decodeObjectForKey: @"east-west"]];
        [self setYAxis: [coder decodeObjectForKey: @"north-south"]];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
    [super encodeWithCoder: coder];
    
    [coder encodeObject: [self xAxis] forKey: @"east-west"];
    [coder encodeObject: [self yAxis] forKey: @"north-south"];
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

    if ([self xAxis])
    {
        [(id)target setValue: [NSNumber numberWithFloat: x] forKey: [self xAxis]];
    }
    if ([self yAxis])
    {
        [(id)target setValue: [NSNumber numberWithFloat: y] forKey: [self yAxis]];
    }
}

@end

@implementation BXAxisToBindings
@synthesize positiveBinding, negativeBinding;

+ (id) bindingWithPositiveAxis: (NSString *)positive
                  negativeAxis: (NSString *)negative
{
    id binding = [self binding];
    [binding setPositiveBinding: [BXAxisToAxis bindingWithAxis: positive]];
    [binding setNegativeBinding: [BXAxisToAxis bindingWithAxis: negative]];
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

- (id) initWithCoder: (NSCoder *)coder
{
    if ((self = [super initWithCoder: coder]))
    {
        [self setPositiveBinding: [coder decodeObjectForKey: @"positive"]];
        [self setNegativeBinding: [coder decodeObjectForKey: @"negative"]];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
    [super encodeWithCoder: coder];
    
    [coder encodeObject: [self positiveBinding] forKey: @"positive"];
    [coder encodeObject: [self negativeBinding] forKey: @"negative"];
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

