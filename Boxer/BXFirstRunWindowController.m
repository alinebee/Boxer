/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXFirstRunWindowController.h"
#import "NSWindow+BXWindowEffects.h"

@implementation BXFirstRunWindowController
@synthesize gamesFolderSelector, addSampleGamesToggle, useShelfAppearanceToggle;

+ (id) controller
{
	static id singleton = nil;
	
	if (!singleton) singleton = [[self alloc] initWithWindowNibName: @"FirstRunWindow"];
	return singleton;
}

- (void) dealloc
{	
	[self setGamesFolderSelector: nil],			[gamesFolderSelector release];
	[self setAddSampleGamesToggle: nil],		[addSampleGamesToggle release];
	[self setUseShelfAppearanceToggle: nil],	[useShelfAppearanceToggle release];
	
	[super dealloc];
}

- (void) awakeFromNib
{
	//Set up the folder location list
}

- (void) showWindow: (id)sender
{
	[super showWindow: sender];
	[[self window] fadeInWithTransition: CGSFlip
							  direction: CGSUp
							   duration: 0.5
						   blockingMode: NSAnimationNonblocking];
	[NSApp runModalForWindow: [self window]];
}

- (BOOL) windowShouldClose: (id)sender
{
	//When the user clicks the close button, shut down the application instead:
	//We don't want them to proceed without having chosen a games folder first
	//TODO: should we leave this up to the application delegate?
	[NSApp stopModal];
	[NSApp terminate: self];
	return YES;
}


- (IBAction) makeGamesFolder: (id)sender
{
	[NSApp stopModal];
	[[self window] fadeOutWithTransition: CGSFlip
							   direction: CGSDown
								duration: 0.5
							blockingMode: NSAnimationBlocking];
}

- (IBAction) showGamesFolderChooser: (id)sender
{
	//NOTE: normally our go-to guy for this is BXGamesFolderPanelController,
	//but he insists on asking about sample games and creating the game folder
	//end of the process. We only want to add the chosen location to the list,
	//and will create the folder when the user confirms.
}

@end