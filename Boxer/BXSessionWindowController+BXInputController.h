/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXInputController is a category of BXSessionWindowController that manages event handling,
//window activity and the grabbing/releasing of user input.
//Currently most of its functionality gets posted straight to SDL-land, but in the near future
//this category will handle it all itself.

#import <Cocoa/Cocoa.h>
#import "BXSessionWindowController.h"

@interface BXSessionWindowController (BXInputController)

//Mouse locking
//-------------

//Set/retrieve whether the mouse is locked to the DOS viewport.
- (void) setMouseLocked: (BOOL) lock;
- (BOOL) mouseLocked;

//Notification observers
//----------------------

//These listen for any time an NSMenu opens or closes, and warn the active emulator
//to pause or resume emulation. In practice this means muting it to avoid hanging
//music and sound effects while the menu is blocking the thread.
//TODO: BXEmulator itself should handle this at a lower level by watching out for
//whenever a new event loop gets created.
- (void) menuDidOpen:	(NSNotification *) notification;
- (void) menuDidClose:	(NSNotification *) notification;

//Responding to SDL's entreaties
//------------------------------
- (NSOpenGLView *) SDLView;
- (NSWindow *) SDLWindow;

- (BOOL) handleSDLKeyboardEvent: (NSEvent *)event;
- (BOOL) handleSDLMouseMovement: (NSEvent *)event;

@end