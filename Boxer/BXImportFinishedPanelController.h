/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXImportFinishedPanelController controls the appearance and behaviour of the final
//your-gamebox-is-finished panel of the import process.

#import <Cocoa/Cocoa.h>

@class BXImportWindowController;
@interface BXImportFinishedPanelController : NSViewController
{
	IBOutlet BXImportWindowController *controller;
}

//A reference to our window controller.
@property (assign, nonatomic) BXImportWindowController *controller;
@property (retain, nonatomic) NSImage *gameboxIcon;

//Reveal the newly-minted gamebox in Finder.
- (IBAction) revealGamebox: (id)sender;

//Launch the newly-minted gamebox in a new Boxer process.
- (IBAction) launchGamebox: (id)sender;

@end