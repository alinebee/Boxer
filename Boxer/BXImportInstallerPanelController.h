/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXImportInstallerPanelController controls the behaviour of the choose-thine-installer panel
//in the game import process.

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class BXImportWindowController;

/// \c BXImportInstallerPanelController controls the behaviour of the choose-thine-installer panel
/// in the game import process.
@interface BXImportInstallerPanelController : NSViewController < NSOpenSavePanelDelegate >
{
    __unsafe_unretained BXImportWindowController *_controller;
    NSPopUpButton *_installerSelector;
}

/// A reference to our window controller.
@property (assign, nonatomic, nullable) IBOutlet BXImportWindowController *controller;

/// The drop-down selector we populate with our installer program options
@property (strong, nonatomic, nullable) IBOutlet NSPopUpButton *installerSelector;

/// Whether we can show a menu option to let the user pick an installer from an open panel.
/// Will be \c NO if the source URL of the import is a disk image, rather than a folder.
@property (readonly, nonatomic) BOOL canBrowseInstallers;

#pragma mark -
#pragma mark UI actions
 
/// Skip the installation step.
- (IBAction) skipInstaller: (nullable id)sender;

/// Cancel the choice of installers and return to the previous step.
- (IBAction) cancelInstallerChoice: (nullable id)sender;

/// Launch the selected installer in installerChoice.
- (IBAction) launchSelectedInstaller: (nullable id)sender;

/// Display a standard Open panel for choosing an installer program to use.
- (IBAction) showInstallerPicker: (nullable id)sender;

/// Display help for this stage of the import process.
- (IBAction) showImportInstallerHelp: (nullable id)sender;

/// Add a new installer with the specified URL to the list of available installers.
- (void) addInstallerFromURL: (NSURL *)URL;

@end

NS_ASSUME_NONNULL_END
