/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
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
@class BXInputHandler;

@interface BXInputController : NSViewController
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
< NSAnimationDelegate >
#endif
{	
	BXCursorFadeAnimation *cursorFade;
	
	BOOL mouseActive;
	BOOL mouseLocked;
	BOOL trackMouseWhileUnlocked;
	CGFloat mouseSensitivity;
	
	//Used internally for constraining mouse location and movement
	NSRect cursorWarpDeadzone;
	NSRect canvasBounds;
	NSRect visibleCanvasBounds;
	
	//Used internally for tracking mouse state between events
	NSPoint distanceWarped;
	BOOL updatingMousePosition;
	NSUInteger simulatedMouseButtons;
}

#pragma mark -
#pragma mark Properties

//Whether the mouse is in use by the DOS program. Set programmatically to match the emulator.
@property (assign) BOOL mouseActive;

//Whether the mouse is locked to the DOS view.
@property (assign) BOOL mouseLocked;

//Whether we should handle mouse movement while the mouse is unlocked from the DOS view.
@property (assign) BOOL trackMouseWhileUnlocked;

//How much to scale mouse motion by.
@property (assign) CGFloat mouseSensitivity;

#pragma mark -
#pragma mark Methods

//Overridden to specify the class expected for our represented object
- (void) setRepresentedObject: (BXInputHandler *)representedObject;

//Returns whether the specified cursor animation should continue.
//Called by our cursor animation as a delegate method.
- (BOOL) animationShouldChangeCursor: (BXCursorFadeAnimation *)cursorAnimation;

//Returns whether the mouse is currently within our view.
- (BOOL) mouseInView;

//Called by BXDOSWindowController whenever the view loses keyboard focus.
- (void) didResignKey;

//Lock/unlock the mouse.
- (IBAction) toggleMouseLocked: (id)sender;

//Enable/disable unlocked mouse tracking.
- (IBAction) toggleTrackMouseWhileUnlocked: (id)sender;


#pragma mark -
#pragma mark Simulating keypresses

- (IBAction) sendEnter: (id)sender;
- (IBAction) sendF1:	(id)sender;
- (IBAction) sendF2:	(id)sender;
- (IBAction) sendF3:	(id)sender;
- (IBAction) sendF4:	(id)sender;
- (IBAction) sendF5:	(id)sender;
- (IBAction) sendF6:	(id)sender;
- (IBAction) sendF7:	(id)sender;
- (IBAction) sendF8:	(id)sender;
- (IBAction) sendF9:	(id)sender;
- (IBAction) sendF10:	(id)sender;

@end
