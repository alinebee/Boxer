/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXInspectorController manages the Boxer inspector panel. It is responsible for displaying and
//toggling the tabs of the panel.

#import "BXMultiPanelWindowController.h"

@class BXDriveList;

@interface BXInspectorController : BXMultiPanelWindowController
{
	IBOutlet NSView *gamePanel;
	IBOutlet NSView *cpuPanel;
	IBOutlet NSView *mousePanel;
	IBOutlet NSView *drivePanel;
	IBOutlet NSSegmentedControl *panelSelector;
}
@property (retain, nonatomic) NSView *gamePanel;		//The gamebox properties tab panel.
@property (retain, nonatomic) NSView *cpuPanel;			//The CPU emulation settings tab panel.
@property (retain, nonatomic) NSView *mousePanel;		//The mouse settings tab panel.
@property (retain, nonatomic) NSView *drivePanel;		//The drive list panel.

//The segmented tab selector button at the top of the inspector.
@property (retain, nonatomic) NSSegmentedControl *panelSelector;
//The array of tab panels, in the same order as panelSelector's tabs
@property (readonly, nonatomic) NSArray *panels;	


//A singleton instance of the inspector controller, which is shared by all session windows.
//The controller should always be accessed through this method.
+ (BXInspectorController *) controller;


- (IBAction) showGameInspectorPanel:	(id)sender;	//Display the gamebox panel.
- (IBAction) showCPUInspectorPanel:		(id)sender;	//Display the CPU panel.
- (IBAction) showDriveInspectorPanel:	(id)sender;	//Display the drive list panel.
- (IBAction) showMouseInspectorPanel:	(id)sender;	//Display the mouse panel.

//Display the tab panel corresponding to the selected tab segment in the sender.
- (IBAction) selectInspectorPanel:		(NSSegmentedControl *)sender;

@end
