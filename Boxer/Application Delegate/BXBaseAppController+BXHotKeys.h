/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXBaseAppController.h"
#import "BXKeyboardEventTap.h"


#define BXMediaKeyEventSubtype 8

/// Extensions for handling system hotkey events.
@interface BXBaseAppController (BXHotKeys) <BXKeyboardEventTapDelegate>

/// Returns whether Boxer's hotkey suppression tap is currently installed.
/// This will be NO if Boxer does not have permission to install its keyboard event tap.
/// @note This property is KVO-observable and will update whenever Boxer becomes the active application.
@property (readonly, nonatomic) BOOL canCaptureHotkeys;

/// Whether this OS X version uses global accessibility controls (10.8 and below) or per-app accessibility controls
/// (10.9 and above.) This is used for varying the accessibility instructions we give to the user to enable our hotkey capture.
+ (BOOL) hasPerAppAccessibilityControls;

/// The localized name of the System Preferences pane that contains the accessibility controls for the current OS X version.
/// Intended for use in UIs explaining to the user where to find the relevant controls.
+ (NSString *) localizedSystemAccessibilityPreferencesName;

/// Receives media key events received by the application and dispatches them to the current session.
- (void) mediaKeyPressed: (NSEvent *)theEvent;

/// If Boxer is prevented from installing its keyboard event tap, this will displays an alert
/// asking the user to give Boxer permission to do so with a button to open the appropriate System Preferences pane.
- (void) showHotkeyWarningIfUnavailable;

/// Opens the appropriate System Preferences pane from which the user can give Boxer permission to install its hotkey event tap.
/// @note In OS X 10.8 and below, this is the Accessibility preferences; in 10.9 this moved to the Security & Privacy preferences.
- (void) showSystemAccessibilityControls;

@end
