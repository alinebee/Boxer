/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "ADBTabbedWindowController.h"

enum {
	BXGameInspectorPanelIndex		= 0,
	BXCPUInspectorPanelIndex        = 1,
	BXMouseInspectorPanelIndex      = 2,
	BXDriveInspectorPanelIndex      = 3,
	BXJoystickInspectorPanelIndex	= 4,
};


@class BXDriveList;

/// \c BXInspectorController manages the Boxer inspector panel. It is responsible for displaying and
/// toggling the tabs of the panel.
@interface BXInspectorController : ADBTabbedWindowController
{
	BOOL _isTemporarilyHidden;
}

/// Whether the inspector panel is currently visible.
@property (assign, nonatomic, getter=isVisible) BOOL visible;

/// A singleton instance of the inspector controller, which is shared by all session windows.
/// The controller should always be accessed through this method.
+ (BXInspectorController *) controller;

/// Select the specified panel and reveal the window.
- (IBAction) showGamePanel:		(id)sender;
- (IBAction) showCPUPanel:		(id)sender;
- (IBAction) showDrivesPanel:	(id)sender;
- (IBAction) showMousePanel:	(id)sender;
- (IBAction) showJoystickPanel:	(id)sender;

/// Show help pages for the various panels
- (IBAction) showGamePanelHelp: (id)sender;
- (IBAction) showCPUPanelHelp: (id)sender;
- (IBAction) showMousePanelHelp: (id)sender;
- (IBAction) showDrivesPanelHelp: (id)sender;
- (IBAction) showJoystickPanelHelp: (id)sender;
- (IBAction) showInactiveJoystickPanelHelp: (id)sender;

/// Temporarily hides the panel if it is currently visible:
/// It can then be unhidden with revealIfHidden.
/// This is used to temporarily suppress the inspector panel while the mouse is locked.
- (void) hideIfVisible;
- (void) revealIfHidden;

@end
