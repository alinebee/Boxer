/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
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

//Used by finishImportingPanel to end the DOS session and finish up the import.
- (IBAction) finishImporting: (id)sender;

@end
