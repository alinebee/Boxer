/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//Private method declarations for BXInputController and its categories to share.

#import "BXInputController.h"
#import "BXInputController+BXKeyboardInput.h"
#import "BXInputController+BXJoystickInput.h"
#import "BXInputController+BXJoypadInput.h"

#import "BXEmulator.h"
#import "BXEmulatedKeyboard.h"
#import "BXEmulatedJoystick.h"
#import "BXEmulatedMouse.h"

#import "BXSession+BXUIControls.h"
#import "BXDOSWindowController.h"


#pragma mark -
#pragma mark Constants for configuring behaviour

//The number of seconds it takes for the cursor to fade out after entering the window.
//Cursor animation is flickery so a small duration helps mask this.
#define BXCursorFadeDuration 0.4

//The framerate at which to animate the cursor fade.
//15fps is as fast as is really noticeable.
#define BXCursorFadeFrameRate 15.0f

//If the cursor is warped less than this distance (relative to a 0.0->1.0 square canvas) then
//the OS X cursor will not be warped to match. Because OS X cursor warping introduces a slight
//input delay, we use this tolerance to ignore small warps.
#define BXCursorWarpTolerance 0.1f

//The volume level at which we'll play the lock/unlock sound effects.
#define BXMouseLockSoundVolume 0.7f

//The maximum length a touch-then-release can last in order to be considered a tap.
#define BXTapDurationThreshold 0.3f


@interface BXInputController ()

#pragma mark -
#pragma mark Internal properties

//Make the available types internally modifiable
@property (readwrite, retain, nonatomic) NSArray *availableJoystickTypes;

@property (retain, nonatomic) BXCursorFadeAnimation *cursorFade;
@property (retain, nonatomic) NSMutableDictionary *controllerProfiles;

#pragma mark -
#pragma mark Convenience accessors

@property (readonly, nonatomic) BXDOSWindowController *windowController;
@property (readonly, nonatomic) BXEmulatedKeyboard *emulatedKeyboard;
@property (readonly, nonatomic) BXEmulatedMouse *emulatedMouse;
@property (readonly, nonatomic) id <BXEmulatedJoystick> emulatedJoystick;


#pragma mark -
#pragma mark Methods

//Called when the active keyboard input source changes in OS X.
//Used to sync the DOS keyboard layout accordingly.
void _inputSourceChanged(CFNotificationCenterRef center,
                         void *observer,
                         CFStringRef name,
                         const void *object,
                         CFDictionaryRef userInfo);

//Resynchronises the current simulated mouse button state whenever the current modifier flags change.
- (void) _syncSimulatedMouseButtons: (NSUInteger)currentModifiers;

//Returns whether we should have control of the mouse cursor state.
//This is true if the mouse is within the view, the window is key,
//mouse input is in use by the DOS program, and the mouse is either
//locked or we track the mouse while it's unlocked.
- (BOOL) _controlsCursor;

//A quicker version of the above for when we already know/don't care
//if the mouse is inside the view.
- (BOOL) _controlsCursorWhileMouseInside;

//Converts a 0.0-1.0 relative canvas offset to a point on screen.
- (NSPoint) _pointOnScreen: (NSPoint)canvasPoint;

//Converts a point on screen to a 0.0-1.0 relative canvas offset.
- (NSPoint) _pointInCanvas: (NSPoint)screenPoint;

//Performs the fiddly internal work of locking/unlocking the mouse.
- (void) _applyMouseLockState: (BOOL)lock;

//Responds to the emulator moving the mouse cursor,
//either in response to our own signals or of its own accord.
- (void) _emulatedCursorMovedToPointInCanvas: (NSPoint)point;

//Warps the OS X cursor to the specified point on our virtual mouse canvas.
//Used when locking and unlocking the mouse and when DOS warps the mouse.
- (void) _syncOSXCursorToPointInCanvas: (NSPoint)point;

//Warps the DOS cursor to the specified point on our virtual mouse canvas.
//Used when unlocking the mouse while unlocked mouse tracking is disabled,
//to remove any latent mouse input from a leftover mouse position.
- (void) _syncEmulatedCursorToPointInCanvas: (NSPoint)pointInCanvas;

@end


@interface BXInputController (BXJoystickInputInternals)

//Resynchronises the DOS emulated joystick type based on currently-connected joystick devices.
- (void) _syncJoystickType;

//Resynchronises the available joystick types to choose from based on the emulated game's
//current level of joystick support.
- (void) _syncAvailableJoystickTypes;

//Recreate HID controller profiles whenever the available controllers change or the emulated game's joystick changes.
- (void) _syncControllerProfiles;

//Returns whether the event represents a deliberate user action rather than 'noise' from the device.
+ (BOOL) HIDEventIsDeliberate: (BXHIDEvent *)event;

//Whether the active emulated program seems to be ignoring gameport input.
- (BOOL) _activeProgramIsIgnoringJoystick;

@end


@interface BXInputController (BXKeyboardInputInternals)

//Resynchronises the DOS keyboard layout with the current OS X text-input source.
- (void) _syncKeyboardLayout;

//Resynchronises the current state of the Shift, Ctrl, Alt, CapsLock etc.
//key, which are represented by event modifier flags.
- (void) _syncModifierFlags: (NSUInteger)newModifiers;

//Returns the DOS keycode constant corresponding to the specified OSX keycode.
- (BXDOSKeyCode) _DOSKeyCodeForSystemKeyCode: (CGKeyCode)keyCode;

//Returns the DOS keycode constant that should be simulated when the specified
//OSX keycode is pressed along with the Fn key.
- (BXDOSKeyCode) _simulatedNumpadKeyCodeForSystemKeyCode: (CGKeyCode)keyCode;

//Called whenever the emulated keyboard's numlock state changes.
//Displays a notification bezel indicating the current state.
- (void) _notifyNumlockState;

@end


@interface BXInputController (BXJoypadInputInternals)

+ (BXEmulatedJoystickButton) emulatedJoystickButtonForJoypadButton: (JoyInputIdentifier)button;
+ (BXEmulatedPOVDirection) emulatedJoystickPOVDirectionForDPadState: (NSUInteger)state;

//Called whenever a Joypad disconnects/reconnects to reset internal tracking values.
- (void) _resetJoypadTrackingValues;

//Show a warning to the user if the game seems to be ignoring joystick input.
//Called internally if Joypad input is received while the joystick is inactive.
- (void) _warnIfJoystickInactive;

@end
