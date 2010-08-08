/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXImportWindowController manages the behaviour of the drive import window and coordinates
//animation and transitions between the window's various views.
//It takes its marching orders from the BXImport document class.

#import <Cocoa/Cocoa.h>

@class BXImport;

@interface BXImportWindowController : NSWindowController
{
	IBOutlet NSView *dropzonePanel;
	IBOutlet NSView *installerPanel;
}


#pragma mark -
#pragma mark Properties

//The dropzone panel, displayed initially when no import source has been selected 
@property (retain, nonatomic) NSView *dropzonePanel;

//The choose-thine-installer panel, displayed if the chosen game source contains
//installers to choose from.
@property (retain, nonatomic) NSView *installerPanel;

//The currently-displayed panel.
@property (assign, nonatomic) NSView *currentPanel;


//Recast NSWindowController's standard accessors so that we get our own classes
//(and don't have to keep recasting them ourselves.)
- (BXImport *) document;

//Show the corresponding panel. Called from BXImport.
- (void) showDropzonePanel;
- (void) showInstallerPanel;

@end