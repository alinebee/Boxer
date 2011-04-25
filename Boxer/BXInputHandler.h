/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXInputHandler converts input from OS X into DOSBox input commands. It expects OS X key and
//modifier constants, but does not accept NSEvents or interact with the OS X event framework:
//instead, it uses abstract methods to receive 'predigested' input data from BXInputController.

#import <Foundation/Foundation.h>
#import <SDL/SDL.h>
#import "BXEventConstants.h"


#pragma mark -
#pragma mark Constants

enum {
	BXDOSJoystickTypeAutoDetect = -1,
	BXDOSJoystickTypeNone = 0,
	BX2AxisJoystick,
	BX4AxisJoystick,
	BXThrustmasterFCS,
	BXCHFlightstickPro
};
typedef NSInteger BXDOSJoystickType;

enum {
	BXDOSJoystickUntimed = NO,
	BXDOSJoystickTimed = YES
};
typedef BOOL BXDOSJoystickTimingMode;



enum {
	BXDOSJoystickAxisX = 0,
	BXDOSJoystickAxisY = 1,
	BXDOSJoystick2AxisX = 2,
	BXDOSJoystick2AxisY = 3,
	
	BXCHFlightstickThrottleAxis = 3
};

typedef NSUInteger BXDOSJoystickAxis;

enum {
	BXDOSJoystickButton1 = 0,
	BXDOSJoystickButton2 = 1,
	BXDOSJoystickButton3 = 2,
	BXDOSJoystickButton4 = 3,
	
	BXDOSJoystick2Button1 = 2,
	BXDOSJoystick2Button2 = 3,
	
	//Only available in CH Flightstick/Combatstick mode
	BXCHFlightstickButton5 = 4,
	BXCHFlightstickButton6 = 5
};

typedef NSUInteger BXDOSJoystickButton;

enum {
	BXDOSFlightstickPOVCentered = 0,
	BXDOSFlightstickPOVNorth,
	BXDOSFlightstickPOVEast,
	BXDOSFlightstickPOVSouth,
	BXDOSFlightstickPOVWest
};

typedef NSUInteger BXDOSFlightstickPOVDirection;




@class BXEmulator;

@interface BXInputHandler : NSObject
{
	BXEmulator *emulator;
	BOOL mouseActive;
	NSPoint mousePosition;
	
	BOOL capsLockEnabled;
	BOOL numLockEnabled;
	
	NSUInteger pressedMouseButtons;
	
	BXDOSJoystickType joystickType;
}

#pragma mark -
#pragma mark Properties

//Our parent emulator.
@property (assign) BXEmulator *emulator;

//Whether we are responding to mouse input.
@property (assign) BOOL mouseActive;

//What kind of joystick to emulate. Defaults to BXDOSJoystickTypeNone.
@property (assign) BXDOSJoystickType joystickType;

//Where DOSBox thinks the mouse is.
@property (assign) NSPoint mousePosition;

//A bitmask of which mouse buttons are currently pressed in DOS.
@property (readonly, assign) NSUInteger pressedMouseButtons;

//Whether these key states should be active at the start of the DOS session.
@property (assign) BOOL capsLockEnabled;
@property (assign) BOOL numLockEnabled;


//Releases all keyboard buttons/mouse buttons
- (void) releaseKeyboardInput;
- (void) releaseMouseInput;
- (void) releaseJoystickInput;


#pragma mark -
#pragma mark Joystick input

- (void) joystickButtonPressed: (BXDOSJoystickButton)button;
- (void) joystickButtonReleased: (BXDOSJoystickButton)button;

- (void) joystickAxisChanged: (BXDOSJoystickAxis)axis toPosition: (float)position;
- (void) joystickAxisChanged: (BXDOSJoystickAxis)axis byAmount: (float)delta;

- (void) joystickPOVSwitchChangedToDirection: (BXDOSFlightstickPOVDirection)direction;


#pragma mark -
#pragma mark Mouse input

//Press/release the specified mouse button, with the specified modifiers.
- (void) mouseButtonPressed: (BXMouseButton)button withModifiers: (NSUInteger)modifierFlags;
- (void) mouseButtonReleased: (BXMouseButton)button withModifiers: (NSUInteger) modifierFlags;

//Press the specified mouse button and then release it a moment later, with the specified modifiers.
//Note that the release event will be delayed slightly to give it time to register in DOS.
- (void) mouseButtonClicked: (BXMouseButton)button
			  withModifiers: (NSUInteger)modifierFlags;

//Move the mouse to a relative point on the specified canvas, by the relative delta.
- (void) mouseMovedToPoint: (NSPoint)point
				  byAmount: (NSPoint)delta
				  onCanvas:	(NSRect)canvas
			   whileLocked: (BOOL)locked;


#pragma mark -
#pragma mark Keyboard input

//Sends a key up/down event with the specified parameters to DOSBox.
- (void) sendKeyEventWithCode: (unsigned short)keyCode
					  pressed: (BOOL)pressed
					modifiers: (NSUInteger)modifierFlags;

//Sends a keydown followed by a keyup event for the specified OS X keycode
//and the specified modifiers. Note that the keyup event will be delayed slightly
//to give it time to register in DOS.
- (void) sendKeypressWithCode: (unsigned short)keyCode
					modifiers: (NSUInteger)modifierFlags;

//Sends a keyup and a keydown event for the specified SDL keycode and the specified modifiers.
//Allows SDL keys that have no OS X keycode equivalent to be triggered in DOS.
- (void) sendKeyEventWithSDLKey: (SDLKey)sdlKeyCode
						pressed: (BOOL)pressed
					  modifiers: (NSUInteger)modifierFlags;

- (void) sendKeypressWithSDLKey: (SDLKey)sdlKeyCode
					  modifiers: (NSUInteger)modifierFlags;



#pragma mark -
#pragma mark Keyboard layout mapping

//Returns the DOS keyboard layout code for the currently-active input method in OS X.
//Returns [BXInputHandler defaultKeyboardLayout] if no suitable layout could be found.
- (NSString *)keyboardLayoutForCurrentInputMethod;

//Returns the DOS keyboard layout code for the specified input source ID,
//or nil if no suitable layout could be found.
+ (NSString *) keyboardLayoutForInputSourceID: (NSString *)inputSourceID;

//Returns a dictionary mapping OS X InputServices input method names to DOS keyboard layout codes. 
+ (NSDictionary *)keyboardLayoutMappings;

//The default DOS keyboard layout that should be used if no more specific one can be found.
+ (NSString *)defaultKeyboardLayout;

@end
