/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "ADBMultiPanelWindowController.h"

@class BXImportSession;

/// \c BXImportWindowController manages the behaviour of the drive import window and coordinates
/// animation and transitions between the window's various views.
/// It takes its marching orders from the BXImportSession document class.
@interface BXImportWindowController : ADBMultiPanelWindowController

#pragma mark -
#pragma mark Properties

/// The dropzone panel, displayed initially when no import source has been selected 
@property (strong, nonatomic) IBOutlet NSView *dropzonePanel;

/// The indeterminate progress panel shown while scanning a game folder for installers.
@property (strong, nonatomic) IBOutlet NSView *loadingPanel;

/// The choose-thine-installer panel, displayed if the chosen game source contains
/// installers to choose from.
@property (strong, nonatomic) IBOutlet NSView *installerPanel;

/// The finalizing-gamebox panel, which shows the progress of the import operation.
@property (strong, nonatomic) IBOutlet NSView *finalizingPanel;

/// The final gamebox panel, which displays the finished gamebox for the user to launch.
@property (strong, nonatomic) IBOutlet NSView *finishedPanel;


/// Recast NSWindowController's standard accessors so that we get our own classes
/// (and don't have to keep recasting them ourselves.)
- (BXImportSession *) document;

/// Hand off control and appearance from one window controller to another.
/// Used to morph between windows.
- (void) handOffToController: (NSWindowController *)controller;

/// Return control to us from the specified window controller. 
- (void) pickUpFromController: (NSWindowController *)controller;

/// Ensure the appropriate panel is displayed in the import window.
///
/// This is called automatically whenever the import session's stage changes.
- (void) syncActivePanel;

@end
