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
	BXDisplayPreferencesPanel,
	BXAudioPreferencesPanel
};

@class BXFilterGallery;
@class BXMT32ROMDropzone;

@interface BXPreferencesController : BXTabbedWindowController <NSOpenSavePanelDelegate>
{
	IBOutlet BXFilterGallery *filterGallery;
	IBOutlet NSPopUpButton *gamesFolderSelector;
	IBOutlet NSMenuItem *currentGamesFolderItem;
    IBOutlet BXMT32ROMDropzone *MT32ROMDropzone;
    IBOutlet NSView *missingMT32ROMHelp;
    IBOutlet NSView *realMT32Help;
    IBOutlet NSView *MT32ROMOptions;
}

@property (retain, nonatomic) BXFilterGallery *filterGallery;
@property (retain, nonatomic) NSPopUpButton *gamesFolderSelector;
@property (retain, nonatomic) NSMenuItem *currentGamesFolderItem;
@property (retain, nonatomic) BXMT32ROMDropzone *MT32ROMDropzone;
@property (retain, nonatomic) NSView *missingMT32ROMHelp;
@property (retain, nonatomic) NSView *realMT32Help;
@property (retain, nonatomic) NSView *MT32ROMOptions;

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
//This is called through Key-Value Observing whenever ROMs are imported, and also 
//whenever the focus returns to Boxer from another application (in case the user has
//manually added the ROMs themselves in Finder).
- (void) syncMT32ROMState;

//Show the MT-32 ROMs folder in Finder, creating it if it doesn't already exist.
- (IBAction) showMT32ROMsInFinder: (id)sender;

//Show the ROM file chooser panel.
- (IBAction) showMT32ROMFileChooser: (id)sender;
- (void) MT32ROMFileChooserDidEnd: (NSOpenPanel *)openPanel
                       returnCode: (int)returnCode
                      contextInfo: (void *)contextInfo;

//Display help for the Audio Preferences panel.
- (IBAction) showAudioPreferencesHelp: (id)sender;

//Does the work of importing ROMs from the specified path. Called when drag-dropping
//ROMs onto the MT-32 ROM dropzone or choosing them from the file picker.
//Will display an error sheet in the Preferences window if importing failed.
- (BOOL) handleROMImportFromPaths: (NSArray *)paths;


#pragma mark -
#pragma mark Help

//Display help for the Display Preferences panel.
- (IBAction) showDisplayPreferencesHelp: (id)sender;

@end
