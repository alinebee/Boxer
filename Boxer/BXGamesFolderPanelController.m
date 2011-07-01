/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXGamesFolderPanelController.h"
#import "BXAppController+BXGamesFolder.h"

@implementation BXGamesFolderPanelController
@synthesize copySampleGamesToggle, useShelfAppearanceToggle;

+ (id) controller
{
	static BXGamesFolderPanelController *singleton = nil;
	if (!singleton) singleton = [[self alloc] initWithNibName: @"GamesFolderPanelOptions" bundle: nil];
	return singleton;
}

- (void) dealloc
{
	[self setCopySampleGamesToggle: nil], copySampleGamesToggle = nil;
	[self setUseShelfAppearanceToggle: nil], useShelfAppearanceToggle = nil;
	[super dealloc];
}

- (void) showGamesFolderPanelForWindow: (NSWindow *)window
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
		//If no folder yet exists, default to the home directory
		parentFolderPath = NSHomeDirectory();
		currentFolderName = nil;
	}
	
	[openPanel setCanCreateDirectories: YES];
	[openPanel setCanChooseDirectories: YES];
	[openPanel setCanChooseFiles: NO];
	[openPanel setTreatsFilePackagesAsDirectories: NO];
	[openPanel setAllowsMultipleSelection: NO];
	
	[openPanel setAccessoryView: [self view]];
	[openPanel setDelegate: self];
	
	[openPanel setPrompt: NSLocalizedString(@"Select", @"Button label for Open panels when selecting a folder.")];
	[openPanel setMessage: NSLocalizedString(@"Select a folder in which to keep your DOS games:",
											 @"Help text shown at the top of choose-a-games-folder panel.")];
	
	
	//Set the initial state of the shelf-appearance toggle to match the current preference setting
	[[self useShelfAppearanceToggle] setState: [[NSApp delegate] appliesShelfAppearanceToGamesFolder]];
	
	if (window)
	{
		[openPanel beginSheetForDirectory: parentFolderPath
									 file: currentFolderName
									types: nil
						   modalForWindow: window
							modalDelegate: self
						   didEndSelector: @selector(setChosenGamesFolder:returnCode:contextInfo:)
							  contextInfo: nil];
	}
	else
	{
		NSInteger returnCode = [openPanel runModalForDirectory: parentFolderPath
														  file: currentFolderName
														 types: nil];
		
		[self setChosenGamesFolder: openPanel returnCode: returnCode contextInfo: nil];
	}
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

//Delegate validation method for 10.6 and above.
- (BOOL) panel: (id)openPanel validateURL: (NSURL *)url error: (NSError **)outError
{
	NSString *path = [url path];
	return [[NSApp delegate] validateGamesFolderPath: &path error: outError];
}

//Delegate validation method for 10.5. Will be ignored on 10.6 and above.
- (BOOL) panel: (NSOpenPanel *)openPanel isValidFilename: (NSString *)path
{
	NSError *validationError = nil;
	BOOL isValid = [[NSApp delegate] validateGamesFolderPath: &path error: &validationError];
	if (!isValid)
	{
		[openPanel presentError: validationError
				 modalForWindow: openPanel
					   delegate: nil
			 didPresentSelector: NULL
					contextInfo: NULL];
	}
	return isValid;
}

- (void) setChosenGamesFolder: (NSOpenPanel *)openPanel
				   returnCode: (int)returnCode
				  contextInfo: (void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		NSString *path = [[openPanel URL] path];
		BXAppController *controller = [NSApp delegate];
		BOOL addSampleGames		= [[self copySampleGamesToggle] state];
		BOOL useShelfAppearance	= [[self useShelfAppearanceToggle] state];
		
		[[NSApp delegate] setAppliesShelfAppearanceToGamesFolder: useShelfAppearance];
		
		[controller assignGamesFolderPath: path
						  withSampleGames: addSampleGames
						  importerDroplet: YES
						  shelfAppearance: BXShelfAuto];
	}
}

@end