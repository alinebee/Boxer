/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Cocoa/Cocoa.h>

@class BXImportDropzone;
@class BXImportWindowController;
@class BXBlueprintProgressIndicator;

/// \c BXImportDropzonePanelController controls the behaviour of the dropzone panel
/// in the game import process.
@interface BXImportDropzonePanelController : NSViewController <NSOpenSavePanelDelegate>

/// The dropzone within the dropzone panel.
@property (strong, nonatomic) IBOutlet BXImportDropzone *dropzone;

/// The progress indicator shown when scanning a game for installers.
/// (This now lives on a separate interstitial view and not the Dropzone
/// view, but I can't be bothered making a second controller for it.)
@property (strong, nonatomic) IBOutlet BXBlueprintProgressIndicator *spinner;

/// A back-reference to our owning window controller
@property (unsafe_unretained, nonatomic) IBOutlet BXImportWindowController *controller;


/// Display a file picker for choosing a folder or disc image to import
- (IBAction) showImportPathPicker: (nullable id)sender;

/// Display help for this stage of the import process.
- (IBAction) showImportDropzoneHelp: (nullable id)sender;

@end
