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


#define BXDefaultAxisDeadzone 0.25f
#define BXDefaultAxisToButtonThreshold 0.25f
#define BXDefaultButtonToAxisPressedValue 1.0f
#define BXDefaultButtonToAxisReleasedValue 0.0f
#define BXDefaultAdditiveAxisRate 1.0f
#define BXDefaultAdditiveAxisInputRate 30.0 //30 frames per second


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
@synthesize delegate;

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

- (void) _performSelector: (SEL)selector
				 onTarget: (id <BXEmulatedJoystick>)target
				withValue: (void *)value
{
	NSMethodSignature *signature = [(id)target methodSignatureForSelector: selector];
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
        [self setUnidirectional: NO];
        [self setInverted: NO];
        
		previousValue = 0.0f;
	}
	return self;
}

- (id) initWithCoder: (NSCoder *)coder
{
    if ((self = [super initWithCoder: coder]))
    {
        SEL axis = NSSelectorFromString([coder decodeObjectForKey: @"axis"]);
        [self setAxisSelector: axis];
         
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
    
    NSString *axis = NSStringFromSelector([self axisSelector]);
    [coder encodeObject: axis forKey: @"axis"];
    
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
		[self _performSelector: [self axisSelector] onTarget: target withValue: &axisValue];
        [[self delegate] binding: self
                 didUpdateTarget: target
                   usingSelector: [self axisSelector]
                          object: [NSNumber numberWithFloat: axisValue]];
		previousValue = axisValue;
	}
}

@end


@implementation BXAxisToAxisAdditive
@synthesize ratePerSecond;

- (id) init
{
	if ((self = [super init]))
	{
		[self setRatePerSecond: BXDefaultAdditiveAxisRate];
	}
	return self;
}

