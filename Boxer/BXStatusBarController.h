/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXStatusBarController manages the main window's status bar and button states.

#import <Cocoa/Cocoa.h>

@class BXDOSWindowController;

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

//The window controller for the window containing this statusbar
- (BXDOSWindowController *)controller;

//Processes the selection/deselection of segments in the segmented button
- (IBAction) performSegmentedButtonAction: (id) sender;

//The text that will appear as the statusbar notification message
- (NSString *) notificationText;

//Selectively hides statusbar items when the window is too small to display them without overlaps 
- (void) _statusBarDidResize;

//Tears down our bindings when the window is about to close
- (void) _windowWillClose;

//Synchronises the selection state of segments in the segmented button
- (void) _syncSegmentedButtonStates;

//Set up/tear down the notification and KVC bindings we use to control the segmented button state
- (void) _prepareBindings;
- (void) _removeBindings;

@end
