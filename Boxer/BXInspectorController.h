/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXInspectorController manages the Boxer inspector panel. It is responsible for displaying and
//toggling the tabs of the panel, handling drag-drop events for files dragged into the panel for
//the DOS drive list, and other drive-related actions.

//TODO: drive-specific methods should be moved to a separate NSViewController for the
//drive list, leaving BXInspectorController responsible only for the window appearance.

#import <Cocoa/Cocoa.h>

@class BXDriveList;

@interface BXInspectorController : NSWindowController
{
	IBOutlet NSView *panelContainer;
	IBOutlet NSView *gamePanel;
	IBOutlet NSView *cpuPanel;
	IBOutlet NSView *drivePanel;
	IBOutlet NSSegmentedControl *panelSelector;
	IBOutlet NSArrayController *driveController;
}
@property (retain) NSView *panelContainer;	//The view into which the current panel will be added.
@property (retain) NSView *gamePanel;		//The gamebox properties tab panel.
@property (retain) NSView *cpuPanel;		//The CPU emulation settings tab panel.
@property (retain) NSView *drivePanel;		//The drive list panel.
@property (retain) NSSegmentedControl *panelSelector;	//The segmented tab selector button at the top of the inspector.
@property (retain) NSArrayController *driveController;	//The array controller representing the current session's drives.


//A singleton instance of the inspector controller, which is shared by all session windows.
//The controller should always be accessed through this method.
+ (BXInspectorController *) controller;

//Returns an array of tab panels, which should match the order of panelSelector's tab segments.
- (NSArray *) panels;

//Sets/gets the currently displayed panel. This will be added to panelContainer and faded in.
- (NSView *) currentPanel;
- (void) setCurrentPanel: (NSView *)panel;

- (IBAction) showGameInspectorPanel:	(id)sender;	//Display the gamebox panel.
- (IBAction) showCPUInspectorPanel:		(id)sender;	//Display the CPU panel.
- (IBAction) showDriveInspectorPanel:	(id)sender;	//Display the drive list panel.

//Display the tab panel corresponding to the selected tab segment in the sender.
- (IBAction) selectInspectorPanel:		(NSSegmentedControl *)sender;

//Reveal the selected drives each in a new Finder window.
- (IBAction) revealSelectedDrivesInFinder: (id)sender;

//Change to the first selected drive in DOS. This action is disabled if a process is running.
- (IBAction) openSelectedDrivesInDOS: (id)sender; 

//Unmount the selected drives from DOS.
- (IBAction) unmountSelectedDrives: (id)sender;


//Window animation
//----------------

//These are called internally to scale and fade from one panel to another using transition animations.
//They should not be called directly, and indeed should be moved to an internal interface.
- (void) startScalingToFrame: (NSRect)newFrame;
- (void) animationDidEnd: (NSAnimation *)animation;
- (void) animationDidStop: (NSAnimation *)animation;


//Handling drag-drop
//------------------

//The inspector panel responds to dragged files and folders while the drive tab panel is active.
//Drag operations into the drive tab panel work identically to drag operations into the main
//session window: these methods call the corresponding methods on BXSessionWindowController.
- (NSDragOperation)draggingEntered: (id < NSDraggingInfo >)sender;
- (BOOL)performDragOperation: (id < NSDraggingInfo >)sender;


//Handling the drives panel
//-------------------------

//TODO: move these off to an NSViewController dedicated to the drives panel
- (NSArray *)driveSortDescriptors;
- (NSPredicate *) driveFilterPredicate;

@end
