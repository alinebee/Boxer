/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXFirstRunWindowController class description goes here.

#import <Cocoa/Cocoa.h>

@interface BXFirstRunWindowController : NSWindowController
{	
	IBOutlet NSPopUpButton *gamesFolderSelector;
	IBOutlet NSButton *addSampleGamesToggle;
	IBOutlet NSButton *useShelfAppearanceToggle;
}

//UI elements on the first-run panel.
@property (retain, nonatomic) NSPopUpButton *gamesFolderSelector;
@property (retain, nonatomic) NSButton *addSampleGamesToggle;
@property (retain, nonatomic) NSButton *useShelfAppearanceToggle;

//Provides a singleton instance of the window controller which stays retained for the lifetime
//of the application. The controller should always be accessed from this singleton.
+ (id) controller;

//Create a new game folder with the chosen settings. Sent by the "Let's Go!" button on the first-run panel.
- (IBAction) makeGamesFolder: (id)sender;

//Display an open panel for choosing the games folder.
- (IBAction) showGamesFolderChooser: (id)sender;


- (void) setChosenGamesFolder: (NSOpenPanel *)openPanel
				   returnCode: (int)returnCode
				  contextInfo: (void *)contextInfo;

//Show/hide the window with a flip animation.
- (void) showWindowWithFlip: (id)sender;
- (void) hideWindowWithFlip: (id)sender;
@end