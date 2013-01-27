/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXImportInstallerPanelController controls the behaviour of the choose-thine-installer panel
//in the game import process.

#import <Cocoa/Cocoa.h>

@class BXImportWindowController;

@interface BXImportInstallerPanelController : NSViewController
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
< NSOpenSavePanelDelegate >
#endif
{
    __unsafe_unretained BXImportWindowController *_controller;
    NSPopUpButton *_installerSelector;
}

//A reference to our window controller.
@property (assign, nonatomic) IBOutlet BXImportWindowController *controller;

//The drop-down selector we populate with our installer program options
@property (retain, nonatomic) IBOutlet NSPopUpButton *installerSelector;


#pragma mark -
#pragma mark UI actions
 
//Skip the installation step.
- (IBAction) skipInstaller: (id)sender;

//Cancel the choice of installers and return to the previous step.
- (IBAction) cancelInstallerChoice: (id)sender;

//Launch the selected installer in installerChoice.
- (IBAction) launchSelectedInstaller: (id)sender;

//Display a standard Open panel for choosing an installer program to use.
- (IBAction) showInstallerPicker: (id)sender;

//Display help for this stage of the import process.
- (IBAction) showImportInstallerHelp: (id)sender;

//Add a new installer with the specified URL to the list of available installers.
- (void) addInstallerFromURL: (NSURL *)URL;

@end