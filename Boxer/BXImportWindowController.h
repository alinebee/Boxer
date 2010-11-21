/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXImportWindowController manages the behaviour of the drive import window and coordinates
//animation and transitions between the window's various views.
//It takes its marching orders from the BXImport document class.

#import "BXMultiPanelWindowController.h"

@class BXImport;

@interface BXImportWindowController : BXMultiPanelWindowController
{
	IBOutlet NSView *dropzonePanel;
	IBOutlet NSView *loadingPanel;
	IBOutlet NSView *installerPanel;
	IBOutlet NSView *finalizingPanel;
	IBOutlet NSView *finishedPanel;
}


#pragma mark -
#pragma mark Properties

//The dropzone panel, displayed initially when no import source has been selected 
@property (retain, nonatomic) NSView *dropzonePanel;

//The indeterminate progress panel shown while scanning a game folder for installers.
@property (retain, nonatomic) NSView *loadingPanel;

//The choose-thine-installer panel, displayed if the chosen game source contains
//installers to choose from.
@property (retain, nonatomic) NSView *installerPanel;

//The finalizing-gamebox panel, which shows the progress of the import operation.
@property (retain, nonatomic) NSView *finalizingPanel;

//The final gamebox panel, which displays the finished gamebox for the user to launch.
@property (retain, nonatomic) NSView *finishedPanel;


//Recast NSWindowController's standard accessors so that we get our own classes
//(and don't have to keep recasting them ourselves.)
- (BXImport *) document;

//Hand off control and appearance from one window controller to another.
//Used to morph between windows.
- (void) handOffToController: (NSWindowController *)controller;

//Return control to us from the specified window controller. 
- (void) pickUpFromController: (NSWindowController *)controller;

@end