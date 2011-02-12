/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXPreferencesController manages Boxer's application preferences panel.

#import "BXTabbedWindowController.h"


//Constants for preferences panel tab indexes
enum {
	BXGeneralPreferencesPanel,
	BXDisplayPreferencesPanel
};

@class BXFilterGallery;

@interface BXPreferencesController : BXTabbedWindowController
{
	IBOutlet BXFilterGallery *filterGallery;
	IBOutlet NSPopUpButton *gamesFolderSelector;
	IBOutlet NSMenuItem *currentGamesFolderItem;
}

@property (retain, nonatomic) BXFilterGallery *filterGallery;
@property (retain, nonatomic) NSPopUpButton *gamesFolderSelector;
@property (retain, nonatomic) NSMenuItem *currentGamesFolderItem;

//Provides a singleton instance of the window controller which stays retained for the lifetime
//of the application. BXPreferencesController should always be accessed from this singleton.
+ (BXPreferencesController *) controller;


#pragma mark -
#pragma mark Managing filter gallery state

//Change the default render filter to match the sender's tag.
//Note that this uses an intentionally different name from the toggleFilterType: defined on
//BXDOSWindowController and used by main menu items, as the two sets of controls need to be
//validated differently.
- (IBAction) toggleDefaultFilterType: (id)sender;

//Toggle whether the games shelf appearance is applied to the games folder.
//This will add/remove the appearance on-the-fly from the folder.
- (IBAction) toggleShelfAppearance: (NSButton *)sender;

//Synchonises the filter gallery controls to the current default filter.
//This is called through Key-Value Observing whenever the filter preference changes.
- (void) syncFilterControls;

//Display an open panel for choosing the games folder.
- (IBAction) showGamesFolderChooser: (id)sender;

@end
