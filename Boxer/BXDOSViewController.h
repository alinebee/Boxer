/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXDOSViewController class description goes here.

#import <Cocoa/Cocoa.h>

@class BXSessionWindowController;
@class BXEmulator;
@class BXCursorFadeAnimation;

@interface BXDOSViewController : NSViewController
{	
	BXCursorFadeAnimation *cursorFade;
	
	BOOL mouseActive;
	BOOL mouseLocked;
	
	NSPoint lastMousePosition;
	BOOL discardNextMouseDelta;
	
	IBOutlet BXSessionWindowController *windowController;
}

//Whether the mouse is in use by the DOS program. Set programmatically to match the emulator.
@property (assign) BOOL mouseActive;
//Set/get whether the mouse is locked to the DOS view.
@property (assign) BOOL mouseLocked;

@property (assign) BXSessionWindowController *windowController;

//Returns whether the specified cursor animation should continue.
- (BOOL) animationShouldChangeCursor: (BXCursorFadeAnimation *)cursorAnimation;

//Returns whether the mouse is currently within our view.
- (BOOL) mouseInView;

//Returns the emulator for the session we belong to.
- (BXEmulator *) emulator;

//Called by BXSessionWindowController whenever the view loses keyboard focus.
- (void) didResignKey;

//Lock/unlock the mouse.
- (IBAction) toggleMouseLocked: (id)sender;

//Warp the OS X cursor to the specified point on our virtual mouse canvas.
//Used when locking and unlocking the mouse.
- (void) _syncOSXCursorToPointInCanvas: (NSPoint)point;

//Does the fiddly internal work of locking/unlocking the mouse.
- (void) _applyMouseLockState;

//Returns whether we should have control of the mouse cursor state.
- (BOOL) _controlsCursor;
@end