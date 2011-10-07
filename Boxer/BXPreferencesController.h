/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
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
@class BXMT32ROMDropzone;

@interface BXPreferencesController : BXTabbedWindowController
{
	IBOutlet BXFilterGallery *filterGallery;
	IBOutlet NSPopUpButton *gamesFolderSelector;
	IBOutlet NSMenuItem *currentGamesFolderItem;
    IBOutlet BXMT32ROMDropzone *MT32ROMDropzone;
    IBOutlet NSView *MT32ROMMissingHelpText;
    IBOutlet NSView *MT32ROMUsageHelpText;
}

@property (retain, nonatomic) BXFilterGallery *filterGallery;
@property (retain, nonatomic) NSPopUpButton *gamesFolderSelector;
@property (retain, nonatomic) NSMenuItem *currentGamesFolderItem;
@property (retain, nonatomic) BXMT32ROMDropzone *MT32ROMDropzone;
@property (retain, nonatomic) NSView *MT32ROMMissingHelpText;
@property (retain, nonatomic) NSView *MT32ROMUsageHelpText;

//Provides a singleton instance of the window controller which stays retained for the lifetime
//of the application. BXPreferencesController should always be accessed from this singleton.
+ (BXPreferencesController *) controller;


#pragma mark -
#pragma mark Filter gallery controls

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


#pragma mark -
#pragma mark General preferences controls

//Display an open panel for choosing the games folder.
- (IBAction) showGamesFolderChooser: (id)sender;


#pragma mark -
#pragma mark Audio controls

//Synchronises the display of the MT-32 ROM dropzone to the currently-installed ROM.
//This is called through Key-Value Observing whenever the ROMs change.
- (void) syncMT32ROMState;

- (IBAction) showMT32ROMsInFinder: (id)sender;
- (IBAction) showMT32ROMFileChooser: (id)sender;

#pragma mark -
#pragma mark Help

//Display help for the Display Preferences panel.
- (IBAction) showDisplayPreferencesHelp: (id)sender;
@end
