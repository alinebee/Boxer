/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXGamesFolderPanelController displays the choose-a-game-folder open panel, and manages its
//accessory view. It is also responsible for adding sample games to the chosen folder, if requested.

#import <Cocoa/Cocoa.h>

@interface BXGamesFolderPanelController : NSViewController
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
< NSOpenSavePanelDelegate >
#endif
{
	IBOutlet NSButton *copySampleGamesToggle;
}

@property (retain, nonatomic) NSButton *copySampleGamesToggle;

//Returns a singleton instance, which loads the view from the NIB file the first time.
+ (id) controller;

//Display the open panel as a sheet in the specified window
//(or as a modal dialog, if window is null.)
- (void) showGamesFolderPanelForWindow: (NSWindow *)window;

//The callback called when the open panel is closed. Will set Boxer's games folder path
//to the chosen folder, if one was selected.
- (void) setChosenGamesFolder: (NSOpenPanel *)openPanel
				   returnCode: (int)returnCode
				  contextInfo: (void *)contextInfo;

@end