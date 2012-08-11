/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
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
	NSSegmentedControl *_statusBarControls;
	NSTextField *_notificationMessage;
    NSView *_volumeControls;
}

@property (retain, nonatomic) IBOutlet NSSegmentedControl *statusBarControls;
@property (retain, nonatomic) IBOutlet NSTextField *notificationMessage;
@property (retain, nonatomic) IBOutlet NSView *volumeControls;

//The window controller for the window containing this statusbar
@property (readonly, nonatomic) BXDOSWindowController *controller;

//The text that will appear as the statusbar notification message
@property (readonly, nonatomic) NSString *notificationText;

//Processes the selection/deselection of segments in the segmented button.
//Called via statusBarControl's action.
- (IBAction) performSegmentedButtonAction: (id) sender;

@end
