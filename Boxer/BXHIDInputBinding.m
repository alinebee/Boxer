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


#define BXDefaultAxisDeadzone 0.20f
#define BXDefaultAxisToButtonThreshold 0.25f
#define BXDefaultButtonToAxisPressedValue 1.0f
#define BXDefaultButtonToAxisReleasedValue 0.0f

#define BXDefaultAdditiveAxisEmulatedDeadzone 0.05f
#define BXDefaultAdditiveAxisRate 2.0f //Go from 0 to max in half a second
#define BXDefaultAdditiveAxisInputRate 30.0 //30 frames per second


@interface BXBaseEmulatedJoystickInputBinding ()

//Convert DDHidElement integer axis value into a floating-point range from -1.0 to 1.0.
+ (float) _normalizedAxisValue: (NSInteger)axisValue;

//Convert DDHidElement integer axis value into a floating-point range from 0.0 to 1.0.
+ (float) _normalizedUnidirectionalAxisValue: (NSInteger)axisValue;

@end


@implementation BXBaseEmulatedJoystickInputBinding
@synthesize target = _target;

+ (BOOL) supportsTarget: (id)target
{
    return [target conformsToProtocol: @protocol(BXEmulatedJoystick)];
}

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
@synthesize deadzone = _deadzone;
@synthesize unidirectional = _unidirectional;
@synthesize inverted = _inverted;
@synthesize axis = _axis;

+ (id) bindingWithAxis: (NSString *)axisName
{
    BXAxisToAxis *binding = [self binding];
    binding.axis = axisName;
    return binding;
}

- (id) init
{
    self = [super init];
	if (self)
	{
        self.deadzone = BXDefaultAxisDeadzone;
        self.unidirectional = NO;
        self.inverted = NO;
        
		_previousValue = 0.0f;
	}
	return self;
}

- (void) dealloc
{
    self.axis = nil;
    [super dealloc];
}

- (id) initWithCoder: (NSCoder *)coder
{
    self = [super initWithCoder: coder];
    if (self)
    {
        self.axis = [coder decodeObjectForKey: @"axis"];
         
        if ([coder containsValueForKey: @"deadzone"])
            self.deadzone = [coder decodeFloatForKey: @"deadzone"];
        
        self.inverted = [coder decodeBoolForKey: @"inverted"];
        self.unidirectional = [coder decodeBoolForKey: @"trigger"];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
    [super encodeWithCoder: coder];
    
    [coder encodeObject: self.axis forKey: @"axis"];
    
    //Don’t persist defaults
    if (self.deadzone != BXDefaultAxisDeadzone)
        [coder encodeFloat: self.deadzone forKey: @"deadzone"];
    
    if (self.isInverted != NO)
        [coder encodeBool: self.isInverted forKey: @"inverted"];
    
    if (self.isUnidirectional != NO)
        [coder encodeBool: self.isUnidirectional forKey: @"trigger"];
}

- (float) _normalizedAxisValue: (NSInteger)axisValue
{	
	float fPosition;
	if (self.isUnidirectional)
	{
		fPosition = [self.class _normalizedUnidirectionalAxisValue: axisValue];
	}
	else
	{
		fPosition = [self.class _normalizedAxisValue: axisValue];
	}
	
	//Flip the axis if necessary
	if (self.isInverted)
        fPosition *= -1;
	
	//Clamp axis value to 0 if it is within the deadzone.
	if (ABS(fPosition) - self.deadzone < 0)
        fPosition = 0;
	
	return fPosition;
}

- (void) processEvent: (BXHIDEvent *)event
{
	float axisValue = [self _normalizedAxisValue: event.axisPosition];
	if (axisValue != _previousValue)
	{
        [(id)self.target setValue: @(axisValue) forKey: self.axis];
		_previousValue = axisValue;
	}
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"%@ binding to emulated axis: %@ unidirectional: %@", self.class, self.axis, self.isUnidirectional ? @"YES" : @"NO"];
}
@end


@interface BXAxisToAxisAdditive ()

@property (retain, nonatomic) NSTimer *inputTimer;

@end

@implementation BXAxisToAxisAdditive
@synthesize ratePerSecond = _ratePerSecond;
@synthesize delegate = _delegate;
@synthesize emulatedDeadzone = _emulatedDeadzone;
@synthesize inputTimer = _inputTimer;

- (id) init
{
    self = [super init];
	if (self)
	{
        self.ratePerSecond = BXDefaultAdditiveAxisRate;
        self.emulatedDeadzone = BXDefaultAdditiveAxisEmulatedDeadzone;
	}
	return self;
}

