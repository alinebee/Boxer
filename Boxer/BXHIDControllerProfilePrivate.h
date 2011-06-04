/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//Defines a 'private' interface for BXHIDControllerProfile and its subclasses

#import "BXHIDControllerProfile.h"
#import "BXEmulatedJoystick.h"
#import "BXHIDInputBinding.h"
#import "DDHidDevice+BXDeviceExtensions.h"


@interface BXHIDControllerProfile ()

//Generates the input bindings for the controller to the emulated joystick.
//Called whenever the controller or emulated joystick are changed.
- (void) generateBindings;

//Called by generateBindings to create the bindings for each particular kind of element.
//Intended to be overridden by subclasses for handling logic that pertains to sets of inputs.
- (void) bindAxisElements: (NSArray *)elements;
- (void) bindButtonElements: (NSArray *)elements;
- (void) bindPOVElements: (NSArray *)elements;

//Returns a BXHIDInputBinding to bind the specified element on the profile's HID controller
//to the profile's emulated joystick. Must return nil if the element should not be bound.
//Used by generateBindings and intended to be overridden by subclasses for individual bindings.
- (id <BXHIDInputBinding>) generatedBindingForAxisElement: (DDHidElement *)element;
- (id <BXHIDInputBinding>) generatedBindingForButtonElement: (DDHidElement *)element;
- (id <BXHIDInputBinding>) generatedBindingForPOVElement: (DDHidElement *)element;


#pragma mark -
#pragma mark Profile registration and matching

//Registers the specified profile subclass as a custom profile.
//Should be called in each subclass's +load method.
+ (void) registerProfile: (BXHIDControllerProfile *)profile;

//Returns whether the implementing class is suitable for the specified controller.
//Returns NO by default and is intended to be overridden by subclasses.
//Used by BXHIDControllerProfile profileClassForHIDController: to find custom
//profile classes for known devices.
+ (BOOL) matchesHIDController: (DDHidJoystick *)HIDController;

//Returns the BXHIDControllerProfile subclass most suited for the specified controller,
//falling back on BXHIDControllerProfile itself if none more suitable is found.
//Should not be overridden.
+ (Class) profileClassForHIDController: (DDHidJoystick *)HIDController;

@end