/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXImportDropzonePanelController controls the behaviour of the dropzone panel
//in the game import process.

#import <Cocoa/Cocoa.h>

@class BXImportDropzone;
@class BXImportWindowController;
@class BXBlueprintProgressIndicator;

@interface BXImportDropzonePanelController : NSViewController
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
< NSOpenSavePanelDelegate >
#endif
{
    __unsafe_unretained BXImportWindowController *_controller;
	BXImportDropzone *_dropzone;
	BXBlueprintProgressIndicator *_spinner;
}

//The dropzone within the dropzone panel
@property (retain, nonatomic) IBOutlet BXImportDropzone *dropzone;

//The progress indicator shown when scanning a game for installers.
//(This now lives on a separate interstitial view and not the Dropzone
//view, but I can't be bothered making a second controller for it.)
@property (retain, nonatomic) IBOutlet BXBlueprintProgressIndicator *spinner;

//A reference to our window controller
@property (assign, nonatomic) IBOutlet BXImportWindowController *controller;


//Display a file picker for choosing a folder or disc image to import
- (IBAction) showImportPathPicker: (id)sender;

//Display help for this stage of the import process.
- (IBAction) showImportDropzoneHelp: (id)sender;

@end