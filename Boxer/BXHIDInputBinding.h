/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//The BXInputBinding classes convert various types of ADBHIDEvent input data into actions
//to perform on a BXEmulatedJoystick.


#import <Cocoa/Cocoa.h>
#import "ADBHIDEvent.h"
#import "BXOutputBinding.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Protocols

@protocol BXHIDInputBinding <NSObject>

/// Returns an autoreleased instance of the class.
+ (instancetype) binding;

/// Handles the specified HID event and passes it on to any output bindings.
- (void) processEvent: (ADBHIDEvent *)event;

@end


@interface BXHIDButtonBinding : NSObject <BXHIDInputBinding>
{
    id <BXOutputBinding> _outputBinding;
}

/// This binding will be sent 1.0 when the joystick button is pressed, and 0.0 when released.
@property (retain, nonatomic) id <BXOutputBinding> outputBinding;

+ (instancetype) bindingWithOutputBinding: (id <BXOutputBinding>)outputBinding;

@end


@interface BXHIDAxisBinding : NSObject <BXHIDInputBinding>
{
    id <BXOutputBinding> _positiveBinding;
    id <BXOutputBinding> _negativeBinding;
    
    BOOL _inverted;
    float _deadzone;
    BOOL _unidirectional;
}

/// This binding will be sent the absolute axis value when the axis is positive,
/// and 0.0 when the axis is centered or negative.
@property (retain, nonatomic, nullable) id <BXOutputBinding> positiveBinding;

/// This binding will be sent the absolute axis value when the axis is negative,
/// and 0.0 when the axis is centered or positive.
@property (retain, nonatomic, nullable) id <BXOutputBinding> negativeBinding;

/// If <code>YES</code>, axis input will be flipped (meaning the negative binding will be triggered
/// when the axis is positive, and vice-versa).
@property (assign, nonatomic, getter=isInverted) BOOL inverted;

/// The deadzone below which all values will be snapped to 0.
@property (assign, nonatomic) float deadzone;

/// Whether this is a trigger-style axis with only one direction of travel.
/// If YES, the full -1.0->1.0 input range will be mapped to 0.0->1.0 before inverting.
@property (assign, nonatomic, getter=isUnidirectional) BOOL unidirectional;

+ (instancetype) bindingWithPositiveBinding: (nullable id <BXOutputBinding>)positiveBinding
                            negativeBinding: (nullable id <BXOutputBinding>)negativeBinding;

@end


@interface BXHIDPOVSwitchBinding : NSObject <BXHIDInputBinding>
{
    NSMutableDictionary *_outputBindings;
    ADBHIDPOVSwitchDirection _previousDirection;
}

/// Creates a new binding from interleaved pairs of bindings and directions, followed by a nil sentinel.
+ (instancetype) bindingWithOutputBindingsAndDirections: (id <BXOutputBinding>)binding, ... NS_REQUIRES_NIL_TERMINATION;

/// Set/get the binding for a particular cardinal POV direction.
/// This binding will be sent 1.0 when the POV is pressed in that direction,
/// and 0.0 when the POV is released or switches to another direction.
/// If a direction is not explicitly bound, then the bindings for the
/// two directions on either side will be triggered simultaneously instead.
- (id <BXOutputBinding>) bindingForDirection: (ADBHIDPOVSwitchDirection)direction;
- (void) setBinding: (id <BXOutputBinding>)binding forDirection: (ADBHIDPOVSwitchDirection) direction;

@end



