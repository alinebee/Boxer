/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXStatusBarController manages the main window's status bar and button states.

#import <Cocoa/Cocoa.h>

@class BXSessionWindowController;

enum {
	BXStatusBarInspectorSegment,
	BXStatusBarProgramPanelSegment,
	BXStatusBarMouseLockSegment
};

@interface BXStatusBarController : NSViewController
{
	IBOutlet NSSegmentedControl *statusBarControls;
	IBOutlet NSTextField *notificationMessage;
}

//Returns the window controller associated with this statusbar
- (BXSessionWindowController *)windowController;

//Processes the selection/deselection of segments in the segmented button
- (IBAction) performSegmentedButtonAction: (id) sender;

//Synchronises the selection state of segments in the segmented button
- (void) syncSegmentedButtonStates;

//The text that will appear as the statusbar notification message
- (NSString *) notificationText;
@end