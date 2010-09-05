/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXInspectorController manages the Boxer inspector panel. It is responsible for displaying and
//toggling the tabs of the panel.

#import "BXTabbedWindowController.h"

enum {
	BXGameInspectorPanelTag		= 0,
	BXCPUInspectorPanelTag		= 1,
	BXMouseInspectorPanelTag	= 2,
	BXDriveInspectorPanelTag	= 3
};


@class BXDriveList;

@interface BXInspectorController : BXTabbedWindowController
{
	IBOutlet NSSegmentedControl *panelSelector;
}

//The segmented tab selector button at the top of the inspector.
@property (retain, nonatomic) NSSegmentedControl *panelSelector;	

//A singleton instance of the inspector controller, which is shared by all session windows.
//The controller should always be accessed through this method.
+ (BXInspectorController *) controller;

- (IBAction) showGameInspectorPanel:	(id)sender;	//Display the gamebox panel.
- (IBAction) showCPUInspectorPanel:		(id)sender;	//Display the CPU panel.
- (IBAction) showDriveInspectorPanel:	(id)sender;	//Display the drive list panel.
- (IBAction) showMouseInspectorPanel:	(id)sender;	//Display the mouse panel.

@end
