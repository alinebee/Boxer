/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXInputController processes keyboard and mouse events received by its view and turns them
//into input commands to the emulator's own input handler (which for convenience is set as the
//controller's representedObject).
//It also manages mouse locking and the appearance and behaviour of the OS X mouse cursor.

#import <Cocoa/Cocoa.h>

@class BXCursorFadeAnimation;
@class BXDOSWindowController;
@class BXSession;

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
	NSTimeInterval threeFingerTapStarted;
	
	NSUInteger lastModifiers;
	
	NSMutableDictionary *lastJoystickValues;
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

//Whether we can currently lock the mouse. This will be YES if the game supports mouse control
//or we're in fullscreen mode (so that we can hide the mouse cursor), NO otherwise.
@property (readonly) BOOL canLockMouse;

//Whether the mouse is currently within our view.
@property (readonly) BOOL mouseInView;

#pragma mark -
#pragma mark Methods

//Overridden to declare the class expected for our represented object
- (BXSession *)representedObject;
- (void) setRepresentedObject: (BXSession *)session;

//Returns whether the specified cursor animation should continue.
//Called by our cursor animation as a delegate method.
- (BOOL) animationShouldChangeCursor: (BXCursorFadeAnimation *)cursorAnimation;


//Called by BXDOSWindowController whenever the view loses keyboard focus.
- (void) didResignKey;

//Called by BXDOSWindowController whenever the view regains keyboard focus.
- (void) didBecomeKey;


#pragma mark -
#pragma mark UI actions

//Lock/unlock the mouse.
- (IBAction) toggleMouseLocked: (id)sender;

//Enable/disable unlocked mouse tracking.
- (IBAction) toggleTrackMouseWhileUnlocked: (id)sender;


@end
