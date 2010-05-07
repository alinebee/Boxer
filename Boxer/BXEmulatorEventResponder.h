/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXEmulatorEventResponder class description goes here.

#import <Cocoa/Cocoa.h>

enum {
	DOSBoxMouseButtonLeft	= 0,
	DOSBoxMouseButtonRight	= 1,
	DOSBoxMouseButtonMiddle	= 2
};

//Modifier flag constants for left- and right-side modifier keys, copied from IOKit/IOLLEvent.h.
//Allows us to distinguish these for DOSBox.
enum {
	BXLeftControlKeyMask	= 0x00000001,
	BXLeftShiftKeyMask		= 0x00000002,
	BXRightShiftKeyMask		= 0x00000004,
	BXLeftCommandKeyMask	= 0x00000008,
	BXRightCommandKeyMask	= 0x00000010,
	BXLeftAlternateKeyMask	= 0x00000020,
	BXRightAlternateKeyMask	= 0x00000040,
	BXRightControlKeyMask	= 0x00002000
};


@interface BXEmulatorEventResponder : NSResponder
{
	NSUInteger simulatedMouseButtons;
}

//Move the mouse to a relative point on the specified canvas, by the relative delta.
- (void) mouseMovedToPoint: (NSPoint)point
				  byAmount: (NSPoint)delta
				  onCanvas:	(NSRect)canvas
			   whileLocked: (BOOL)locked;

//Called whenever we lose keyboard input focus. Clears all DOSBox events.
- (void) lostFocus;

@end


#if __cplusplus
//Hide SDL nastiness from Objective C classes

#import <SDL/SDL.h>

@interface BXEmulatorEventResponder (BXEmulatorEventResponderInternals)

//Analoguous to [[NSApp currentEvent] modifierFlags], only for SDL-style modifiers.
- (SDLMod) currentSDLModifiers;

//Generates and returns an SDL key event with the specified parameters.
+ (SDL_Event) _SDLKeyEventForKeyCode: (CGKeyCode)keyCode
							 pressed: (BOOL)pressed
					   withModifiers: (NSUInteger)modifierFlags;

//Returns the SDL key constant corresponding to the specified OS X virtual keycode.
+ (SDLKey) _convertToSDLKeyCode: (CGKeyCode)keyCode;	
	
//Returns the appropriate SDL modifier bitmask for the specified NSEvent modifier flags.
+ (SDLMod) _convertToSDLModifiers: (NSUInteger)modifierFlags;

@end
#endif