/*
@protocol BXHIDInputBinding <NSObject, NSCoding>

//Returns whether bindings of this type can talk to the specified target.
+ (BOOL) supportsTarget: (id)target;

//Return an input binding of the appropriate type initialized with default values.
+ (id) binding;

//The target joystick or keyboard upon which this binding acts when it is triggered.
@property (retain, nonatomic) id target;

//Translate the specified event and perform the appropriate action for this binding on the binding's target.
- (void) processEvent: (ADBHIDEvent *)event;

@end


//Represents a binding that sends periodic input outside of the normal event flow.
//It has a delegate to which it sends notification messages whenever it posts input.

@protocol BXPeriodicInputBindingDelegate;
@protocol BXPeriodicInputBinding <NSObject>

@property (assign, nonatomic) id <BXPeriodicInputBindingDelegate> delegate;

@end

@protocol BXPeriodicInputBindingDelegate <NSObject>

//Posted to the delegate whenever the specified binding sends its input.
//(It is up to the delegate to interrogate the binding as to what that input was.)
- (void) binding: (id <BXPeriodicInputBinding>) binding didSendInputToTarget: (id)target;

@end


#pragma mark - Emulated joystick bindings

//The base implementation of the BXHIDInputBinding protocol for talking to emulated joysticks.
//Contains common logic used by all joystick-related bindings. Should not be used directly.
@interface BXBaseEmulatedJoystickInputBinding : NSObject <BXHIDInputBinding>
{
    id <BXEmulatedJoystick> _target;
}
@property (retain, nonatomic) id <BXEmulatedJoystick> target;

@end


//Translates an axis on an HID controller to an emulated joystick axis.
@interface BXAxisToAxis: BXBaseEmulatedJoystickInputBinding
{
	NSString *_axis;
	BOOL _unidirectional;
	BOOL _inverted;
	float _deadzone;
	float _previousValue;
}
//Convenience method to return a binding preconfigured to send axis
//input to the specified axis.
+ (id) bindingWithAxis: (NSString *)axisName;

//Absolute axis values below this amount will be rounded to 0. Defaults to 0.25f.
@property (assign, nonatomic) float deadzone;

//Whether the axis input is inverted. Defaults to NO.
@property (assign, nonatomic, getter=isInverted) BOOL inverted;

//Whether the axis input represents a unidirectional trigger. Defaults to NO.
//If YES, the input will be mapped to 0->1.0 instead of -1.0->1.0.
@property (assign, nonatomic, getter=isUnidirectional) BOOL unidirectional;

//The axis to set on the emulated joystick, specified as a property key name.
@property (copy, nonatomic) NSString *axis;

@end


//Adds input from an HID controller axis to the current value of an emulated axis:
//Used for emulating axes that don’t return to center.
@interface BXAxisToAxisAdditive: BXAxisToAxis <BXPeriodicInputBinding>
{
    NSTimeInterval _lastUpdated;
    float _ratePerSecond;
    float _emulatedDeadzone;
    NSTimer *_inputTimer;
    __unsafe_unretained id <BXPeriodicInputBindingDelegate> _delegate;
}

//How much to increment the emulated axis per second if the controller axis input is at full strength.
//Defaults to 1.0f: the emulated axis will go from 0 to 1.0 in 1 second when the axis is on full.
@property (assign, nonatomic) float ratePerSecond;

//The range to 'snap' to 0 when incrementing the emulated axis. Defaults to 0.1.
//Note that this is independent from the deadzone property, which applies a deadzone to the real axis.
@property (assign, nonatomic) float emulatedDeadzone;
@end


//Translates a button on an HID controller to an emulated joystick button.
@interface BXButtonToButton: BXBaseEmulatedJoystickInputBinding
{
	BXEmulatedJoystickButton _button;
}

//Convenience method to return a binding preconfigured to send button
//input as the specified button.
+ (id) bindingWithButton: (BXEmulatedJoystickButton)button;

//The BXEmulatedButton constant of the button to bind to on the emulated joystick.
@property (assign, nonatomic) BXEmulatedJoystickButton button;

@end


//Translates a button on an HID controller to an emulated joystick axis,
//with specific axis values for the pressed/released state of the button.
@interface BXButtonToAxis: BXBaseEmulatedJoystickInputBinding
{
	NSString *_axis;
	float _pressedValue;
	float _releasedValue;
}

//Convenience method to return a binding preconfigured to send button
//input to the specified axis.
+ (id) bindingWithAxis: (NSString *)axisName;

//The axis value to apply when the button is pressed. Defaults to +1.0f.
@property (assign, nonatomic) float pressedValue;

//The axis value to apply when the button is released. Defaults to 0.0f.
@property (assign, nonatomic) float releasedValue;

//The axis to set on the emulated joystick, specified as a property key name.
@property (copy, nonatomic) NSString *axis;

@end


//Translates an axis on an HID controller to an emulated joystick button,
//with a specific threshold over which the button is considered pressed.
@interface BXAxisToButton: BXBaseEmulatedJoystickInputBinding
{
	float _threshold;
	BOOL _unidirectional;
	BXEmulatedJoystickButton _button;
	BOOL _previousValue;
}

//Convenience method to return a binding preconfigured to send axis
//input as the specified button.
+ (id) bindingWithButton: (BXEmulatedJoystickButton)button;

//The normalized axis value over which the button will be treated as pressed.
//Ignores polarity to treat positive and negative axis values the same,
//measuring only distance from 0.
//Defaults to 0.25f.
@property (assign, nonatomic) float threshold;

//Whether the axis input represents a unidirectional trigger. Defaults to NO.
//If YES, then the axis input will be normalized to 0->1.0 before considering
//the threshold.
//(Note that this works slightly differently to unidirectional on BXAxisToAxis.)
@property (assign, nonatomic, getter=isUnidirectional) BOOL unidirectional;

//The BXEmulatedButton constant of the button to bind to on the emulated joystick.
@property (assign, nonatomic) BXEmulatedJoystickButton button;

@end


//Translates a POV switch or D-pad on an HID controller to an emulated POV switch.
@interface BXPOVToPOV: BXBaseEmulatedJoystickInputBinding
{
	NSUInteger _POVNumber;
}

//The POV number to apply to on the emulated joystick. Defaults to 0.
@property (assign, nonatomic) NSUInteger POVNumber;

@end


//Translates a button to a single cardinal POV direction
@interface BXButtonToPOV: BXBaseEmulatedJoystickInputBinding
{
	NSUInteger _POVNumber;
    BXEmulatedPOVDirection _direction;
}

//The POV number to apply to on the emulated joystick. Defaults to 0.
@property (assign, nonatomic) NSUInteger POVNumber;

//The direction to apply when the button is pressed.
@property (assign, nonatomic) BXEmulatedPOVDirection direction;

+ (id) bindingWithDirection: (BXEmulatedPOVDirection) direction;

@end


//Translates a POV switch or D-pad on an HID controller to a pair of X and Y axes
//on the emulated joystick, such that WE will set the X axis and NS will set the Y axis.
@interface BXPOVToAxes: BXBaseEmulatedJoystickInputBinding
{
	NSString *_xAxis;
	NSString *_yAxis;
}

//Convenience method to return a binding preconfigured to send POV
//input to the specified axes.
+ (id) bindingWithXAxis: (NSString *)xAxis
                  YAxis: (NSString *)yAxis;

//The axis to set on the emulated joystick for WE input.
//Defaults to xAxisChangedTo:
@property (copy, nonatomic) NSString *xAxis;

//The axis to set on the emulated joystick for NS input.
//Defaults to yAxisChangedTo:
@property (copy, nonatomic) NSString *yAxis;

@end


//Sends axis input to one of two alternate bindings, depending on whether the
//input is positive or negative. The binding for the current polarity will be
//sent the full axis value, while the opposite binding will be sent a value of
//0.0.
@interface BXAxisToBindings: BXBaseEmulatedJoystickInputBinding
{
	id <BXHIDInputBinding> _positiveBinding;
	id <BXHIDInputBinding> _negativeBinding;
    float _deadzone;
    float _previousValue;
}

//Convenience method to return a binding preconfigured to split axis input
//to the specified axes, specified as property key names.
+ (id) bindingWithPositiveAxis: (NSString *)positiveAxis
                  negativeAxis: (NSString *)negativeAxis;

//Convenience method to return a binding preconfigured to split axis input
//to the specified buttons.
+ (id) bindingWithPositiveButton: (BXEmulatedJoystickButton)positiveButton
                  negativeButton: (BXEmulatedJoystickButton)negativeButton;

//The binding to which to pass positive axis values.
@property (retain, nonatomic) id <BXHIDInputBinding> positiveBinding;

//The binding to which to pass negative axis values.
@property (retain, nonatomic) id <BXHIDInputBinding> negativeBinding;

//The deadzone inside which neither binding will be triggered.
@property (assign, nonatomic) float deadzone;

@end


//Triggers a separate binding for each cardinal direction on the POV.
//This will synthesize BXHIDButtonDown and BXHIDButtonUp events to send
//to the individual bindings (which are thus expected to respond to button events).
//Diagonals can have their own individual bindings; if no explicit binding
//is given for a diagonal, then the adjacent horizontal and vertical bindings
//will be triggered instead.
@interface BXPOVToBindings : BXBaseEmulatedJoystickInputBinding
{
    NSMutableDictionary *_bindings;
    BXHIDPOVSwitchDirection _previousValue;
}

//Creates a new binding from interleaved pairs of bindings and directions, followed by a nil sentinel.
+ (id) bindingWithBindingsAndDirections: (id <BXHIDInputBinding>)binding, ... NS_REQUIRES_NIL_TERMINATION;

- (id <BXHIDInputBinding>) bindingForDirection: (BXHIDPOVSwitchDirection)direction;
- (void) setBinding: (id <BXHIDInputBinding>)binding forDirection: (BXHIDPOVSwitchDirection) direction;

@end


#pragma mark - Emulated keyboard bindings

//The base implementation of the BXHIDInputBinding protocol for talking to emulated keyboards.
//Contains common logic used by all keyboard-related bindings. Should not be used directly.
@interface BXBaseEmulatedKeyboardInputBinding : NSObject <BXHIDInputBinding>
{
    BXEmulatedKeyboard *_target;
    BXDOSKeyCode _keyCode;
}
@property (retain, nonatomic) BXEmulatedKeyboard *target;

//The keycode that will be triggered by this binding.
@property (assign, nonatomic) BXDOSKeyCode keyCode;

//Convenience method to return a binding preconfigured with the specified key code.
+ (id) bindingWithKeyCode: (BXDOSKeyCode)keyCode;
- (id) initWithKeyCode: (BXDOSKeyCode)keyCode;

@end


//Translates an HID controller button into an emulated keypress.
@interface BXButtonToKey : BXBaseEmulatedKeyboardInputBinding
@end

//Translates HID controller axis input into an emulated keypress,
//which will be triggered when the axis is over a certain threshold.
@interface BXAxisToKey: BXBaseEmulatedKeyboardInputBinding
{
	float _threshold;
	BOOL _unidirectional;
	BOOL _previousValue;
}

//The normalized axis value over which the button will be treated as pressed.
//Ignores polarity to treat positive and negative axis values the same,
//measuring only distance from 0.
//Defaults to 0.25f.
@property (assign, nonatomic) float threshold;

//Whether the axis input represents a unidirectional trigger. Defaults to NO.
//If YES, then the axis input will be normalized to 0->1.0 before considering
//the threshold.
//(Note that this works slightly differently to unidirectional on BXAxisToAxis.)
@property (assign, nonatomic, getter=isUnidirectional) BOOL unidirectional;

@end

*/

NS_ASSUME_NONNULL_END
