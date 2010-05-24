/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXInputController processes keyboard and mouse events received by its view and turns them
//into input commands to the emulator's own input handler (which for convenience is set as the
//controller's representedObject).
//It also manages mouse locking and the appearance and behaviour of the OS X mouse cursor.

#import <Cocoa/Cocoa.h>

@class BXCursorFadeAnimation;

@interface BXInputController : NSViewController
{	
	BXCursorFadeAnimation *cursorFade;
	
	BOOL mouseActive;
	BOOL mouseLocked;
	
	NSPoint lastMousePosition;
	BOOL discardNextMouseDelta;
	NSUInteger simulatedMouseButtons;
}

#pragma mark -
#pragma mark Properties

//Whether the mouse is in use by the DOS program. Set programmatically to match the emulator.
@property (assign) BOOL mouseActive;

//Set/get whether the mouse is locked to the DOS view.
@property (assign) BOOL mouseLocked;


#pragma mark -
#pragma mark Methods

//Returns whether the specified cursor animation should continue.
//Called by our cursor animation as a delegate method.
- (BOOL) animationShouldChangeCursor: (BXCursorFadeAnimation *)cursorAnimation;

//Returns whether the mouse is currently within our view.
- (BOOL) mouseInView;

//Called by BXSessionWindowController whenever the view loses keyboard focus.
- (void) didResignKey;

//Lock/unlock the mouse.
- (IBAction) toggleMouseLocked: (id)sender;

@end