/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXFirstRunWindowController.h"
#import "NSWindow+BXWindowEffects.h"
#import "BXAppController+BXGamesFolder.h"
#import "BXValueTransformers.h"
#import "BXAppKitVersionHelpers.h"


//Used to determine where to fill the games folder selector with suggested locations

enum {
	BXGamesFolderSelectorStartOfOptionsTag = 1,
	BXGamesFolderSelectorEndOfOptionsTag = 2
};

@interface BXFirstRunWindowController ()

//Generates a new menu item representing the specified path,
//ready for insertion into the games folder selector.
- (NSMenuItem *) _folderItemForPath: (NSString *)path;

@end


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
	//Empty the placeholder items first
	NSMenu *menu = [gamesFolderSelector menu];
	NSUInteger startOfOptions	= [menu indexOfItemWithTag: BXGamesFolderSelectorStartOfOptionsTag];
	NSUInteger endOfOptions		= [menu indexOfItemWithTag: BXGamesFolderSelectorEndOfOptionsTag];
	NSRange optionRange			= NSMakeRange(startOfOptions, endOfOptions - startOfOptions);

	for (NSMenuItem *oldItem in [[menu itemArray] subarrayWithRange: optionRange])
		[menu removeItem: oldItem];
	
	
	//Now populate the menu with new items for each default path
	NSArray *defaultPaths = [BXAppController defaultGamesFolderPaths];
	
	NSUInteger insertionPoint = startOfOptions;
	
	for (NSString *path in defaultPaths)
	{
		NSMenuItem *item = [self _folderItemForPath: path];
		[menu insertItem: item atIndex: insertionPoint++];
	}
	
	[gamesFolderSelector selectItemAtIndex: 0];	
}

- (NSMenuItem *) _folderItemForPath: (NSString *)path
{
	NSValueTransformer *pathTransformer = [NSValueTransformer valueTransformerForName: @"BXIconifiedGamesFolderPath"];
	
	NSMenuItem *item = [[NSMenuItem alloc] init];
	[item setRepresentedObject: path];
	
	[item setAttributedTitle: [pathTransformer transformedValue: path]];
	
	return [item autorelease];
}

- (void) showWindow: (id)sender
{
	[super showWindow: self];
	[NSApp runModalForWindow: [self window]];
}

- (void) showWindowWithTransition: (id)sender
{
#ifdef USE_PRIVATE_APIS
	[[self window] revealWithTransition: CGSFlip
							  direction: CGSUp
							   duration: 0.5
						   blockingMode: NSAnimationNonblocking];
#else
    [[self window] fadeInWithDuration: 0.5];
#endif
    
	[self showWindow: sender];
}

- (void) hideWindowWithTransition: (id)sender
{
#ifdef USE_PRIVATE_APIS
	[[self window] hideWithTransition: CGSFlip
							direction: CGSDown
							 duration: 0.5
						 blockingMode: NSAnimationBlocking];
#else
    [[self window] fadeOutWithDuration: 0.5];
#endif
	
	[[self window] close];
}
	
- (void) windowWillClose: (NSNotification *)notification
{
	if ([NSApp modalWindow] == [self window]) [NSApp stopModal];
}

- (IBAction) makeGamesFolder: (id)sender
{	
	NSString *path = [[gamesFolderSelector selectedItem] representedObject];
	
	
	BOOL applyShelfAppearance = (BOOL)[useShelfAppearanceToggle state];
	BOOL addSampleGames = [addSampleGamesToggle state];
    
    NSError *folderError = nil;
    
    BOOL assigned = [[NSApp delegate] assignGamesFolderPath: path
                                            withSampleGames: addSampleGames
                                            importerDroplet: YES
                                            shelfAppearance: applyShelfAppearance
                                            createIfMissing: YES
                                                      error: &folderError];
    
    //If we failed to assign the folder for some reason,
    //present the error to the user and bail out
    if (!assigned && folderError)
    {
        [self presentError: folderError
            modalForWindow: [self window]
                  delegate: nil
        didPresentSelector: NULL
               contextInfo: NULL];
        
        return;
    }
    //Otherwise, close the first-run window and let the app move on.
    else
    {
        //Lion's own window transitions will interfere with our own, so leave them out.
        if (isRunningOnLionOrAbove())
        {
            [[self window] close];
        }
        else
        {
            [self hideWindowWithTransition: self];
        }
    }
}

- (IBAction) showGamesFolderChooser: (id)sender
{	
	//NOTE: normally our go-to guy for this is BXGamesFolderPanelController,
	//but he insists on asking about sample games and creating the game folder
	//end of the process. We only want to add the chosen location to the list,
	//and will create the folder when the user confirms.
	
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	
	[openPanel setCanCreateDirectories: YES];
	[openPanel setCanChooseDirectories: YES];
	[openPanel setCanChooseFiles: NO];
	[openPanel setTreatsFilePackagesAsDirectories: NO];
	[openPanel setAllowsMultipleSelection: NO];
	[openPanel setDelegate: self];
	
	[openPanel setPrompt: NSLocalizedString(@"Select", @"Button label for Open panels when selecting a folder.")];
	[openPanel setMessage: NSLocalizedString(@"Select a folder in which to keep your DOS games:",
											 @"Help text shown at the top of choose-a-games-folder panel.")];
	
	[openPanel beginSheetForDirectory: NSHomeDirectory()
								 file: nil
								types: nil
					   modalForWindow: [self window]
						modalDelegate: self
					   didEndSelector: @selector(setChosenGamesFolder:returnCode:contextInfo:)
						  contextInfo: NULL];
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
		NSMenuItem *item = [self _folderItemForPath: path];
		
		NSMenu *menu = [gamesFolderSelector menu];
		NSUInteger insertionPoint = [menu indexOfItemWithTag: BXGamesFolderSelectorEndOfOptionsTag];
		[menu insertItem: item atIndex: insertionPoint];
		[gamesFolderSelector selectItemAtIndex: insertionPoint];
	}
	else
	{
		[gamesFolderSelector selectItemAtIndex: 0];
	}
}

@end