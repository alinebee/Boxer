/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Cocoa/Cocoa.h>
#import "BXEventConstants.h"

@class BXCursorFadeAnimation;
@class BXDOSWindowController;
@class BXSession;
@class DDHidJoystick;

/// BXInputController processes keyboard and mouse events received by its view and turns them
/// into input commands to the emulator's own input handler (which for convenience is set as the
/// controller's representedObject).
/// It also manages mouse locking and the appearance and behaviour of the OS X mouse cursor.
@interface BXInputController : NSViewController <NSAnimationDelegate>
{
	BXCursorFadeAnimation *_cursorFade;
	
    BOOL _simulatedNumpadActive;
	BOOL _mouseActive;
	BOOL _mouseLocked;
	BOOL _trackMouseWhileUnlocked;
	CGFloat _mouseSensitivity;
	
	/// Used internally for constraining mouse location and movement
	NSRect _cursorWarpDeadzone;
	NSRect _canvasBounds;
	NSRect _visibleCanvasBounds;
	
	/// Used internally for tracking mouse state between events
	NSPoint _distanceWarped;
	BOOL _updatingMousePosition;
	NSTimeInterval _threeFingerTapStarted;
    
	BXMouseButtonMask _simulatedMouseButtons;
    
    /// Which OSX virtual keycodes were pressed with a modifier, causing
    /// them to send a different key than usual. Used for releasing
    /// simulated keys upon key-up.
    BOOL _modifiedKeys[BXMaxSystemKeyCode];
    
	NSUInteger _lastModifiers;
	
	NSMutableDictionary *_controllerProfiles;
	NSArray *_availableJoystickTypes;
}

#pragma mark -
#pragma mark Properties

/// Whether the mouse is in use by the DOS program. Set programmatically to match the emulator.
@property (assign, nonatomic) BOOL mouseActive;

/// Whether the mouse is locked to the DOS view.
@property (assign, nonatomic) BOOL mouseLocked;

/// Whether we should handle mouse movement while the mouse is unlocked from the DOS view.
@property (assign, nonatomic) BOOL trackMouseWhileUnlocked;

/// How much to scale mouse motion by.
@property (assign, nonatomic) CGFloat mouseSensitivity;

/// Whether we can currently lock the mouse. This will be YES if the game supports mouse control
/// or we're in fullscreen mode (so that we can hide the mouse cursor), NO otherwise.
@property (readonly, nonatomic) BOOL canLockMouse;

/// Whether the mouse is currently within our view.
@property (readonly, nonatomic) BOOL mouseInView;

/// Whether numpad simulation is turned on. When active, certain keys will be remapped to imitate
/// the numeric keypad on a fullsize PC keyboard.
@property (assign, nonatomic) BOOL simulatedNumpadActive;

#pragma mark -
#pragma mark Methods

/// Overridden to declare the class expected for our represented object
- (BXSession *)representedObject;
- (void) setRepresentedObject: (BXSession *)session;

/// Returns whether the specified cursor animation should continue.
/// Called by our cursor animation as a delegate method.
- (BOOL) animationShouldChangeCursor: (BXCursorFadeAnimation *)cursorAnimation;

/// Called when the cursor needs updating outside of the standard NSResponder event mechanisms.
- (void) syncCursor;

/// Called by \c BXDOSWindowController whenever the view loses keyboard focus.
- (void) didResignKey;

/// Called by \c BXDOSWindowController whenever the view regains keyboard focus.
- (void) didBecomeKey;

/// Applies the specified mouse-lock state.
/// If force is NO, the mouse will not be locked if canLockMouse returns NO.
/// If force is YES, it will be locked regardless.
- (void) setMouseLocked: (BOOL)locked
                  force: (BOOL)force;

#pragma mark -
#pragma mark UI actions

/// Lock/unlock the mouse. Only available while a program is running.
- (IBAction) toggleMouseLocked: (id)sender;

/// Enable/disable unlocked mouse tracking.
- (IBAction) toggleTrackMouseWhileUnlocked: (id)sender;

/// Enable/disable the simulated numpad layout. Only available while a program is running.
- (IBAction) toggleSimulatedNumpad: (id)sender;

@end
