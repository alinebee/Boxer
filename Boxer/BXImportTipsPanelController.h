/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXProgramPanelController.h"


@interface BXImportTipsPanelController : BXProgramPanelController
{
	IBOutlet NSView *finishImportingPanel;
	IBOutlet NSView *installerTipsPanel;
}

@property (retain, nonatomic) NSView *finishImportingPanel;
@property (retain, nonatomic) NSView *installerTipsPanel;

//Used by installerTipsPanel to show the help page for game installation.
- (IBAction) showInstallerHelp: (id)sender;

@end
