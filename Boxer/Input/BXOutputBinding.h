//
//  BXEmulatedOutputBinding.h
//  Boxer
//
//  Created by Alun Bestor on 09/02/2013.
//  Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BXEmulatedJoystick.h"
#import "BXEmulatedKeyboard.h"

//BXOutputBindings take a scalar input value from 0.0 to 1.0 and trigger a signal on an emulated input device:
//e.g. an emulated joystick or keyboard.


#pragma mark - Constants

typedef enum {
    kBXAxisNegative = -1,
    kBXAxisPositive = 1,
} BXAxisPolarity;


//The minimum and maximum acceptable input values.
#define kBXOutputBindingMin 0.0
#define kBXOutputBindingMax 1.0


@protocol BXEmulatedJoystick;
@class BXEmulatedKeyboard;


#pragma mark - Protocols

@protocol BXOutputBinding <NSObject>

//Returns an autoreleased instance of the class.
+ (id) binding;

//Receives a raw input value.
- (void) applyInputValue: (float)value;

@end


//A base class to provide standard functionality to all output bindings. Should not be used directly.
@interface BXBaseOutputBinding : NSObject <BXOutputBinding>
{
    float _previousValue;
    float _previousNormalizedValue;
    float _threshold;
    BOOL _inverted;
}

//Input values below this amount will be rounded to 0. This is useful as a deadzone.
@property (assign, nonatomic) float threshold;

//Whether the input values will be flipped.
@property (assign, nonatomic) BOOL inverted;

//The last raw value that was provided to this binding.
@property (readonly, nonatomic) float latestValue;

//The last normalized value that was processed by this binding.
@property (readonly, nonatomic) float latestNormalizedValue;

//The current scalar value of the property to which this binding is attached.
//Returns 0 by default; should be overridden by subclasses.
@property (readonly, nonatomic) float effectiveValue;

//Receives a raw input value. The base implementation normalizes it with normalizedValue:,
//and then calls applyNormalizedInputValue: with the result if it differs from the previous
//normalized value. This also updates previousValue: and previousNormalizedValue: to match.
- (void) applyInputValue: (float)value;

//Called by applyInputValue: with an already-normalized value. Must be implemented by subclasses.
- (void) applyNormalizedInputValue: (float)value;

//Returns a normalized version of the specified input value, normalized according to our threshold and inverted flag.
//May be overridden by subclasses to do additional normalizing.
- (float) normalizedValue: (float)value;

@end


#pragma mark - Joystick bindings

//The base class for all joystick output bindings. Should not be used directly.
@interface BXBaseEmulatedJoystickBinding : BXBaseOutputBinding
{
    id <BXEmulatedJoystick> _joystick;
}
//The joystick to which we send input signals.
@property (retain, nonatomic) id <BXEmulatedJoystick> joystick;

@end


//Presses a joystick button when input > 0, releases it when input = 0.
@interface BXEmulatedJoystickButtonBinding : BXBaseEmulatedJoystickBinding
{
    BXEmulatedJoystickButton _button;
}
@property (assign, nonatomic) BXEmulatedJoystickButton button;

+ (id) bindingWithJoystick: (id <BXEmulatedJoystick>)joystick button: (BXEmulatedJoystickButton)button;

@end


//Maps the input value as input on a particular joystick axis and polarity.
@interface BXEmulatedJoystickAxisBinding : BXBaseEmulatedJoystickBinding
{
    NSString *_axisName;
    BXAxisPolarity _polarity;
}
@property (copy, nonatomic) NSString *axisName;
@property (assign, nonatomic) BXAxisPolarity polarity;

+ (id) bindingWithJoystick: (id <BXEmulatedJoystick>)joystick
                      axis: (NSString *)axisName
                  polarity: (BXAxisPolarity)polarity;

@end


//Presses a particular hat-switch direction when input > 0, releases it when input = 0.
@interface BXEmulatedJoystickPOVDirectionBinding : BXBaseEmulatedJoystickBinding
{
    NSUInteger _POVNumber;
    BXEmulatedPOVDirection _POVDirection;
}
@property (assign, nonatomic) NSUInteger POVNumber;
@property (assign, nonatomic) BXEmulatedPOVDirection POVDirection;

