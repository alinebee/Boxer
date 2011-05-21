/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//Private method declarations for BXInputController and its categories to share.

#import "BXInputController.h"
#import "BXInputController+BXKeyboardInput.h"
#import "BXInputController+BXJoystickInput.h"

#import "BXEmulator.h"
#import "BXEmulatedKeyboard.h"
#import "BXEmulatedJoystick.h"
#import "BXEmulatedMouse.h"

#import "BXSession.h"
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
#pragma mark Convenience accessors

@property (readonly) BXDOSWindowController *_windowController;
@property (readonly) BXEmulatedKeyboard *_emulatedKeyboard;
@property (readonly) BXEmulatedMouse *_emulatedMouse;
@property (readonly) id <BXEmulatedJoystick> _emulatedJoystick;


#pragma mark -
#pragma mark Methods


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


//Forces a cursor update whenever the window changes size. This works
//around a bug whereby the current cursor resets whenever the window
//resizes (presumably because the tracking areas are being recalculated)
- (BOOL) _windowDidResize: (NSNotification *)notification;

@end


@interface BXInputController (BXJoystickInputInternals)

//Resynchronises the DOS emulated joystick type based on currently-connected joystick devices.
- (void) _syncJoystickType;

//Processes a button-press/release.
- (void) _handleHIDJoystickButtonEvent: (BXHIDEvent *)event;

//Returns a normalized axis value to account for deadzones and unidirectional (trigger) inputs.
- (NSInteger) _normalizedAxisPositionForEvent: (BXHIDEvent *)event;

@end


@interface BXInputController (BXKeyboardInputInternals)

//Resynchronises the current state of the Shift, Ctrl, Alt, CapsLock etc.
//key, which are represented by event modifier flags.
- (void) _syncModifierFlags: (NSUInteger)newModifiers;

//Returns the DOS keycode constant corresponding to the specified OSX keycode.
+ (BXDOSKeyCode) _DOSKeyCodeForSystemKeyCode: (CGKeyCode)keyCode;

@end


//Some extension methods to NSDictionary to make it easier for us to record and retrieve
//controller values from our lastJoystickValues dictionary
@interface NSMutableDictionary (BXHIDElementValueRecording)

//Returns the dictionary key to be used for storing the specified element's value
- (id) keyForHIDElement: (DDHidElement *)element;

//Returns the stored value for the specified element, as an integer
- (NSInteger) integerValueForHIDElement: (DDHidElement *)element;

//Stores the specified value for the specified element, as an integer
- (void) setIntegerValue: (NSInteger)value forHIDElement: (DDHidElement *)element;
@end
