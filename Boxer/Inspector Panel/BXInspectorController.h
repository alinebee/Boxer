/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXInspectorController manages the Boxer inspector panel. It is responsible for displaying and
//toggling the tabs of the panel.

#import "BXTabbedWindowController.h"

enum {
	BXGameInspectorPanelTag		= 0,
	BXCPUInspectorPanelTag		= 1,
	BXMouseInspectorPanelTag	= 2,
	BXDriveInspectorPanelTag	= 3,
	BXJoystickInspectorPanelTag	= 4
};


@class BXDriveList;

@interface BXInspectorController : BXTabbedWindowController
{
	IBOutlet NSSegmentedControl *panelSelector;
	BOOL isTemporarilyHidden;
}

//The segmented tab selector button at the top of the inspector.
@property (retain, nonatomic) NSSegmentedControl *panelSelector;

//Whether the inspector panel is currently visible.
@property (assign, nonatomic) BOOL panelShown;

//A singleton instance of the inspector controller, which is shared by all session windows.
//The controller should always be accessed through this method.
+ (BXInspectorController *) controller;

//Select the specified panel and reveal the window.
- (IBAction) showGamePanel:		(id)sender;
- (IBAction) showCPUPanel:		(id)sender;
- (IBAction) showDrivesPanel:	(id)sender;
- (IBAction) showMousePanel:	(id)sender;
- (IBAction) showJoystickPanel:	(id)sender;

//Show help pages for the various panels
- (IBAction) showGamePanelHelp: (id)sender;
- (IBAction) showCPUPanelHelp: (id)sender;
- (IBAction) showMousePanelHelp: (id)sender;
- (IBAction) showDrivesPanelHelp: (id)sender;
- (IBAction) showJoystickPanelHelp: (id)sender;
- (IBAction) showInactiveJoystickPanelHelp: (id)sender;

//Temporarily hides the panel if it is currently visible:
//It can then be unhidden with revealIfHidden.
//This is used to temporarily suppress the inspector panel while the mouse is locked.
- (void) hideIfVisible;
- (void) revealIfHidden;

@end
