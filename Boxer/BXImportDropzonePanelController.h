/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXImportDropzonePanelController controls the behaviour of the dropzone panel
//in the game import process.

#import <Cocoa/Cocoa.h>

@class BXImportDropzone;
@class BXImportWindowController;

@interface BXImportDropzonePanelController : NSViewController
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
< NSOpenSavePanelDelegate >
#endif
{
	IBOutlet BXImportDropzone *dropzone;
	IBOutlet BXImportWindowController *controller;
}

//The dropzone within the dropzone panel
@property (retain, nonatomic) BXImportDropzone *dropzone;

//A reference to our window controller
@property (assign, nonatomic) BXImportWindowController *controller;


//Display a file picker for choosing a folder or disc image to import
- (IBAction) showImportPathPicker: (id)sender;

@end