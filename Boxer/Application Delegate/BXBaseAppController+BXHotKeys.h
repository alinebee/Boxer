/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXBaseAppController.h"
#import "BXKeyboardEventTap.h"


/// Extensions for handling system hotkey events and displaying a startup warning if hotkeys cannot be captured.
@interface BXBaseAppController (BXHotKeys) <BXKeyboardEventTapDelegate>

#pragma mark - Capturing and responding to hotkeys

/// Creates and installs the app controller's hotkey suppression tap, binding it to the user defaults so that
/// it can be dynamically enabled/disabled. Called automatically during application startup.
- (void) prepareHotkeyTap;

/// Checks whether the event tap is tapping at 'full strength': if not, attempts to reestablish the tap.
/// Called automatically whenever Boxer regains the application focus, in case the user has given Boxer more
/// accessibility permissions.
- (void) checkHotkeyCaptureAvailability;

/// Receives media key events received by the application and dispatches them to the current session.
- (void) mediaKeyPressed: (NSEvent *)theEvent;


#pragma mark - Bleating about not being able to capture hotkeys

/// Returns whether Boxer's hotkey suppression tap is currently installed.
/// This will be NO if Boxer does not have permission to install its keyboard event tap.
/// @note This property is KVO-observable and will update whenever Boxer becomes the active application.
@property (readonly, nonatomic) BOOL canCaptureHotkeys;

/// This will be set to YES if Boxer needs to be restarted in order for expanded accessibility permissions to take effect.
/// @note This property is KVO-observable, and will update whenever Boxer attempts to establish an event tap.
@property (readonly, nonatomic) BOOL needsRestartForHotkeyCapture;

/// Whether the application should warn the user at startup. This will be YES if:
/// the application does not have permission to capture events,
/// the application has been flagged to care about hotkeys (always true for Boxer, optional for standalone apps), and
/// the user has not already skipped a similar warning in the past.
@property (readonly, nonatomic) BOOL shouldShowHotkeyWarning;

/// Set to YES to prevent the hotkey warning from being displayed in future, even when appropriate.
/// @note There are separate hotkey warnings for different versions of OS X: this property only affects
/// the suppression flag for the current OS X version.
@property (assign, nonatomic) BOOL hotkeyWarningSuppressed;

/// Whether this OS X version uses global accessibility controls (10.8 and below) or per-app accessibility controls
/// (10.9 and above.) This is used for varying the accessibility instructions we give to the user to enable our hotkey capture.
+ (BOOL) hasPerAppAccessibilityControls;

/// The localized name of the System Preferences pane that contains the accessibility controls for the current OS X version.
/// Intended for use in UIs explaining to the user where to find the relevant controls.
+ (NSString *) localizedSystemAccessibilityPreferencesName;

/// If Boxer is prevented from installing its keyboard event tap, this will displays an alert
/// asking the user to give Boxer permission to do so with a button to open the appropriate System Preferences pane.
- (IBAction) showHotkeyWarningIfUnavailable: (id)sender;

/// Opens the appropriate System Preferences pane from which the user can give Boxer permission to install its hotkey event tap.
/// @note In OS X 10.8 and below, this is the Accessibility preferences; in 10.9 this moved to the Security & Privacy preferences.
- (IBAction) showSystemAccessibilityControls: (id)sender;

/// Constructs and returns a hotkey warning that will be displayed if the application cannot capture hotkeys.
/// Used by @c showHotkeyWarningIfUnavailable:.
- (NSAlert *) hotkeyWarningAlert;



@end
