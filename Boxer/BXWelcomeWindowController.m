/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXWelcomeWindowController.h"

//The height of the bottom window border.
//TODO: determine this from NIB content.
#define BXWelcomeWindowBorderThickness 32.0f

#define BXRecentDocumentsMenuTag 1

@implementation BXWelcomeWindowController
@synthesize openRecentButton;

+ (id) controller
{
	static id singleton = nil;
	
	if (!singleton) singleton = [[self alloc] initWithWindowNibName: @"Welcome"];
	return singleton;
}

- (void) dealloc
{
	[self setOpenRecentButton: nil], [openRecentButton release];
	[super dealloc];
}

- (void) windowDidLoad
{
	[[self window] setContentBorderThickness: BXWelcomeWindowBorderThickness + 1 forEdge: NSMinYEdge];

	/*
	NSMenu *fileMenu = [[[NSApp mainMenu] itemAtIndex: 1] submenu];
	NSMenu *recentDocumentsMenu = [[fileMenu itemWithTag: BXRecentDocumentsMenuTag] submenu];
	
	NSPopUpButtonCell *recentButtonCell = [[self openRecentButton] cell];
	
	NSMenuItem *titleItem = [[NSMenuItem alloc] init];
	[titleItem setTitle: [recentButtonCell itemTitleAtIndex: 0]];
	
	[recentButtonCell setMenu: [[recentDocumentsMenu copy] autorelease]];
	[recentButtonCell setUsesItemFromMenu: NO];
	[recentButtonCell setMenuItem: titleItem];
	
	[titleItem release];
	 */
}

- (void) menuWillOpen: (NSMenu *)menu
{
	//Fill the Open Recent dropdown with the contents of the corresponding Open Recent app menu
	//FIXME: this doesn't work because the Open Recent menu is a Very Special Boy and doesn't
	//have persistent items like a normal menu.
	//Instead, we'll need to create items by hand from [BXAppController recentDocumentURLs],
	//which means we lose the Open Recent menu's cool contextual path clarifications.
	
	NSMenu *fileMenu = [[[NSApp mainMenu] itemAtIndex: 1] submenu];
	NSMenu *recentDocumentsMenu = [[fileMenu itemWithTag: BXRecentDocumentsMenuTag] submenu];
	
	
	//Delete all items but the first one (which is the label for the button)
	while ([menu numberOfItems] > 1) [menu removeItemAtIndex: 1];
	
	
	//Then, repopulate it with copies of the Open Recent menu items
	for (NSMenuItem *item in [recentDocumentsMenu itemArray])
	{
		[menu addItem: [[item copy] autorelease]];
	}
}

@end