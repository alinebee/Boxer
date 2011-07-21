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

@protocol BXHIDInputBindingDelegate;
@class BXHIDEvent;
@class DDHidUsage;
@protocol BXHIDInputBinding <NSObject, NSCoding>

//The delegate to which to send input notifications. This is not retained.
@property (assign, nonatomic) id <BXHIDInputBindingDelegate> delegate;

//Return an input binding of the appropriate type initialized with default values.
+ (id) binding;

//Translate the specified event and perform the appropriate action on the destination joystick.
- (void) processEvent: (BXHIDEvent *)event
			forTarget: (id <BXEmulatedJoystick>)target;

@end


//The base implementation of the BXHIDInputBinding class, containing common logic used by all bindings.
//Not directly instantiatable.
@interface BXBaseHIDInputBinding: NSObject <BXHIDInputBinding>
{
    id <BXHIDInputBindingDelegate> delegate;
}
@end


//Translates an axis on an HID controller to an emulated joystick axis.
@interface BXAxisToAxis: BXBaseHIDInputBinding
{
	SEL axisSelector;
	BOOL unidirectional;
	BOOL inverted;
	float deadzone;
	float previousValue;
}
//Convenience method to return a binding preconfigured to send axis
//input as the specified button.
+ (id) bindingWithAxisSelector: (SEL)axisSelector;

//Absolute axis values below this amount will be rounded to 0. Defaults to 0.25f.
@property (assign, nonatomic) float deadzone;

//Whether the axis input is inverted. Defaults to NO.
@property (assign, nonatomic, getter=isInverted) BOOL inverted;

//Whether the axis input represents a unidirectional trigger. Defaults to NO.
//If YES, the input will be mapped to 0->1.0 instead of -1.0->1.0.
@property (assign, nonatomic, getter=isUnidirectional) BOOL unidirectional;

//The axis selector to call on the emulated joystick.
@property (assign, nonatomic) SEL axisSelector;

@end


//Adds input from an HID controller axis to the current value of an emulated axis:
//Used for emulating axes that don’t return to center.
@interface BXAxisToAxisAdditive: BXAxisToAxis
{
    NSTimeInterval lastUpdated;
    float ratePerSecond;
    NSTimer *inputTimer;
}

//How much to increment the emulated axis per second if the controller axis input is at full strength.
//Defaults to 1.0f: the emulated axis will go from 0 to 1.0 in 1 second when the axis is on full.
@property (assign, nonatomic) float ratePerSecond;

@end


//Translates a button on an HID controller to an emulated joystick button.
@interface BXButtonToButton: BXBaseHIDInputBinding
{
	NSUInteger button;
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
	SEL axisSelector;
	float pressedValue;
	float releasedValue;
}

//Convenience method to return a binding preconfigured to send button
//input to the specified axis selector.
+ (id) bindingWithAxisSelector: (SEL)axis;

//The axis value to apply when the button is pressed. Defaults to +1.0f.
@property (assign, nonatomic) float pressedValue;

//The axis value to apply when the button is released. Defaults to 0.0f.
@property (assign, nonatomic) float releasedValue;

//The axis selector to call on the emulated joystick.
@property (assign, nonatomic) SEL axisSelector;

@end


//Translates an axis on an HID controller to an emulated joystick button,
//with a specific threshold over which the button is considered pressed.
@interface BXAxisToButton: BXBaseHIDInputBinding
{
	float threshold;
	BOOL unidirectional;
	NSUInteger button;
	BOOL previousValue;
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
	SEL POVSelector;
}

//The POV selector to call on the emulated joystick. Defaults to POVChangedTo:
@property (assign, nonatomic) SEL POVSelector;

@end


//Translates a set of 4 buttons on an HID controller to an emulated POV switch.
@interface BXButtonsToPOV: BXBaseHIDInputBinding
{
	SEL POVSelector;
	DDHidUsage *northButtonUsage;
	DDHidUsage *southButtonUsage;
	DDHidUsage *eastButtonUsage;
	DDHidUsage *westButtonUsage;
	NSUInteger buttonStates;
}

//The POV selector to call on the emulated joystick. Defaults to POVChangedTo:
@property (assign, nonatomic) SEL POVSelector;

//The buttons corresponding to the N, S, E and W directions on the POV switch.
//Their pressed/released state is tracked individually.
@property (copy, nonatomic) DDHidUsage *northButtonUsage;
@property (copy, nonatomic) DDHidUsage *southButtonUsage;
@property (copy, nonatomic) DDHidUsage *eastButtonUsage;
@property (copy, nonatomic) DDHidUsage *westButtonUsage;

@end


//Translates a POV switch or D-pad on an HID controller to a pair of X and Y axes
//on the emulated joystick, such that WE will set the X axis and NS will set the Y axis.
@interface BXPOVToAxes: BXBaseHIDInputBinding
{
	SEL xAxisSelector;
	SEL yAxisSelector;
}

//Convenience method to return a binding preconfigured to send POV
//input to the specified selectors.
+ (id) bindingWithXAxisSelector: (SEL)x
                  YAxisSelector: (SEL)y;

//The POV selector to call on the emulated joystick for WE input.
//Defaults to xAxisChangedTo:
@property (assign, nonatomic) SEL xAxisSelector;

//The POV selector to call on the emulated joystick for NS input.
//Defaults to yAxisChangedTo:
@property (assign, nonatomic) SEL yAxisSelector;

@end


//Sends axis input to one of two alternate bindings, depending on whether the
//input is positive or negative. The selector for the current polarity will be
//sent the full axis value, while the opposite binding will be sent a value of
//0.0.
@interface BXAxisToBindings: BXBaseHIDInputBinding
{
	id <BXHIDInputBinding> positiveBinding;
	id <BXHIDInputBinding> negativeBinding;
	float previousValue;
}

//Convenience method to return a binding preconfigured to split axis input
//to the specified axis selectors.
+ (id) bindingWithPositiveAxisSelector: (SEL)positive
                  negativeAxisSelector: (SEL)negative;

//Convenience method to return a binding preconfigured to split axis input
//to the specified buttons.
+ (id) bindingWithPositiveButton: (NSUInteger)positive
                  negativeButton: (NSUInteger)negative;

//The binding to which to pass positive axis values.
@property (retain, nonatomic) id <BXHIDInputBinding> positiveBinding;

//The binding to which to pass negative axis values.
@property (retain, nonatomic) id <BXHIDInputBinding> negativeBinding;

@end



@protocol BXHIDInputBindingDelegate <NSObject>

//Called by processEvent:forTarget: whenever updating an emulated joystick.
- (void) binding: (id <BXHIDInputBinding>)binding
 didUpdateTarget: (id <BXEmulatedJoystick>)target
   usingSelector: (SEL)selector
          object: (id)object;
@end