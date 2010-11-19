/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXPreferencesController.h"
#import "BXSession.h"
#import "BXValueTransformers.h"
#import "BXAppController+BXGamesFolder.h"


#pragma mark -
#pragma mark Private method declarations

@interface BXPreferencesController ()

//Sets the games folder location based on the chosen folder in the chooser panel.
- (void) _setChosenGamesFolder: (NSOpenPanel *)openPanel
					returnCode: (int)returnCode
				   contextInfo: (void *)contextInfo;

//Copy sample games to the specified path with indeterminate progress indicator
- (void) _addSampleGamesToPath: (NSString *)path;

@end


#pragma mark -
#pragma mark Implementation

@implementation BXPreferencesController
@synthesize filterGallery, gamesFolderSelector;
@synthesize folderSelectorAccessoryView, copySampleGamesToggle;
@synthesize processingGamesFolder;

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
	[self setFilterGallery: nil],				[filterGallery release];
	[self setGamesFolderSelector: nil],			[gamesFolderSelector release];
	[self setFolderSelectorAccessoryView: nil],	[folderSelectorAccessoryView release];
	[self setCopySampleGamesToggle: nil],		[copySampleGamesToggle release];
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

	NSString *currentFolderPath = [[NSApp delegate] gamesFolderPath];
	NSString *parentFolderPath, *currentFolderName;
	if (currentFolderPath)
	{
		parentFolderPath = [currentFolderPath stringByDeletingLastPathComponent];
		currentFolderName = [currentFolderPath lastPathComponent];
	}
	else
	{
		//If no folder yet exists, choose
		parentFolderPath = NSHomeDirectory();
		currentFolderName = nil;
	}
	
	[openPanel setCanCreateDirectories: YES];
	[openPanel setCanChooseDirectories: YES];
	[openPanel setCanChooseFiles: NO];
	[openPanel setTreatsFilePackagesAsDirectories: NO];
	[openPanel setAllowsMultipleSelection: NO];
	
	[openPanel setAccessoryView: [self folderSelectorAccessoryView]];
	[openPanel setDelegate: self];
	
	[openPanel setPrompt: NSLocalizedString(@"Select", @"Button label for Open panels when selecting a folder.")];
	[openPanel setMessage: NSLocalizedString(@"Select a folder in which to keep your DOS games:",
											 @"Help text shown at the top of choose-a-games-folder panel.")];
	
	[openPanel beginSheetForDirectory: parentFolderPath
								 file: currentFolderName
								types: nil
					   modalForWindow: [self window]
						modalDelegate: self
					   didEndSelector: @selector(_setChosenGamesFolder:returnCode:contextInfo:)
						  contextInfo: nil];
}

- (void) panelSelectionDidChange: (id)sender
{
	NSString *selection = [[sender URL] path];
	NSFileManager *manager = [NSFileManager defaultManager];
	BOOL hasFiles = ([[manager enumeratorAtPath: selection] nextObject] != nil);
	
	//If the selected folder is empty, turn on the copy-sample-games checkbox; otherwise, clear it. 
	[[self copySampleGamesToggle] setState: !hasFiles];
}

- (void) panel: (NSOpenPanel *)openPanel directoryDidChange: (NSString *)path
{
	[self panelSelectionDidChange: openPanel];
}

- (void) _setChosenGamesFolder: (NSOpenPanel *)openPanel
					returnCode: (int)returnCode
				   contextInfo: (void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		NSString *path = [[openPanel URL] path];
		
		if ([[NSApp delegate] appliesShelfAppearanceToGamesFolder])
		{
			[[NSApp delegate] applyShelfAppearanceToPath: path switchToShelfMode: YES];
		}
		
		if ([[self copySampleGamesToggle] state])
		{
			//Let the sheet close before we start copying files, so that we can display the progress indicator
			[self performSelector: @selector(_addSampleGamesToPath:) withObject: path afterDelay: 0.5];
		}
		
		[[NSApp delegate] setGamesFolderPath: path];
	}
	
	//Restore the game folder dropdown to the first item, which is the games folder representation
	[[self gamesFolderSelector] selectItemAtIndex: 0];
}

- (void) _addSampleGamesToPath: (NSString *)path
{
	//As this is a time-consuming operation, show our progress indicator
	[self setProcessingGamesFolder: YES];
	[[NSApp delegate] addSampleGamesToPath: path];
	[self setProcessingGamesFolder: NO];
}

@end
