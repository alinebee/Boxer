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
#import "BXEventConstants.h"


@class BXEmulator;

@interface BXInputHandler : NSObject
{
	BXEmulator *emulator;
	BOOL mouseActive;
	NSPoint mousePosition;
	
	NSUInteger pressedMouseButtons;
}

#pragma mark -
#pragma mark Properties

//Our parent emulator.
@property (assign) BXEmulator *emulator;

//Whether we are responding to mouse input.
@property (assign) BOOL mouseActive;

//Where DOSBox thinks the mouse is.
@property (assign) NSPoint mousePosition;

//A bitmask of which mouse buttons are currently pressed in DOS.
@property (readonly, assign) NSUInteger pressedMouseButtons;


//Releases all keyboard buttons/mouse buttons
- (void) releaseMouseInput;


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

@end
