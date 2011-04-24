/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXImportFinishedPanelController controls the appearance and behaviour of the final
//your-gamebox-is-finished panel of the import process.

#import <Cocoa/Cocoa.h>

@class BXImportIconDropzone;
@class BXImportWindowController;
@interface BXImportFinishedPanelController : NSViewController
{
	IBOutlet BXImportWindowController *controller;
	IBOutlet BXImportIconDropzone *iconView;
	IBOutlet NSTextField *nameField;
}

//A reference to our window controller.
@property (assign, nonatomic) BXImportWindowController *controller;

//The image well that displays the gamebox icon.
@property (retain, nonatomic) BXImportIconDropzone *iconView;

//The text field that allows the gamebox's name to be edited.
@property (retain, nonatomic) NSTextField *nameField;

//The gamebox’s icon itself.
@property (retain, nonatomic) NSImage *gameboxIcon;

//Reveal the newly-minted gamebox in Finder.
- (IBAction) revealGamebox: (id)sender;

//Launch the newly-minted gamebox in a new Boxer process.
- (IBAction) launchGamebox: (id)sender;

//Called when the user drops an image onto the icon view.
- (IBAction) addCoverArt: (id)sender;

//Display help for this stage of the import process.
- (IBAction) showImportFinishedHelp: (id)sender;

@end

@interface BXImportIconDropzone : NSImageView
{
	BOOL isDragTarget;
}
@property (readonly, assign) BOOL isHighlighted;

@end