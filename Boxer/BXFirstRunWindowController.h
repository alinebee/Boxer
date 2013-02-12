/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXFirstRunWindowController class description goes here.

#import <Cocoa/Cocoa.h>

@interface BXFirstRunWindowController : NSWindowController <NSOpenSavePanelDelegate>
{	
	NSPopUpButton *_gamesFolderSelector;
	NSButton *_addSampleGamesToggle;
	NSButton *_useShelfAppearanceToggle;
}

//UI elements on the first-run panel.
@property (retain, nonatomic) IBOutlet NSPopUpButton *gamesFolderSelector;
@property (retain, nonatomic) IBOutlet NSButton *addSampleGamesToggle;
@property (retain, nonatomic) IBOutlet NSButton *useShelfAppearanceToggle;

//Provides a singleton instance of the window controller which stays retained for the lifetime
//of the application. The controller should always be accessed from this singleton.
+ (id) controller;

//Create a new game folder with the chosen settings. Sent by the "Let's Go!" button on the first-run panel.
- (IBAction) makeGamesFolder: (id)sender;

//Display an open panel for choosing the games folder.
- (IBAction) showGamesFolderChooser: (id)sender;

//Adds a new menu option for the specified folder to the games folder selector
//(if one isn't already available) and selects the option.
- (void) chooseGamesFolderWithURL: (NSURL *)URL;

//Show/hide the window with a flip animation.
- (void) showWindowWithTransition: (id)sender;
- (void) hideWindowWithTransition: (id)sender;
@end