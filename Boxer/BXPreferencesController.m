/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXPreferencesController.h"
#import "BXSession.h"
#import "BXValueTransformers.h"
#import "BXAppController.h"


#pragma mark -
#pragma mark Private method declarations

@interface BXPreferencesController ()

//Sets the games folder location based on the chosen folder in the chooser panel.
- (void) _setChosenGamesFolder: (NSOpenPanel *)openPanel
					returnCode: (int)returnCode
				   contextInfo: (void *)contextInfo;

@end


#pragma mark -
#pragma mark Implementation

@implementation BXPreferencesController
@synthesize filterGallery, gamesFolderSelector;

#pragma mark -
#pragma mark Initialization and deallocation

+ (void) initialize
{
	BXImageSizeTransformer *gamesFolderIconSize	= [[BXImageSizeTransformer alloc] initWithSize: NSMakeSize(16, 16)];
	BXDisplayPathTransformer *gamesFolderPath	= [[BXDisplayPathTransformer alloc] initWithJoiner: @" ▸ " maxComponents: 2];
	
	[NSValueTransformer setValueTransformer: gamesFolderIconSize forName: @"BXGamesFolderIconSize"];
	[NSValueTransformer setValueTransformer: gamesFolderPath forName: @"BXGamesFolderPath"];
	[gamesFolderIconSize release];
	[gamesFolderPath release];
}

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
}

- (void) dealloc
{
	[self setFilterGallery: nil], [filterGallery release];
	[self setGamesFolderSelector: nil], [gamesFolderSelector release];
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

- (IBAction) showGamesFolderChooserPanel: (id)sender
{	
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	
	[openPanel setCanChooseFiles: NO];
	[openPanel setCanChooseDirectories: YES];
	[openPanel setTreatsFilePackagesAsDirectories: NO];
	[openPanel setMessage:	NSLocalizedString(@"Choose a folder in which to keep your DOS games:",
											  @"Help text shown at the top of choose-a-games-folder panel.")];
	
	[openPanel beginSheetForDirectory: nil
								 file: nil
								types: nil
					   modalForWindow: [self window]
						modalDelegate: self
					   didEndSelector: @selector(_setChosenGamesFolder:returnCode:contextInfo:)
						  contextInfo: nil];
}

- (void) _setChosenGamesFolder: (NSOpenPanel *)openPanel
					returnCode: (int)returnCode
				   contextInfo: (void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		NSString *path = [[openPanel URL] path];
		
		[[NSApp delegate] setGamesFolderPath: path];
	}
	
	//Restore the game folder dropdown to the first item, which is the game folder representation
	[[self gamesFolderSelector] selectItemAtIndex: 0];
}

@end
