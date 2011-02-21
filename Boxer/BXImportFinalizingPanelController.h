/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXImportFinalizingPanelController manages the finalizing-gamebox view of the game import window.

#import <Cocoa/Cocoa.h>
#import "BXImport.h"

@class BXImportWindowController;
@interface BXImportFinalizingPanelController : NSViewController
{
	IBOutlet BXImportWindowController *controller;
}

//A reference to our window controller.
@property (assign, nonatomic) BXImportWindowController *controller;

//Whether we can provide an accurate indication of progress.
//Used for toggling the progressbar to/from indeterminate mode.
@property (readonly, nonatomic) BOOL isIndeterminate;

//How far through the current import stage we are.
//Used as the value for the progress bar when isIndeterminate is NO.
@property (readonly, nonatomic) BXOperationProgress progress;

//A textual description of what import stage we are currently performing.
//Used for populating the description field beneath the progress bar.
@property (readonly, nonatomic) NSString *progressDescription; 


//Display help for this stage of the import process.
- (IBAction) showImportFinalizingHelp: (id)sender;

@end