+ (id) bindingWithJoystick: (id <BXEmulatedJoystick>)joystick
                       POV: (NSUInteger)POVNumber
                 direction: (BXEmulatedPOVDirection)direction;

@end


#pragma mark - Keyboard bindings

//Presses a particular keyboard key when input > 0, releases it when input = 0.
@interface BXEmulatedKeyboardKeyBinding : BXBaseOutputBinding
{
    BXEmulatedKeyboard *_keyboard;
    BXDOSKeyCode _keyCode;
}

//The keyboard to which we send key signals.
@property (retain, nonatomic) BXEmulatedKeyboard *keyboard;

//The key code to press/release when this binding is activated.
@property (assign, nonatomic) BXDOSKeyCode keyCode;

+ (id) bindingWithKeyboard: (BXEmulatedKeyboard *)keyboard keyCode: (BXDOSKeyCode)keyCode;

@end


#pragma mark UI bindings


@interface BXTargetActionBinding : BXBaseOutputBinding
{
    __unsafe_unretained id _target;
    SEL _pressedAction;
    SEL _releasedAction;
}
@property (assign, nonatomic) id target;
@property (assign, nonatomic) SEL pressedAction;
@property (assign, nonatomic) SEL releasedAction;

+ (id) bindingWithTarget: (id)target pressedAction: (SEL)pressedAction releasedAction: (SEL)releasedAction;

@end



#pragma mark Meta-bindings

//Sends a signal to another binding at a certain interval while the input value is > 0.
//Stops sending the signal when the input value is 0.
//Can be given a delegate to which it will send signals whenever the binding fires.
@protocol BXPeriodicOutputBindingDelegate;
@interface BXPeriodicOutputBinding : BXBaseOutputBinding
{
    __unsafe_unretained NSTimer *_timer;
    __unsafe_unretained id <BXPeriodicOutputBindingDelegate> _delegate;
    NSTimeInterval _period;
    NSTimeInterval _lastUpdated;
}

//The delegate to whom we will send BXPeriodicOutputBindingDelegate messages whenever the binding fires.
@property (assign, nonatomic) id <BXPeriodicOutputBindingDelegate> delegate;

//The frequency with which to fire signals. Defaults to 1 / 30.0, i.e. 30 times a second.
@property (assign, nonatomic) NSTimeInterval period;

//Called whenever the timer fires, with the elapsed time since the previous firing.
//Must be implemented by subclasses.
- (void) applyPeriodicUpdateForTimeStep: (NSTimeInterval)timeStep;

@end

@protocol BXPeriodicOutputBindingDelegate <NSObject>

//Posted to the delegate whenever the specified binding updates itself.
//(It is up to the delegate to interrogate the binding as to what change actually occurred.)
- (void) outputBindingDidUpdate: (BXPeriodicOutputBinding *)binding;

@end


//Increments (or decrements) the value of an axis over time.
//Useful for mimicking throttle axes that don't return to 0 when released.
@interface BXEmulatedJoystickAxisAdditiveBinding : BXPeriodicOutputBinding
{
    id <BXEmulatedJoystick> _joystick;
    NSString *_axisName;
    float _ratePerSecond;
    float _outputThreshold;
}

//The joystick and axis this binding will increment/decrement.
@property (retain, nonatomic) id <BXEmulatedJoystick> joystick;
@property (copy, nonatomic) NSString *axisName;

//Output axis values below this amount will be snapped to zero.
@property (assign, nonatomic) float outputThreshold;

//How much to increment/decrement the axis value by over the course of one second,
//while the input value is at maximum. If this is positive, the axis value will increase;
//if negative, the axis value will decrease.
@property (assign, nonatomic) float ratePerSecond;

+ (id) bindingWithJoystick: (id <BXEmulatedJoystick>)joystick axis: (NSString *)axisName rate: (float)ratePerSecond;

@end