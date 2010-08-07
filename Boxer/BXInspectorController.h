/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXInspectorController manages the Boxer inspector panel. It is responsible for displaying and
//toggling the tabs of the panel.

#import <Cocoa/Cocoa.h>

@class BXDriveList;

@interface BXInspectorController : NSWindowController
{
	IBOutlet NSView *panelContainer;
	IBOutlet NSView *gamePanel;
	IBOutlet NSView *cpuPanel;
	IBOutlet NSView *mousePanel;
	IBOutlet NSView *drivePanel;
	IBOutlet NSSegmentedControl *panelSelector;
}
@property (retain, nonatomic) NSView *panelContainer;	//The view into which the current panel will be added.
@property (retain, nonatomic) NSView *gamePanel;		//The gamebox properties tab panel.
@property (retain, nonatomic) NSView *cpuPanel;			//The CPU emulation settings tab panel.
@property (retain, nonatomic) NSView *mousePanel;		//The mouse settings tab panel.
@property (retain, nonatomic) NSView *drivePanel;		//The drive list panel.
@property (retain, nonatomic) NSSegmentedControl *panelSelector;	//The segmented tab selector button at the top of the inspector.

@property (assign, nonatomic) NSView *currentPanel;	//The currently-displayed panel.
@property (readonly, nonatomic) NSArray *panels;	//The array of tab panels, in the same order as panelSelector's tabs


//A singleton instance of the inspector controller, which is shared by all session windows.
//The controller should always be accessed through this method.
+ (BXInspectorController *) controller;


- (IBAction) showGameInspectorPanel:	(id)sender;	//Display the gamebox panel.
- (IBAction) showCPUInspectorPanel:		(id)sender;	//Display the CPU panel.
- (IBAction) showDriveInspectorPanel:	(id)sender;	//Display the drive list panel.
- (IBAction) showMouseInspectorPanel:	(id)sender;	//Display the mouse panel.

//Display the tab panel corresponding to the selected tab segment in the sender.
- (IBAction) selectInspectorPanel:		(NSSegmentedControl *)sender;


#pragma mark -
#pragma mark Window animation

//These are called internally to scale and fade from one panel to another using transition animations.
//They should not be called directly, and indeed should be moved to an internal interface.
- (void) startScalingToFrame: (NSRect)newFrame;
- (void) animationDidEnd: (NSAnimation *)animation;
- (void) animationDidStop: (NSAnimation *)animation;

@end
