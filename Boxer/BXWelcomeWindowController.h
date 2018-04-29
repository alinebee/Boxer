/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Cocoa/Cocoa.h>
#import "BXWelcomeButtonDraggingDelegate.h"

@class BXWelcomeButton;

/// \c BXWelcomeWindowController manages the welcome window shown when Boxer launches.
@interface BXWelcomeWindowController : NSWindowController <BXWelcomeButtonDraggingDelegate>

/// The Open Recent popup button.
@property (strong, nonatomic) IBOutlet NSPopUpButton *recentDocumentsButton;

/// The import-a-new-game button. Drag-drop events onto this button will be handled by this controller.
@property (strong, nonatomic) IBOutlet BXWelcomeButton *importGameButton;

/// The open-DOS-prompt button. Drag-drop events onto this button will be handled by this controller.
@property (strong, nonatomic) IBOutlet BXWelcomeButton *openPromptButton;

/// The browse-games-folder button. Has no special behaviour.
@property (strong, nonatomic) IBOutlet BXWelcomeButton *showGamesFolderButton;


/// Provides a singleton instance of the window controller which stays retained for the lifetime
/// of the application. The controller should always be accessed from this singleton.
+ (instancetype) controller;

/// Open the URL represented by the sending menu item. Called by items in the Open Recent popup button.
- (IBAction) openRecentDocument: (NSMenuItem *)sender;

/// Reveal the window by bringing it in with a flip transition.
- (void) showWindowWithTransition: (id)sender;

@end
