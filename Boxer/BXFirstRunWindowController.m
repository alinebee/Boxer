/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
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
@synthesize gamesFolderSelector = _gamesFolderSelector;
@synthesize addSampleGamesToggle = _addSampleGamesToggle;
@synthesize useShelfAppearanceToggle = _useShelfAppearanceToggle;

+ (id) controller
{
	static id singleton = nil;
	
	if (!singleton) singleton = [[self alloc] initWithWindowNibName: @"FirstRunWindow"];
	return singleton;
}

- (void) dealloc
{	
    self.gamesFolderSelector = nil;
    self.addSampleGamesToggle = nil;
    self.useShelfAppearanceToggle = nil;
	
	[super dealloc];
}

- (void) awakeFromNib
{
	//Empty the placeholder items first
	NSMenu *menu = self.gamesFolderSelector.menu;
	NSUInteger startOfOptions	= [menu indexOfItemWithTag: BXGamesFolderSelectorStartOfOptionsTag];
	NSUInteger endOfOptions		= [menu indexOfItemWithTag: BXGamesFolderSelectorEndOfOptionsTag];
	NSRange optionRange			= NSMakeRange(startOfOptions, endOfOptions - startOfOptions);

	for (NSMenuItem *oldItem in [menu.itemArray subarrayWithRange: optionRange])
		[menu removeItem: oldItem];
	
	
	//Now populate the menu with new items for each default path
	NSArray *defaultPaths = [BXAppController defaultGamesFolderPaths];
	
	NSUInteger insertionPoint = startOfOptions;
	
	for (NSString *path in defaultPaths)
	{
		NSMenuItem *item = [self _folderItemForPath: path];
		[menu insertItem: item atIndex: insertionPoint++];
	}
	
	[self.gamesFolderSelector selectItemAtIndex: 0];	
}

- (NSMenuItem *) _folderItemForPath: (NSString *)path
{
	NSValueTransformer *pathTransformer = [NSValueTransformer valueTransformerForName: @"BXIconifiedGamesFolderPath"];
	
	NSMenuItem *item = [[NSMenuItem alloc] init];
	item.representedObject = path;
    item.attributedTitle = [pathTransformer transformedValue: path];
	
	return [item autorelease];
}

- (void) showWindow: (id)sender
{
	[super showWindow: self];
	[NSApp runModalForWindow: self.window];
}

- (void) showWindowWithTransition: (id)sender
{
#ifdef USE_PRIVATE_APIS
	[[self window] revealWithTransition: CGSFlip
							  direction: CGSUp
							   duration: 0.5
						   blockingMode: NSAnimationNonblocking];
#else
    [self.window fadeInWithDuration: 0.5];
#endif
    
	[self showWindow: sender];
}

- (void) hideWindowWithTransition: (id)sender
{
#ifdef USE_PRIVATE_APIS
	[self.window hideWithTransition: CGSFlip
                          direction: CGSDown
                           duration: 0.5
                       blockingMode: NSAnimationBlocking];
#else
    [self.window fadeOutWithDuration: 0.5];
#endif
	
	[self.window close];
}
	
- (void) windowWillClose: (NSNotification *)notification
{
	if ([NSApp modalWindow] == self.window) [NSApp stopModal];
}

- (IBAction) makeGamesFolder: (id)sender
{	
	NSString *path = self.gamesFolderSelector.selectedItem.representedObject;
	
	BOOL applyShelfAppearance = self.useShelfAppearanceToggle.state;
	BOOL addSampleGames = self.addSampleGamesToggle.state;
    
    NSError *folderError = nil;
    
    BOOL assigned = [[NSApp delegate] assignGamesFolderPath: path
                                            withSampleGames: addSampleGames
                                            shelfAppearance: applyShelfAppearance
                                            createIfMissing: YES
                                                      error: &folderError];
    
    //If we failed to assign the folder for some reason,
    //present the error to the user and bail out
    if (!assigned && folderError)
    {
        [self presentError: folderError
            modalForWindow: self.window
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
            [self.window close];
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
	
    openPanel.delegate = self;
    openPanel.canCreateDirectories = YES;
    openPanel.canChooseDirectories = YES;
    openPanel.canChooseFiles = NO;
    openPanel.treatsFilePackagesAsDirectories = NO;
    openPanel.allowsMultipleSelection = NO;
    
    openPanel.directoryURL = [NSURL fileURLWithPath: NSHomeDirectory()];
    
    openPanel.prompt = NSLocalizedString(@"Select", @"Button label for Open panels when selecting a folder.");
    openPanel.message = NSLocalizedString(@"Select a folder in which to keep your DOS games:",
                                          @"Help text shown at the top of choose-a-games-folder panel.");
	
    [openPanel beginSheetModalForWindow: self.window completionHandler: ^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton)
        {
            NSURL *chosenURL = openPanel.URL;
            [self chooseGamesFolderWithURL: chosenURL];
        }
        else
        {
            [self.gamesFolderSelector selectItemAtIndex: 0];
        }
    }];
}

//Delegate validation method for 10.6 and above.
- (BOOL) panel: (id)openPanel validateURL: (NSURL *)URL error: (NSError **)outError
{
	NSString *path = URL.path;
	return [[NSApp delegate] validateGamesFolderPath: &path error: outError];
}

- (void) chooseGamesFolderWithURL: (NSURL *)URL
{
    NSString *path = URL.path;
    
    //Look for an existing menu item with that path
    NSInteger itemIndex = [self.gamesFolderSelector indexOfItemWithRepresentedObject: path];
    if (itemIndex == -1)
    {
        //This program is not yet in the menu: add a new item for it and use its new index
        NSMenuItem *item = [self _folderItemForPath: path];
        
        NSMenu *menu = self.gamesFolderSelector.menu;
        itemIndex = [menu indexOfItemWithTag: BXGamesFolderSelectorEndOfOptionsTag];
        [menu insertItem: item atIndex: itemIndex];
    }
    
    [self.gamesFolderSelector selectItemAtIndex: itemIndex];
}

@end