/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXInputHandler converts input from OS X into DOSBox input commands. It expects OS X key and
//modifier constants, but does not accept NSEvents or interact with the OS X event framework:
//instead, it uses abstract methods to receive 'predigested' input data from BXInputController.

#import <Foundation/Foundation.h>

@class BXEmulator;

@interface BXInputHandler : NSObject
{
	BXEmulator *emulator;
	BOOL mouseActive;
	NSPoint mousePosition;
	CGFloat mouseSensitivity;
}
//Our parent emulator.
@property (assign) BXEmulator *emulator;

//Whether we are responding to mouse input.
@property (assign) BOOL mouseActive;

//Where DOSBox thinks the mouse is.
@property (assign) NSPoint mousePosition;

//How much to scale mouse motion by.
@property (assign) CGFloat mouseSensitivity;


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
				withModifiers: (NSUInteger)modifierFlags;

//Sends a key up/down event with the specified code, using the current modifier flags.
- (void) sendKeyEventWithCode: (unsigned short)keyCode pressed: (BOOL)pressed;

//Sends a keyup and a keydown event for the specified code, using the current modifier flags.
- (void) sendKeypressWithCode: (unsigned short)keyCode;


//Returns the DOS keyboard layout code for the currently-active input method in OS X.
//Returns [BXInputHandler defaultKeyboardLayout] if no appropriate layout could be found.
- (NSString *)keyboardLayoutForCurrentInputMethod;

//Returns a dictionary mapping OSX InputServices input method names to DOS keyboard layout codes. 
+ (NSDictionary *)keyboardLayoutMappings;

//The default DOS keyboard layout that should be used if no more specific one can be found.
+ (NSString *)defaultKeyboardLayout;

//Returns the current state of capslock for DOSBox.
- (BOOL) capsLockEnabled;

@end