- (id) initWithCoder: (NSCoder *)coder
{
    self = [super initWithCoder: coder];
    if (self)
    {
        if ([coder containsValueForKey: @"strength"])
            self.ratePerSecond = [coder decodeFloatForKey: @"strength"];
        
        if ([coder containsValueForKey: @"emulated deadzone"])
            self.emulatedDeadzone = [coder decodeFloatForKey: @"emulated deadzone"];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
    [super encodeWithCoder: coder];
    
    //Don’t persist defaults
    if (self.ratePerSecond != BXDefaultAdditiveAxisRate)
        [coder encodeFloat: self.ratePerSecond forKey: @"strength"];
    
    if (self.emulatedDeadzone != BXDefaultAdditiveAxisEmulatedDeadzone)
        [coder encodeFloat: self.emulatedDeadzone forKey: @"emulated deadzone"];
        
}

- (void) dealloc
{
    [self _stopUpdating];
    [super dealloc];
}

#pragma mark -
#pragma mark Timed updates

- (void) _updateWithTimer: (NSTimer *)timer
{
    if (_previousValue != 0.0f)
    {
        //Work out how much to increment the axis value by for the current timestep.
        float increment = (self.ratePerSecond * _previousValue) / (float)BXDefaultAdditiveAxisInputRate;
    
        float currentValue = [[(id)self.target valueForKey: self.axis] floatValue];
        float newValue = currentValue + increment;
        
        //Apply a deadzone to the incremented value to snap very low values to 0.
        //This makes it easier to center the input.
        if ((ABS(newValue) - self.emulatedDeadzone) < 0) newValue = 0;
        
        [(id)self.target setValue: @(newValue) forKey: self.axis];
        
        //Let the delegate know that we updated the binding's value outside of the event stream.
        [self.delegate binding: self didSendInputToTarget: self.target];
    }
}

- (void) _startUpdating
{
    if (!self.inputTimer)
    {
        self.inputTimer = [NSTimer scheduledTimerWithTimeInterval: (1.0f / BXDefaultAdditiveAxisInputRate)
                                                           target: self
                                                         selector: @selector(_updateWithTimer:)
                                                         userInfo: nil
                                                          repeats: YES];
    }
}

- (void) _stopUpdating
{
    [self.inputTimer invalidate];
    self.inputTimer = nil;
}

- (void) processEvent: (BXHIDEvent *)event
{
	_previousValue = [self _normalizedAxisValue: event.axisPosition];
    
    //EXPLANATION: BXAxisToAxisAdditive gradually increments/decrements
    //its emulated axis when the input axis is outside its deadzone.
    //Because we may not receive ongoing input signals from the axis
    //(e.g. if it is being held at maximum), we use a timer to update
    //the emulated axis periodically with whatever the latest value
    //of the input axis is.
    
    //Once the input axis returns to center, we cancel the timer: this
    //leaves the emulated axis at whatever value it had reached.
    
    if (_previousValue != 0.0f)
        [self _startUpdating];
    else
        [self _stopUpdating];
}

@end


@implementation BXButtonToButton
@synthesize button = _button;

+ (id) bindingWithButton: (NSUInteger)button
{
    BXButtonToButton *binding = [self binding];
    binding.button = button;
    return binding;
}

- (id) initWithCoder: (NSCoder *)coder
{
    self = [super initWithCoder: coder];
    if (self)
    {
        self.button = [coder decodeIntegerForKey: @"button"];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
    [super encodeWithCoder: coder];
    [coder encodeInteger: self.button forKey: @"button"];
}

- (void) processEvent: (BXHIDEvent *)event
{
	BOOL buttonDown = (event.type == BXHIDJoystickButtonDown);
	if (buttonDown)
		[self.target buttonDown: self.button];
	else
		[self.target buttonUp: self.button];
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"%@ binding to emulated button: %lu", self.class, (unsigned long)self.button];
}
@end


@implementation BXButtonToAxis
@synthesize pressedValue = _pressedValue;
@synthesize releasedValue = _releasedValue;
@synthesize axis = _axis;

+ (id) bindingWithAxis: (NSString *)axisName
{
    BXButtonToAxis *binding = [self binding];
    binding.axis = axisName;
    return binding;
}

- (id) init
{
    self = [super init];
	if (self)
	{
        self.pressedValue = BXDefaultButtonToAxisPressedValue;
        self.releasedValue = BXDefaultButtonToAxisReleasedValue;
	}
	return self;	
}

- (void) dealloc
{
    self.axis = nil;
    [super dealloc];
}

- (id) initWithCoder: (NSCoder *)coder
{
    self = [super initWithCoder: coder];
    if (self)
    {
        self.axis = [coder decodeObjectForKey: @"axis"];
        
        if ([coder containsValueForKey: @"pressed"])
            self.pressedValue = [coder decodeFloatForKey: @"pressed"];
        
        if ([coder containsValueForKey: @"released"])
            self.releasedValue = [coder decodeFloatForKey: @"released"];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
    [super encodeWithCoder: coder];
    
    [coder encodeObject: self.axis forKey: @"axis"];
    
    //Don’t persist defaults
    if (self.pressedValue != BXDefaultButtonToAxisPressedValue)
        [coder encodeFloat: self.pressedValue forKey: @"pressed"];
    
    if (self.releasedValue != BXDefaultButtonToAxisReleasedValue)
        [coder encodeFloat: self.releasedValue forKey: @"released"];
}

- (void) processEvent: (BXHIDEvent *)event
{
	float axisValue;
	if (event.type == BXHIDJoystickButtonDown)
		axisValue = self.pressedValue;
	else
		axisValue = self.releasedValue;
	
    [(id)self.target setValue: @(axisValue) forKey: self.axis];
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"%@ binding to emulated axis: %@ value when pressed: %02f when released: %02f", self.class, self.axis, self.pressedValue, self.releasedValue];
}
@end



@implementation BXAxisToButton
@synthesize threshold = _threshold;
@synthesize unidirectional = _unidirectional;
@synthesize button = _button;

+ (id) bindingWithButton: (NSUInteger)button
{
    BXAxisToButton *binding = [self binding];
    binding.button = button;
    return binding;
}

- (id) init
{
    self = [super init];
	if (self)
	{
		self.threshold = BXDefaultAxisToButtonThreshold;
        self.unidirectional = NO;
    	_previousValue = NO;
	}
	return self;
}

- (id) initWithCoder: (NSCoder *)coder
{
    self = [super initWithCoder: coder];
    if (self)
    {
        self.button = [coder decodeIntegerForKey: @"button"];
        
        if ([coder containsValueForKey: @"threshold"])
            self.threshold = [coder decodeFloatForKey: @"threshold"];
        
        self.unidirectional = [coder decodeBoolForKey: @"trigger"];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
    [super encodeWithCoder: coder];
    
    [coder encodeInteger: self.button forKey: @"button"];
    
    //Don’t persist defaults
    if (self.threshold != BXDefaultAxisToButtonThreshold)
        [coder encodeFloat: self.threshold forKey: @"threshold"];
    
    if (self.isUnidirectional != NO)
        [coder encodeBool: self.isUnidirectional forKey: @"trigger"];
}

- (BOOL) _buttonDown: (NSInteger)axisPosition
{
	float fPosition;
	if (self.isUnidirectional)
	{
		fPosition = [self.class _normalizedUnidirectionalAxisValue: axisPosition];
	}
	else
	{
		fPosition = [self.class _normalizedAxisValue: axisPosition];
	}

	//Ignore polarity when checking whether the axis is over the threshold:
	//This makes both directions on a bidirectional axis act the same.
	if (ABS(fPosition) > self.threshold)
        return YES;
    else
        return NO;
}

- (void) processEvent: (BXHIDEvent *)event
{
	BOOL buttonDown = [self _buttonDown: event.axisPosition];
	
	if (buttonDown != _previousValue)
	{
		if (buttonDown)
			[self.target buttonDown: self.button];
		else
			[self.target buttonUp: self.button];
		
		_previousValue = buttonDown;
	}
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"%@ binding to emulated button: %lu threshold: %02f", self.class, (unsigned long)self.button, self.threshold];
}
@end


@implementation BXPOVToPOV
@synthesize POVNumber = _POVNumber;

+ (BOOL) supportsTarget: (id)target
{
    return [target conformsToProtocol: @protocol(BXEmulatedFlightstick)];
}

- (id) init
{
    self = [super init];
	if (self)
	{
        self.POVNumber = 0;
	}
	return self;
}

- (id) initWithCoder: (NSCoder *)coder
{
    self = [super initWithCoder: coder];
    if (self)
    {
        self.POVNumber = [coder decodeIntegerForKey: @"pov"];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
    [super encodeWithCoder: coder];
    [coder encodeInteger: self.POVNumber forKey: @"pov"];
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
{
	BXEmulatedPOVDirection direction = [self.class emulatedDirectionForHIDDirection: event.POVDirection];
	
    [(id <BXEmulatedFlightstick>)self.target POV: self.POVNumber changedTo: direction];
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"%@ binding to emulated POV number: %lu", self.class, (unsigned long)self.POVNumber];
}
@end


@implementation BXButtonToPOV
@synthesize POVNumber = _POVNumber;
@synthesize direction = _direction;

+ (BOOL) supportsTarget: (id)target
{
    return [target conformsToProtocol: @protocol(BXEmulatedFlightstick)];
}

+ (id) bindingWithDirection: (BXEmulatedPOVDirection) direction
{
    BXButtonToPOV *binding = [self binding];
    binding.direction = direction;
    return binding;
}

- (id) init
{
    self = [super init];
	if (self)
	{
        self.POVNumber = 0;
	}
	return self;
}

- (id) initWithCoder: (NSCoder *)coder
{
    self = [super initWithCoder: coder];
    if (self)
    {
        self.POVNumber = [coder decodeIntegerForKey: @"pov"];
        self.direction = [coder decodeIntegerForKey: @"direction"];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
    [super encodeWithCoder: coder];
    [coder encodeInteger: self.POVNumber forKey: @"pov"];
    [coder encodeInteger: self.direction forKey: @"direction"];
}

- (void) processEvent: (BXHIDEvent *)event
{
	if (event.type == BXHIDJoystickButtonDown)
        [(id <BXEmulatedFlightstick>)self.target POV: self.POVNumber directionDown: self.direction];
	else
        [(id <BXEmulatedFlightstick>)self.target POV: self.POVNumber directionUp: self.direction];
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"%@ binding for direction: %li on emulated POV number: %lu", self.class, (long)self.direction, (unsigned long)self.POVNumber];
}
@end

@implementation BXPOVToAxes
@synthesize xAxis = _xAxis;
@synthesize yAxis = _yAxis;

+ (id) bindingWithXAxis: (NSString *)x
                  YAxis: (NSString *)y
{
    BXPOVToAxes *binding = [self binding];
    binding.xAxis = x;
    binding.yAxis = y;
    return binding;
}

- (void) dealloc
{
    self.xAxis = nil;
    self.yAxis = nil;
    [super dealloc];
}

- (id) initWithCoder: (NSCoder *)coder
{
    self = [super initWithCoder: coder];
    if (self)
    {
        self.xAxis = [coder decodeObjectForKey: @"east-west"];
        self.yAxis = [coder decodeObjectForKey: @"north-south"];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
    [super encodeWithCoder: coder];
    
    [coder encodeObject: self.xAxis forKey: @"east-west"];
    [coder encodeObject: self.yAxis forKey: @"north-south"];
}

- (void) processEvent: (BXHIDEvent *)event
{
	BXHIDPOVSwitchDirection direction = event.POVDirection;
	
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

    if (self.xAxis)
    {
        [(id)self.target setValue: @(x) forKey: self.xAxis];
    }
    if (self.yAxis)
    {
        [(id)self.target setValue: @(y) forKey: self.yAxis];
    }
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"%@ binding to emulated left-right axis: %@ up-down axis: %@", self.class, self.xAxis, self.yAxis];
}

@end

@implementation BXAxisToBindings
@synthesize positiveBinding = _positiveBinding;
@synthesize negativeBinding = _negativeBinding;
@synthesize deadzone = _deadzone;

+ (id) bindingWithPositiveAxis: (NSString *)positive
                  negativeAxis: (NSString *)negative
{
    BXAxisToBindings *binding = [self binding];
    binding.positiveBinding = [BXAxisToAxis bindingWithAxis: positive];
    binding.negativeBinding = [BXAxisToAxis bindingWithAxis: negative];
    return binding;
}

+ (id) bindingWithPositiveButton: (NSUInteger)positive
                  negativeButton: (NSUInteger)negative
{
    BXAxisToBindings *binding = [self binding];
    binding.positiveBinding = [BXAxisToButton bindingWithButton: positive];
    binding.negativeBinding = [BXAxisToButton bindingWithButton: negative];
    return binding;
}                          
                                 
- (id) init
{
    self = [super init];
    if (self)
    {
		_previousValue = 0.0f;
        self.deadzone = BXDefaultAxisDeadzone;
    }
    return self;
}

- (void) dealloc
{
    self.positiveBinding = nil;
    self.negativeBinding = nil;
    
    [super dealloc];
}

- (id) initWithCoder: (NSCoder *)coder
{
    self = [super initWithCoder: coder];
    if (self)
    {
        self.positiveBinding = [coder decodeObjectForKey: @"positive"];
        self.negativeBinding = [coder decodeObjectForKey: @"negative"];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
    [super encodeWithCoder: coder];
    
    [coder encodeObject: self.positiveBinding forKey: @"positive"];
    [coder encodeObject: self.negativeBinding forKey: @"negative"];
}

- (void) processEvent: (BXHIDEvent *)event
{
    NSInteger rawValue = event.axisPosition;
	NSInteger positiveValue = (rawValue > self.deadzone) ? rawValue : 0;
	NSInteger negativeValue = (rawValue < -self.deadzone) ? rawValue : 0;

    //Fake the event's axis value before feeding it to our positive
    //and negative bindings.
    //TODO: copy the event instead.
    event.axisPosition = positiveValue;
    [self.positiveBinding processEvent: event];
    
    event.axisPosition = negativeValue;
    [self.negativeBinding processEvent: event];
    
    event.axisPosition = rawValue;
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"%@ binding with positive binding: [%@] negative binding: [%@]", self.class, self.positiveBinding, self.negativeBinding];
}
@end

