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

#import "BXEmulatedKeyboard.h"
#import "BXEmulator.h"
#import "BXSession.h"
#import "BXDOSWindowController.h"


@interface BXInputController ()

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
- (void) _emulatorCursorMovedToPointInCanvas: (NSPoint)point;

//Warps the OS X cursor to the specified point on our virtual mouse canvas.
//Used when locking and unlocking the mouse and when DOS warps the mouse.
- (void) _syncOSXCursorToPointInCanvas: (NSPoint)point;

//Warps the DOS cursor to the specified point on our virtual mouse canvas.
//Used when unlocking the mouse while unlocked mouse tracking is disabled,
//to remove any latent mouse input from a leftover mouse position.
- (void) _syncDOSCursorToPointInCanvas: (NSPoint)pointInCanvas;


//Forces a cursor update whenever the window changes size. This works
//around a bug whereby the current cursor resets whenever the window
//resizes (presumably because the tracking areas are being recalculated)
- (BOOL) _windowDidResize: (NSNotification *)notification;

@end


@interface BXInputController (BXJoystickInputInternals)

//Resynchronises the DOS emulated joystick type based on currently-connected joystick devices.
- (void) _syncJoystickType;

@end


@interface BXInputController (BXKeyboardInputInternals)

//Return a reference to the emulated keyboard
- (BXEmulatedKeyboard *)_keyboard;

//Resynchronises the current state of the Shift, Ctrl, Alt, CapsLock etc.
//key, which are represented by event modifier flags.
- (void) _syncModifierFlags: (NSUInteger)newModifiers;

//Returns the DOS keycode constant corresponding to the specified OSX keycode
+ (BXDOSKeyCode) _DOSKeyCodeForSystemKeyCode: (CGKeyCode)keyCode;

@end
