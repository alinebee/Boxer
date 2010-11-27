/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXPreferencesController.h"
#import "BXSession.h"
#import "BXValueTransformers.h"
#import "BXGamesFolderPanelController.h"

#pragma mark -
#pragma mark Implementation

@implementation BXPreferencesController
@synthesize filterGallery, gamesFolderSelector, currentGamesFolderItem;

#pragma mark -
#pragma mark Initialization and deallocation

+ (BXPreferencesController *) controller
{
	static BXPreferencesController *singleton = nil;
	
	if (!singleton) singleton = [[self alloc] initWithWindowNibName: @"Preferences"];
	return singleton;
}

- (void) awakeFromNib
{
	[super awakeFromNib];
	//Bind to the filter preference so that we can synchronise our filter selection controls when it changes
	[[NSUserDefaults standardUserDefaults] addObserver: self
											forKeyPath: @"filterType"
											   options: NSKeyValueObservingOptionInitial
											   context: nil];
	
	//Bind the attributed title so that it will prettify the current games folder path
	NSDictionary *bindingOptions = [NSDictionary dictionaryWithObjectsAndKeys:
									@"BXDisplayPathWithIcons", NSValueTransformerNameBindingOption,
									nil];
	[currentGamesFolderItem bind: @"attributedTitle"
						toObject: [NSApp delegate]
					 withKeyPath: @"gamesFolderPath"
						 options: bindingOptions];

}

- (void) dealloc
{
	[currentGamesFolderItem unbind: @"attributedTitle"];
	
	[self setFilterGallery: nil],				[filterGallery release];
	[self setGamesFolderSelector: nil],			[gamesFolderSelector release];
	[self setCurrentGamesFolderItem: nil],		[currentGamesFolderItem release];
	[super dealloc];
}


#pragma mark -
#pragma mark Switching tabs

- (void) tabView: (NSTabView *)tabView didSelectTabViewItem: (NSTabViewItem *)tabViewItem
{
	//Set the window title to the same as the active tab
	//[[self window] setTitle: [tabViewItem label]];
	
	//Sync the toolbar selection after switching tabs
	NSInteger tabIndex = [tabView indexOfTabViewItem: tabViewItem];
	for (NSToolbarItem *item in [[[self window] toolbar] items])
	{
		if ([item tag] == tabIndex)
		{
			[[[self window] toolbar] setSelectedItemIdentifier: [item itemIdentifier]];
			break;
		}
	}
}

#pragma mark -
#pragma mark Managing filter gallery state

- (void) observeValueForKeyPath: (NSString *)keyPath
					   ofObject: (id)object
						 change: (NSDictionary *)change
						context: (void *)context
{
	//Whenever the key path changes, synchronise our filter selection controls
	if ([object isEqualTo: [NSUserDefaults standardUserDefaults]] && [keyPath isEqualToString: @"filterType"])
	{
		[self syncFilterControls];
	}
}

- (IBAction) toggleDefaultFilterType: (id)sender
{
	NSInteger filterType = [sender tag];
	[[NSUserDefaults standardUserDefaults] setInteger: filterType forKey: @"filterType"];
}

- (void) syncFilterControls
{
	NSInteger defaultFilter = [[NSUserDefaults standardUserDefaults] integerForKey: @"filterType"];

	for (id view in [filterGallery subviews])
	{
		if ([view isKindOfClass: [NSButton class]])
		{
			[view setState: ([view tag] == defaultFilter)];
		}
	}
}

//Display an open panel for choosing the games folder.
- (IBAction) showGamesFolderChooser: (id)sender
{
	BXGamesFolderPanelController *chooser = [BXGamesFolderPanelController controller];
	[chooser showGamesFolderPanelForWindow: [self window]];
	[[self gamesFolderSelector] selectItemAtIndex: 0];
}

@end
