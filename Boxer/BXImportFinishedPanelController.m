/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXImportFinishedPanelController.h"
#import "BXAppController.h"
#import "BXImportWindowController.h"
#import "BXSession.h"
#import "BXCoverArt.h"

@implementation BXImportFinishedPanelController
@synthesize controller;

+ (NSSet *) keyPathsForValuesAffectingGameboxIcon
{
	return [NSSet setWithObject: @"controller.document.representedIcon"];
}
- (void) setGameboxIcon: (NSImage *)icon
{
	if (icon)
	{
		[[controller document] setRepresentedIcon: [BXCoverArt coverArtWithImage: icon]];
	}
	else [[controller document] setRepresentedIcon: nil];	
}

- (NSImage *) gameboxIcon
{
	NSImage *icon = [[controller document] representedIcon];
	if (!icon) icon = [NSImage imageNamed: @"package.icns"];
	return icon;
}


#pragma mark -
#pragma mark UI actions

- (IBAction) revealGamebox: (id)sender
{
	NSString *packagePath = [[[controller document] gamePackage] bundlePath];
	[[NSApp delegate] revealInFinder: packagePath];
}

- (IBAction) launchGamebox: (id)sender
{
	NSURL *packageURL = [NSURL fileURLWithPath: [[[controller document] gamePackage] bundlePath]];
	
	//Close ourselves down so that we won't appear as already representing this game
	[[controller document] close];
	
	//Open the newly-minted gamebox in a new Boxer process.
	[[NSApp delegate] openDocumentWithContentsOfURL: packageURL display: YES error: NULL];
}

@end