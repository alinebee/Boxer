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
@class DDHidElement;
@protocol BXHIDInputBinding

//Return a input binding of the appropriate type initialized with default values.
+ (id) binding;

//Translate the specified event and perform the appropriate action on the destination joystick.
- (void) processEvent: (BXHIDEvent *)event
			forTarget: (id <BXEmulatedJoystick>)target;

@end


//The base implementation of the BXHIDInputBinding class, containing common logic used by all bindings.
//Not directly instantiatable.
@interface BXBaseHIDInputBinding: NSObject <BXHIDInputBinding>
@end


//Translates an axis on an HID controller to an emulated joystick axis.
@interface BXAxisToAxis: BXBaseHIDInputBinding
{
	SEL axisSelector;
	float deadzone;
	float previousValue;
}
//Absolute axis values below this amount will be rounded to 0. Defaults to 0.25f.
@property (assign, nonatomic) float deadzone;

//The axis selector to call on the emulated joystick.
@property (assign, nonatomic) SEL axisSelector;

@end


//Translates a button on an HID controller to an emulated joystick button.
@interface BXButtonToButton: BXBaseHIDInputBinding
{
	NSUInteger button;
}

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
	NSUInteger button;
	BOOL previousValue;
}

//The axis value above which the button will be treated as pressed. Defaults to 0.25f.
@property (assign, nonatomic) float threshold;

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
	DDHidElement *northButton;
	DDHidElement *southButton;
	DDHidElement *eastButton;
	DDHidElement *westButton;
	NSUInteger buttonStates;
}

//The POV selector to call on the emulated joystick. Defaults to POVChangedTo:
@property (assign, nonatomic) SEL POVSelector;

//The buttons corresponding to the N, S, E and W directions on the POV switch.
//Their pressed/released state is tracked individually.
@property (assign, nonatomic) DDHidElement *northButton;
@property (assign, nonatomic) DDHidElement *southButton;
@property (assign, nonatomic) DDHidElement *eastButton;
@property (assign, nonatomic) DDHidElement *westButton;

@end


//Translates a POV switch or D-pad on an HID controller to a pair of X and Y axes
//on the emulated joystick, such that WE will set the X axis and NS will set the Y axis.
@interface BXPOVToAxes: BXBaseHIDInputBinding
{
	SEL xAxisSelector;
	SEL yAxisSelector;
}

//The POV selector to call on the emulated joystick for WE input.
//Defaults to xAxisChangedTo:
@property (assign, nonatomic) SEL xAxisSelector;

//The POV selector to call on the emulated joystick for NS input.
//Defaults to yAxisChangedTo:
@property (assign, nonatomic) SEL yAxisSelector;

@end