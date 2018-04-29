/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Cocoa/Cocoa.h>

/// BXGamesFolderPanelController displays the choose-a-game-folder open panel, and manages its
/// accessory view. It is also responsible for adding sample games to the chosen folder, if requested.
@interface BXGamesFolderPanelController : NSViewController <NSOpenSavePanelDelegate>

@property (strong, nonatomic) IBOutlet NSButton *sampleGamesToggle;
@property (strong, nonatomic) IBOutlet NSButton *useShelfAppearanceToggle;

/// Returns a singleton instance, which loads the view from the NIB file the first time.
@property (class, readonly, strong) id controller;

/// Display the open panel as a sheet in the specified window
/// (or as a modal dialog, if window is nil.)
- (void) showGamesFolderPanelForWindow: (NSWindow *)window;

@end