- (id) initWithCoder: (NSCoder *)coder
{
    if ((self = [super initWithCoder: coder]))
    {
        if ([coder containsValueForKey: @"strength"])
            [self setRatePerSecond: [coder decodeFloatForKey: @"strength"]];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
    [super encodeWithCoder: coder];
    
    //Don’t persist defaults
    if ([self ratePerSecond] != BXDefaultAdditiveAxisRate)
        [coder encodeFloat: [self ratePerSecond] forKey: @"strength"];
}

#pragma mark -
#pragma mark Timed updates

- (void) _updateWithTimer: (NSTimer *)timer
{
    if (previousValue != 0.0f)
    {
        id <BXEmulatedJoystick> target = [timer userInfo];
 
        float impulseValue = ([self ratePerSecond] * previousValue) / (float)BXDefaultAdditiveAxisInputRate;
    
        [self _performSelector: [self axisSelector] onTarget: target withValue: &impulseValue];
        
        [[self delegate] binding: self
                 didUpdateTarget: target
                   usingSelector: [self axisSelector]
                          object: [NSNumber numberWithFloat: impulseValue]];
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
        
        inputTimer = [NSTimer scheduledTimerWithTimeInterval: (1000 / BXDefaultAdditiveAxisInputRate)
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
		[self setPressedValue: BXDefaultButtonToAxisPressedValue];
		[self setReleasedValue: BXDefaultButtonToAxisReleasedValue];
	}
	return self;	
}


- (id) initWithCoder: (NSCoder *)coder
{
    if ((self = [super initWithCoder: coder]))
    {
        SEL axis = NSSelectorFromString([coder decodeObjectForKey: @"axis"]);
        [self setAxisSelector: axis];
        
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
    
    NSString *axis = NSStringFromSelector([self axisSelector]);
    [coder encodeObject: axis forKey: @"axis"];
    
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
	
	[self _performSelector: [self axisSelector] onTarget: target withValue: &axisValue];
    
    [[self delegate] binding: self
             didUpdateTarget: target
               usingSelector: [self axisSelector]
                      object: [NSNumber numberWithFloat: axisValue]];
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
@synthesize POVSelector;

- (id) init
{
	if ((self = [super init]))
	{
		[self setPOVSelector: @selector(POVChangedTo:)];
	}
	return self;
}

- (id) initWithCoder: (NSCoder *)coder
{
    if ((self = [super initWithCoder: coder]))
    {
        SEL povSelector = NSSelectorFromString([coder decodeObjectForKey: @"pov"]);
        [self setPOVSelector: povSelector];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
    [super encodeWithCoder: coder];
    
    NSString *povSelector = NSStringFromSelector([self POVSelector]);
    [coder encodeObject: povSelector forKey: @"povSelector"];
}

- (void) processEvent: (BXHIDEvent *)event
			forTarget: (id <BXEmulatedJoystick>)target
{
	BXEmulatedPOVDirection direction = [event POVDirection];
	
	[self _performSelector: [self POVSelector] onTarget: target withValue: &direction];
    
    [[self delegate] binding: self
             didUpdateTarget: target
               usingSelector: [self POVSelector]
                      object: [NSNumber numberWithInteger: direction]];
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
@synthesize POVSelector, northButtonUsage, southButtonUsage, eastButtonUsage, westButtonUsage;

- (id) init
{
	if ((self = [super init]))
	{
		[self setPOVSelector: @selector(POVChangedTo:)];
	}
	return self;
}

- (void) dealloc
{
    [[self northButtonUsage] release], [self setNorthButtonUsage: nil];
    [[self southButtonUsage] release], [self setSouthButtonUsage: nil];
    [[self eastButtonUsage] release], [self setEastButtonUsage: nil];
    [[self westButtonUsage] release], [self setWestButtonUsage: nil];
    [super dealloc];
}

- (id) initWithCoder: (NSCoder *)coder
{
    if ((self = [super initWithCoder: coder]))
    {
        SEL povSelector = NSSelectorFromString([coder decodeObjectForKey: @"pov"]);
        [self setPOVSelector: povSelector];
        
        [self setNorthButtonUsage: BXUsageFromName([coder decodeObjectForKey: @"north"])];
        [self setSouthButtonUsage: BXUsageFromName([coder decodeObjectForKey: @"south"])];
        [self setEastButtonUsage: BXUsageFromName([coder decodeObjectForKey: @"east"])];
        [self setWestButtonUsage: BXUsageFromName([coder decodeObjectForKey: @"west"])];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
    [super encodeWithCoder: coder];
    
    NSString *povSelector = NSStringFromSelector([self POVSelector]);
    [coder encodeObject: povSelector forKey: @"povSelector"];
    
    [coder encodeObject: [[self northButtonUsage] usageName] forKey: @"north"];
    [coder encodeObject: [[self southButtonUsage] usageName] forKey: @"south"];
    [coder encodeObject: [[self eastButtonUsage] usageName] forKey: @"east"];
    [coder encodeObject: [[self westButtonUsage] usageName] forKey: @"west"];
}

- (void) _syncButtonState: (DDHidUsage *)buttonUsage isDown: (BOOL)down
{
	NSUInteger mask = BXButtonsToPOVNoButtons;
	if		([buttonUsage isEqualToUsage: [self northButtonUsage]])	mask = BXButtonsToPOVNorthMask;
	else if	([buttonUsage isEqualToUsage: [self southButtonUsage]])	mask = BXButtonsToPOVSouthMask;
	else if	([buttonUsage isEqualToUsage: [self eastButtonUsage]])  mask = BXButtonsToPOVEastMask;
	else if	([buttonUsage isEqualToUsage: [self westButtonUsage]])  mask = BXButtonsToPOVWestMask;
	
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
	[self _syncButtonState: [button usage] isDown: down];
	
	BXEmulatedPOVDirection direction = [self _POVDirection];
	
	[self _performSelector: [self POVSelector] onTarget: target withValue: &direction];
    
    [[self delegate] binding: self
             didUpdateTarget: target
               usingSelector: [self POVSelector]
                      object: [NSNumber numberWithInteger: direction]];
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

- (id) initWithCoder: (NSCoder *)coder
{
    if ((self = [super initWithCoder: coder]))
    {
        SEL xAxis = NSSelectorFromString([coder decodeObjectForKey: @"east-west"]);
        [self setXAxisSelector: xAxis];
        
        SEL yAxis = NSSelectorFromString([coder decodeObjectForKey: @"north-south"]);
        [self setYAxisSelector: yAxis];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
    [super encodeWithCoder: coder];
    
    NSString    *xAxis = NSStringFromSelector([self xAxisSelector]),
                *yAxis = NSStringFromSelector([self yAxisSelector]);
    
    [coder encodeObject: xAxis forKey: @"east-west"];
    [coder encodeObject: yAxis forKey: @"north-south"];
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
    {
        [self _performSelector: [self xAxisSelector] onTarget: target withValue: &x];
        [[self delegate] binding: self
                 didUpdateTarget: target
                   usingSelector: [self xAxisSelector]
                          object: [NSNumber numberWithFloat: x]];
    }
    if ([self yAxisSelector])
    {
        [self _performSelector: [self yAxisSelector] onTarget: target withValue: &y];
        [[self delegate] binding: self
                 didUpdateTarget: target
                   usingSelector: [self yAxisSelector]
                          object: [NSNumber numberWithFloat: y]];
    }
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

