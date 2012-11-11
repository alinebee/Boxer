/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//The BXInputBinding classes convert various types of BXHIDEvent input data into actions
//to perform on a BXEmulatedJoystick.


#import <Cocoa/Cocoa.h>
#import "BXEmulatedJoystick.h"

@class BXHIDEvent;
@class DDHidUsage;

#pragma mark -
#pragma mark Protocols

@protocol BXHIDInputBinding <NSObject, NSCoding>

//Return an input binding of the appropriate type initialized with default values.
+ (id) binding;

//Translate the specified event and perform the appropriate action on the destination joystick.
- (void) processEvent: (BXHIDEvent *)event
			forTarget: (id <BXEmulatedJoystick>)target;

@end


//Represents a binding that sends periodic input outside of the normal event flow.
//It has a delegate to which it sends notification messages whenever it posts input.

@protocol BXPeriodicInputBindingDelegate;
@protocol BXPeriodicInputBinding <BXHIDInputBinding>

@property (assign, nonatomic) id <BXPeriodicInputBindingDelegate> delegate;

@end

@protocol BXPeriodicInputBindingDelegate <NSObject>

//Posted to the delegate whenever the specified binding sends its input.
//(It is up to the delegate to interrogate the binding as to what that input was.)
- (void) binding: (id <BXPeriodicInputBinding>) binding didSendInputToTarget: (id <BXEmulatedJoystick>)target;

@end


#pragma mark -
#pragma mark Concrete binding types

//The base implementation of the BXHIDInputBinding class,
//containing common logic used by all bindings.
//Should not be used directly.
@interface BXBaseHIDInputBinding: NSObject <BXHIDInputBinding>
@end


//Translates an axis on an HID controller to an emulated joystick axis.
@interface BXAxisToAxis: BXBaseHIDInputBinding
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
    id <BXPeriodicInputBindingDelegate> _delegate;
}

//How much to increment the emulated axis per second if the controller axis input is at full strength.
//Defaults to 1.0f: the emulated axis will go from 0 to 1.0 in 1 second when the axis is on full.
@property (assign, nonatomic) float ratePerSecond;

//The range to 'snap' to 0 when incrementing the emulated axis. Defaults to 0.1.
//Note that this is independent from the deadzone property, which applies a deadzone to the real axis.
@property (assign, nonatomic) float emulatedDeadzone;
@end


//Translates a button on an HID controller to an emulated joystick button.
@interface BXButtonToButton: BXBaseHIDInputBinding
{
	NSUInteger _button;
}

//Convenience method to return a binding preconfigured to send button
//input as the specified button.
+ (id) bindingWithButton: (NSUInteger)button;

//The BXEmulatedButton constant of the button to bind to on the emulated joystick.
@property (assign, nonatomic) NSUInteger button;

@end


//Translates a button on an HID controller to an emulated joystick axis,
//with specific axis values for the pressed/released state of the button.
@interface BXButtonToAxis: BXBaseHIDInputBinding
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
@interface BXAxisToButton: BXBaseHIDInputBinding
{
	float _threshold;
	BOOL _unidirectional;
	NSUInteger _button;
	BOOL _previousValue;
}

//Convenience method to return a binding preconfigured to send axis
//input as the specified button.
+ (id) bindingWithButton: (NSUInteger)button;

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
@property (assign, nonatomic) NSUInteger button;

@end


//Translates a POV switch or D-pad on an HID controller to an emulated POV switch.
@interface BXPOVToPOV: BXBaseHIDInputBinding
{
	NSUInteger _POVNumber;
}

//The POV number to apply to on the emulated joystick. Defaults to 0.
@property (assign, nonatomic) NSUInteger POVNumber;

@end


//Translates a button to a single cardinal POV direction
@interface BXButtonToPOV: BXBaseHIDInputBinding
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
@interface BXPOVToAxes: BXBaseHIDInputBinding
{
	NSString *_xAxis;
	NSString *_yAxis;
}

//Convenience method to return a binding preconfigured to send POV
//input to the specified axes.
+ (id) bindingWithXAxis: (NSString *)x
                  YAxis: (NSString *)y;

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
@interface BXAxisToBindings: BXBaseHIDInputBinding
{
	id <BXHIDInputBinding> _positiveBinding;
	id <BXHIDInputBinding> _negativeBinding;
	float _previousValue;
    float _deadzone;
}

//Convenience method to return a binding preconfigured to split axis input
//to the specified axes, specified as property key names.
+ (id) bindingWithPositiveAxis: (NSString *)positive
                  negativeAxis: (NSString *)negative;

//Convenience method to return a binding preconfigured to split axis input
//to the specified buttons.
+ (id) bindingWithPositiveButton: (NSUInteger)positive
                  negativeButton: (NSUInteger)negative;

//The binding to which to pass positive axis values.
@property (retain, nonatomic) id <BXHIDInputBinding> positiveBinding;

//The binding to which to pass negative axis values.
@property (retain, nonatomic) id <BXHIDInputBinding> negativeBinding;

//The deadzone inside which neither binding will be triggered.
@property (assign, nonatomic) float deadzone;

@end
