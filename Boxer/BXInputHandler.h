/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXInputHandler converts input from OS X into DOSBox input commands. It expects OS X key and
//modifier constants, but does not accept NSEvents or interact with the OS X event framework:
//instead, it uses abstract methods to receive 'predigested' input data from BXInputController.

#import <Foundation/Foundation.h>
#import <SDL/SDL.h>


@class BXEmulator;

@interface BXInputHandler : NSObject
{
	BXEmulator *emulator;
	BOOL mouseActive;
	NSPoint mousePosition;
	
	BOOL capsLockEnabled;
	BOOL numLockEnabled;
	
	NSUInteger pressedMouseButtons;
}
//Our parent emulator.
@property (assign) BXEmulator *emulator;

//Whether we are responding to mouse input.
@property (assign) BOOL mouseActive;

//Where DOSBox thinks the mouse is.
@property (assign) NSPoint mousePosition;

//A bitmask of which mouse buttons are currently pressed in DOS.
@property (readonly, assign) NSUInteger pressedMouseButtons;

//Whether these key states should be active at the start of the DOS session.
@property (assign) BOOL capsLockEnabled;
@property (assign) BOOL numLockEnabled;


//Called whenever we lose keyboard input focus. Clears all DOSBox events.
- (void) lostFocus;

//Press/release the specified mouse button, with the specified modifiers.
- (void) mouseButtonPressed: (NSInteger)button withModifiers: (NSUInteger)modifierFlags;
- (void) mouseButtonReleased: (NSInteger)button withModifiers: (NSUInteger) modifierFlags;

//Move the mouse to a relative point on the specified canvas, by the relative delta.
- (void) mouseMovedToPoint: (NSPoint)point
				  byAmount: (NSPoint)delta
				  onCanvas:	(NSRect)canvas
			   whileLocked: (BOOL)locked;

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

//Returns the current state of capslock for DOSBox.
- (BOOL) capsLockEnabled;

@end
