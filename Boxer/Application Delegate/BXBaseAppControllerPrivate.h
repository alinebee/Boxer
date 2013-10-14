/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXBaseAppController.h"
#import "BXBaseAppController+BXSupportFiles.h"
#import "BXBaseAppController+BXHotKeys.h"

/// Private API for BXAppController which should only be accessed by subclasses.
@interface BXBaseAppController ()

/// A block to run once the application has finished terminating. Used by @c -terminateWithHandler:.
@property (copy, nonatomic) void(^postTerminationHandler)();

/// Captures incoming hotkey and media key events, to allow Boxer to make use of play/pause/fast-forward keys
/// and to prevent conflicting OS X hotkeys from interfering with DOS games.
@property (retain, nonatomic) BXKeyboardEventTap *hotkeySuppressionTap;

/// Used by @c BXBaseAppController+BXHotkeys to track whether we are currently displaying our hotkey warning,
/// so it can be programmatically dismissed under certain circumstances.
@property (retain, nonatomic) NSAlert *activeHotkeyAlert;

//Redeclared to be writable
@property (assign, nonatomic) BOOL needsRestartForHotkeyCapture;

//Redeclared to be writable
@property (readwrite, retain) NSOperationQueue *generalQueue;


#pragma mark - Initialization

/// Load/create the user defaults for the application. Called from +initialize.
+ (void) prepareUserDefaults;

/// Create common value transformers used throughout the application. Called from +initialize.
+ (void) prepareValueTransformers;


#pragma mark - Responding to changes in application mode

/// Set the application UI to the appropriate mode for the current session's
/// fullscreen and mouse-locked status. Called in response to relevant changes in application state.
- (void) syncApplicationPresentationMode;

/// Registers the application delegate to receive notifications about application mode changes.
- (void) registerApplicationModeObservers;

/// Called whenever a Boxer session releases the mouse.
- (void) sessionDidUnlockMouse: (NSNotification *)notification;

/// Called whenever a Boxer session locks the mouse to its window.
- (void) sessionDidLockMouse: (NSNotification *)notification;

/// Called when a Boxer session is about to enter fullscreen mode.
- (void) sessionWillEnterFullScreenMode: (NSNotification *)notification;

/// Called when a Boxer session has finished entering fullscreen mode.
- (void) sessionDidEnterFullScreenMode: (NSNotification *)notification;

/// Called when a Boxer session is about to exit fullscreen mode.
- (void) sessionWillExitFullScreenMode: (NSNotification *)notification;

/// Called when a Boxer session has finished exiting fullscreen mode.
- (void) sessionDidExitFullScreenMode: (NSNotification *)notification;


#pragma mark - Application lifecycle

/// Attempts to terminate the application, calling the specified termination handler if termination is successful.
/// This is intended for use by @c BXBaseAppController subclasses in order to restart the app or launch a secondary Boxer process.
/// @param postTerminationHandler   The block to execute once the app is ready to terminate.
///                                 This will only be executed if the app really will terminate;
///                                 if the user cancels termination, the handler will be discarded unused.
- (void) terminateWithHandler: (void (^)())postTerminationHandler;


@end
