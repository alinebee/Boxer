/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Foundation/Foundation.h>
#import "BXEmulatedJoystick.h"
#import "BXEmulatedKeyboard.h"

NS_ASSUME_NONNULL_BEGIN

//BXOutputBindings take a scalar input value from 0.0 to 1.0 and trigger a signal on an emulated input device:
//e.g. an emulated joystick or keyboard.


#pragma mark - Constants

typedef NS_ENUM(NSInteger, BXAxisPolarity) {
    kBXAxisNegative = -1,
    kBXAxisPositive = 1,
};


/// The minimum and maximum acceptable input values.
#define kBXOutputBindingMin 0.0
#define kBXOutputBindingMax 1.0


@protocol BXEmulatedJoystick;
@class BXEmulatedKeyboard;


#pragma mark - Protocols

/// BXOutputBindings take a scalar input value from 0.0 to 1.0 and trigger a signal on an emulated input device:
/// e.g. an emulated joystick or keyboard.
@protocol BXOutputBinding <NSObject>

/// Returns an autoreleased instance of the class.
+ (instancetype) binding;

/// Receives a raw input value.
- (void) applyInputValue: (float)value;

@end


/// A base class to provide standard functionality to all output bindings. Should not be used directly.
@interface BXBaseOutputBinding : NSObject <BXOutputBinding>

/// Input values below this amount will be rounded to 0. This is useful as a deadzone.
@property (nonatomic) float threshold;

/// Whether the input values will be flipped.
@property (nonatomic) BOOL inverted;

/// The last raw value that was provided to this binding.
@property (readonly, nonatomic) float latestValue;

/// The last normalized value that was processed by this binding.
@property (readonly, nonatomic) float latestNormalizedValue;

/// The current scalar value of the property to which this binding is attached.
/// Returns 0 by default; should be overridden by subclasses.
@property (readonly, nonatomic) float effectiveValue;

/// Receives a raw input value. The base implementation normalizes it with normalizedValue:,
/// and then calls applyNormalizedInputValue: with the result if it differs from the previous
/// normalized value. This also updates previousValue: and previousNormalizedValue: to match.
- (void) applyInputValue: (float)value;

/// Called by applyInputValue: with an already-normalized value. Must be implemented by subclasses.
- (void) applyNormalizedInputValue: (float)value;

/// Returns a normalized version of the specified input value, normalized according to our threshold and inverted flag.
/// May be overridden by subclasses to do additional normalizing.
- (float) normalizedValue: (float)value;

@end


#pragma mark - Joystick bindings

/// The base class for all joystick output bindings. Should not be used directly.
@interface BXBaseEmulatedJoystickBinding : BXBaseOutputBinding

/// The joystick to which we send input signals.
@property (nonatomic) id <BXEmulatedJoystick> joystick;

@end


/// Presses a joystick button when input > 0, releases it when input = 0.
@interface BXEmulatedJoystickButtonBinding : BXBaseEmulatedJoystickBinding

@property (nonatomic) BXEmulatedJoystickButton button;

+ (instancetype) bindingWithJoystick: (id <BXEmulatedJoystick>)joystick button: (BXEmulatedJoystickButton)button;

@end


/// Maps the input value as input on a particular joystick axis and polarity.
@interface BXEmulatedJoystickAxisBinding : BXBaseEmulatedJoystickBinding

@property (copy, nonatomic) NSString *axisName;
@property (nonatomic) BXAxisPolarity polarity;

+ (instancetype) bindingWithJoystick: (id <BXEmulatedJoystick>)joystick
                                axis: (NSString *)axisName
                            polarity: (BXAxisPolarity)polarity;

@end


/// Presses a particular hat-switch direction when input > 0, releases it when input = 0.
@interface BXEmulatedJoystickPOVDirectionBinding : BXBaseEmulatedJoystickBinding

@property (nonatomic) NSUInteger POVNumber;
@property (nonatomic) BXEmulatedPOVDirection POVDirection;

+ (instancetype) bindingWithJoystick: (id <BXEmulatedJoystick>)joystick
                                 POV: (NSUInteger)POVNumber
                           direction: (BXEmulatedPOVDirection)direction;

@end


#pragma mark - Keyboard bindings

/// Presses a particular keyboard key when input > 0, releases it when input = 0.
@interface BXEmulatedKeyboardKeyBinding : BXBaseOutputBinding

/// The keyboard to which we send key signals.
@property (strong, nonatomic) BXEmulatedKeyboard *keyboard;

/// The key code to press/release when this binding is activated.
@property (nonatomic) BXDOSKeyCode keyCode;

+ (instancetype) bindingWithKeyboard: (BXEmulatedKeyboard *)keyboard keyCode: (BXDOSKeyCode)keyCode;

@end


#pragma mark UI bindings


@interface BXTargetActionBinding : BXBaseOutputBinding

@property (weak, nonatomic, nullable) id target;
@property (nonatomic, nullable) SEL pressedAction;
@property (nonatomic, nullable) SEL releasedAction;

+ (instancetype) bindingWithTarget: (id)target pressedAction: (nullable SEL)pressedAction releasedAction: (nullable SEL)releasedAction;

@end



#pragma mark Meta-bindings

@protocol BXPeriodicOutputBindingDelegate;

/// Sends a signal to another binding at a certain interval while the input value is > 0.
/// Stops sending the signal when the input value is 0.
/// Can be given a delegate to which it will send signals whenever the binding fires.
@interface BXPeriodicOutputBinding : BXBaseOutputBinding

/// The delegate to whom we will send BXPeriodicOutputBindingDelegate messages whenever the binding fires.
@property (weak, nonatomic) id <BXPeriodicOutputBindingDelegate> delegate;

/// The frequency with which to fire signals. Defaults to 1 / 30.0, i.e. 30 times a second.
@property (nonatomic) NSTimeInterval period;

/// Called whenever the timer fires, with the elapsed time since the previous firing.
/// Must be implemented by subclasses.
- (void) applyPeriodicUpdateForTimeStep: (NSTimeInterval)timeStep;

@end

@protocol BXPeriodicOutputBindingDelegate <NSObject>

/// Posted to the delegate whenever the specified binding updates itself.
/// (It is up to the delegate to interrogate the binding as to what change actually occurred.)
- (void) outputBindingDidUpdate: (BXPeriodicOutputBinding *)binding;

@end


/// Increments (or decrements) the value of an axis over time.
/// Useful for mimicking throttle axes that don't return to 0 when released.
@interface BXEmulatedJoystickAxisAdditiveBinding : BXPeriodicOutputBinding

/// The joystick and axis this binding will increment/decrement.
@property (strong, nonatomic) id <BXEmulatedJoystick> joystick;
@property (copy, nonatomic) NSString *axisName;

/// Output axis values below this amount will be snapped to zero.
@property (nonatomic) float outputThreshold;

/// How much to increment/decrement the axis value by over the course of one second,
/// while the input value is at maximum. If this is positive, the axis value will increase;
/// if negative, the axis value will decrease.
@property (nonatomic) float ratePerSecond;

+ (instancetype) bindingWithJoystick: (id <BXEmulatedJoystick>)joystick axis: (NSString *)axisName rate: (float)ratePerSecond;

@end

NS_ASSUME_NONNULL_END
