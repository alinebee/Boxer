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

@interface BXEmulatorEventResponder : NSResponder

- (void) mouseMovedToPoint: (NSPoint)point
				  byAmount: (NSPoint)delta
				  onCanvas:	(NSRect)canvas
			   whileLocked: (BOOL)locked;

@end


#if __cplusplus
//Hide SDL nastiness from Objective C classes

#import <SDL/SDL.h>

@interface BXEmulatorEventResponder (BXEmulatorEventResponderInternals)

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