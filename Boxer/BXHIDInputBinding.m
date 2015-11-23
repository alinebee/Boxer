/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXHIDInputBinding.h"
#import "ADBHIDEvent.h"
#import "BXEmulatedJoystick.h"
#import "DDHidUsage+ADBUsageExtensions.h"


#define BXDefaultAxisDeadzone 0.20f

@implementation BXHIDButtonBinding
@synthesize outputBinding = _outputBinding;

+ (id) binding
{
    return [[self alloc] init];
}

+ (id) bindingWithOutputBinding: (id <BXOutputBinding>)outputBinding
{
    BXHIDButtonBinding *binding = [self binding];
    binding.outputBinding = outputBinding;
    return binding;
}

- (void) processEvent: (ADBHIDEvent *)event
{
    if (event.type == ADBHIDJoystickButtonDown)
        [self.outputBinding applyInputValue: kBXOutputBindingMax];
    else
        [self.outputBinding applyInputValue: kBXOutputBindingMin];
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"%@ input binding to %@", self.class, self.outputBinding];
}

@end


@implementation BXHIDAxisBinding
@synthesize positiveBinding = _positiveBinding;
@synthesize negativeBinding = _negativeBinding;
@synthesize deadzone = _deadzone;
@synthesize inverted = _inverted;
@synthesize unidirectional = _unidirectional;

+ (id) binding
{
    return [[self alloc] init];
}

+ (id) bindingWithPositiveBinding: (id< BXOutputBinding>)positiveBinding
                  negativeBinding: (id <BXOutputBinding>)negativeBinding
{
    BXHIDAxisBinding *binding = [self binding];
    binding.positiveBinding = positiveBinding;
    binding.negativeBinding = negativeBinding;
    return binding;
}

- (id) init
{
    self = [super init];
    if (self)
    {
        self.deadzone = BXDefaultAxisDeadzone;
    }
    return self;
}

- (float) _normalizedAxisValue: (NSInteger)axisValue
{
	float normalizedValue = axisValue / (float)DDHID_JOYSTICK_VALUE_MAX;
	if (self.isUnidirectional)
	{
		normalizedValue = (normalizedValue + 1.0) * 0.5;
	}
	
	//Flip the axis if necessary
	if (self.isInverted)
        normalizedValue *= -1;
	
	//Clamp axis value to 0 if it is within the deadzone.
	if (ABS(normalizedValue) - self.deadzone < 0)
        normalizedValue = 0;
	
	return normalizedValue;
}

- (void) processEvent: (ADBHIDEvent *)event
{
    float normalizedValue = [self _normalizedAxisValue: event.axisPosition];
    
    //IMPLEMENTATION NOTE: because it's likely that the positive and negative
    //bindings will both affect the same emulated axis, we clear the 'released'
    //binding before triggering the 'activated' binding, so that the released
    //binding hopefully won't undo our hard work.
    if (normalizedValue > 0)
    {
        [self.negativeBinding applyInputValue: 0];
        [self.positiveBinding applyInputValue: normalizedValue];
    }
    else if (normalizedValue < 0)
    {
        [self.positiveBinding applyInputValue: 0];
        [self.negativeBinding applyInputValue: ABS(normalizedValue)];
    }
    else
    {
        [self.positiveBinding applyInputValue: 0];
        [self.negativeBinding applyInputValue: 0];
    }
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"%@ input binding to positive %@, negative %@", self.class, self.positiveBinding, self.negativeBinding];
}

@end



@interface BXHIDPOVSwitchBinding ()
@property (retain, nonatomic) NSMutableDictionary *outputBindings;
@end

@implementation BXHIDPOVSwitchBinding
@synthesize outputBindings = _outputBindings;

+ (id) binding
{
    return [[self alloc] init];
}

+ (id) bindingWithOutputBindingsAndDirections: (id <BXOutputBinding>)subBinding, ... NS_REQUIRES_NIL_TERMINATION
{
    BXHIDPOVSwitchBinding *binding = [self binding];
    
    if (subBinding != nil)
    {
        va_list args;
        va_start(args, subBinding);
        
        BOOL nextIsDirection = YES;
        while (subBinding != nil)
        {
            if (nextIsDirection)
            {
                ADBHIDPOVSwitchDirection direction = va_arg(args, ADBHIDPOVSwitchDirection);
                [binding setBinding: subBinding forDirection: direction];
            }
            else
            {
                subBinding = va_arg(args, id);
            }
        }
        
        va_end(args);
    }
    return binding;
}

- (id) init
{
    self = [super init];
    if (self)
    {
        self.outputBindings = [NSMutableDictionary dictionaryWithCapacity: 8];
		_previousDirection = ADBHIDPOVCentered;
    }
    return self;
}

- (id <BXHIDInputBinding>) bindingForDirection: (ADBHIDPOVSwitchDirection)direction
{
    return [self.outputBindings objectForKey: @(direction)];
}

- (void) setBinding: (id<BXHIDInputBinding>)binding forDirection: (ADBHIDPOVSwitchDirection)direction
{
    [self.outputBindings setObject: binding forKey: @(direction)];
}

- (NSSet *) closestBindingsForDirection: (ADBHIDPOVSwitchDirection)direction
{
    direction = [ADBHIDEvent closest8WayDirectionForPOV: direction];
    
    id <BXOutputBinding> matchingBinding = [self bindingForDirection: direction];
    if (matchingBinding)
    {
        return [NSSet setWithObject: matchingBinding];
    }
    else if (direction != ADBHIDPOVCentered)
    {
        NSMutableSet *bindings = [NSMutableSet setWithCapacity: 2];
        //Try with directions either side of the binding.
        ADBHIDPOVSwitchDirection cw  = (direction + 4500) % 36000;
        ADBHIDPOVSwitchDirection ccw = (direction - 4500) % 36000;
        
        id <BXOutputBinding> cwBinding = [self bindingForDirection: cw];
        id <BXOutputBinding> ccwBinding = [self bindingForDirection: ccw];
        if (cwBinding) [bindings addObject: cwBinding];
        if (ccwBinding) [bindings addObject: ccwBinding];
        
        return bindings;
    }
    else
    {
        return nil;
    }
}

- (void) processEvent: (ADBHIDEvent *)event
{
    ADBHIDPOVSwitchDirection direction = [ADBHIDEvent closest8WayDirectionForPOV: event.POVDirection];
    
    if (direction != _previousDirection)
    {
        NSSet *inactiveBindings = [self closestBindingsForDirection: _previousDirection];
        NSSet *activeBindings = [self closestBindingsForDirection: direction];
        
        for (id <BXOutputBinding> binding in inactiveBindings)
        {
            if (![activeBindings containsObject: binding])
                [binding applyInputValue: kBXOutputBindingMin];
        }
        
        for (id <BXOutputBinding> binding in activeBindings)
        {
            if (![inactiveBindings containsObject: binding])
                [binding applyInputValue: kBXOutputBindingMax];
        }
        
        _previousDirection = direction;
    }
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"%@ binding with output bindings: %@", self.class, self.outputBindings];
}

@end
