/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXImportTipsPanelController.h"
#import "BXImportSession.h"
#import "BXEmulator.h"
#import "BXAppController.h"


@implementation BXImportTipsPanelController
@synthesize finishImportingPanel, installerTipsPanel;

- (NSString *) nibName	{ return @"ImportTipsPanel"; }

- (void) dealloc
{
	[self setFinishImportingPanel: nil],[finishImportingPanel release];
	[self setInstallerTipsPanel: nil],	[installerTipsPanel release];
	[super dealloc];
}

- (void) syncActivePanel
{
	BXImportSession *session = [self representedObject];
	NSView *panel;
	
	if ([[session emulator] isRunningProcess])
	{
		//Show installer tips while any program is running
		panel = installerTipsPanel;
	}
	else
	{
		//Otherwise, show the UI for finishing the import process
		panel = finishImportingPanel;
	}
	[self setActivePanel: panel];
}

- (IBAction) showInstallerHelp: (id)sender
{
	[[NSApp delegate] showHelpAnchor: @"game-installation-without-preamble"];
}

- (void) syncPanelExecutables
{
	//The installer tips panel never shows available executables, so this becomes a no-op.
	return;
}

@end