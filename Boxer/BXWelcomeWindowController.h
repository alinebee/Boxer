/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXWelcomeWindowController manages the welcome window shown when Boxer launches.

#import <Cocoa/Cocoa.h>
#import "BXWelcomeButtonDraggingDelegate.h"

@class BXWelcomeButton;

@interface BXWelcomeWindowController : NSWindowController <BXWelcomeButtonDraggingDelegate>
{
	IBOutlet NSPopUpButton *recentDocumentsButton;
	IBOutlet BXWelcomeButton *importGameButton;
	IBOutlet BXWelcomeButton *openPromptButton;
}

//The Open Recent popup button.
@property (retain, nonatomic) NSPopUpButton *recentDocumentsButton;

//The import-a-new-game button. Drag-drop events onto this button will be handled by this controller.
@property (retain, nonatomic) BXWelcomeButton *importGameButton;

//The open-DOS-prompt button. Drag-drop events onto this button will be handled by this controller.
@property (retain, nonatomic) BXWelcomeButton *openPromptButton;


//Provides a singleton instance of the window controller which stays retained for the lifetime
//of the application. The controller should always be accessed from this singleton.
+ (id) controller;

//Open the URL represented by the sending menu item. Called by items in the Open Recent popup button.
- (IBAction) openRecentDocument: (NSMenuItem *)sender;

@end