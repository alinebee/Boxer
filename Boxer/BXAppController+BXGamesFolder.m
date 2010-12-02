/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXAppController+BXGamesFolder.h"

#import "NDAlias+AliasFile.h"
#import "Finder.h"
#import "NSWorkspace+BXIcons.h"
#import "BXPathEnumerator.h"
#import "BXGamesFolderPanelController.h"
#import "BXCoverArt.h"


#pragma mark -
#pragma mark Private method declarations

@interface BXAppController ()

//Callback for the 'we-couldnt-find-your-games-folder sheet.
- (void) _gamesFolderPromptDidEnd: (NSAlert *)alert
					   returnCode: (NSInteger)returnCode
						   window: (NSWindow *)window;

@end




@implementation BXAppController (BXGamesFolder)

+ (NSArray *) defaultGamesFolderPaths
{
	NSArray *paths = nil;
	if (!paths)
	{
		NSString *defaultName = NSLocalizedString(@"DOS Games", @"The default name for the games folder.");
	
		NSString *homePath		= NSHomeDirectory();
		NSString *appPath		= [NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSLocalDomainMask, YES) objectAtIndex: 0];
		//NSString *userAppPath	= [NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSUserDomainMask, YES) objectAtIndex: 0];
		
		paths = [[NSArray alloc] initWithObjects:
				 [homePath stringByAppendingPathComponent: defaultName],
				 [appPath stringByAppendingPathComponent: defaultName],
				 //[userAppPath stringByAppendingPathComponent: defaultName],
				 nil];
	}

	return paths;
}

+ (NSSet *) keyPathsForValuesAffectingGamesFolderChosen
{
	return [NSSet setWithObject: @"gamesFolderPath"];
}

- (BOOL) gamesFolderChosen
{
	return [[NSUserDefaults standardUserDefaults] dataForKey: @"gamesFolder"] != nil;
}


- (NSString *) gamesFolderPath
{
	//Load the games folder path from our preferences alias the first time we need it
	if (!gamesFolderPath)
	{
		NSData *aliasData = [[NSUserDefaults standardUserDefaults] dataForKey: @"gamesFolder"];
		
		if (aliasData)
		{
			NDAlias *alias = [NDAlias aliasWithData: aliasData];
			gamesFolderPath = [[alias path] copy];
			
			//If the alias was updated while resolving it because the target had moved,
			//then re-save the new alias data
			if ([alias changed])
			{
				[[NSUserDefaults standardUserDefaults] setObject: [alias data] forKey: @"gamesFolder"];
			}
		}
		else
		{
			//If no games folder has been set yet, try and import it now from Boxer 0.8x.
			NSString *oldPath = [self oldGamesFolderPath];
			if (oldPath) [self importOldGamesFolderFromPath: oldPath];
		}
	}
	return gamesFolderPath;
}

- (void) setGamesFolderPath: (NSString *)newPath
{
	if (![gamesFolderPath isEqualToString: newPath])
	{
		[gamesFolderPath release];
		gamesFolderPath = [newPath copy];
		
		if (newPath)
		{
			//Store the new path in the preferences as an alias, so that users can move it around.
			NDAlias *alias = [NDAlias aliasWithPath: newPath];
			[[NSUserDefaults standardUserDefaults] setObject: [alias data] forKey: @"gamesFolder"];
		}
	}
}

- (void) assignGamesFolderPath: (NSString *)newPath
			   withSampleGames: (BOOL)addSampleGames
			   importerDroplet: (BOOL)addImporterDroplet
			   shelfAppearance: (BXShelfAppearance)applyShelfAppearance
{
	if (applyShelfAppearance == BXShelfAuto)
	{
		applyShelfAppearance = [self appliesShelfAppearanceToGamesFolder];
	}
	else
	{
		[self setAppliesShelfAppearanceToGamesFolder: (BOOL)applyShelfAppearance];
	}

	
	if (applyShelfAppearance)
		[self applyShelfAppearanceToPath: newPath switchToShelfMode: YES];
	
	if (addSampleGames)			[self addSampleGamesToPath: newPath];
	if (addImporterDroplet)		[self addImporterDropletToPath: newPath];
	
	//Set the actual games folder last, so that any icon changes from
	//applyShelfAppearanceToPath:switchToShelfMode will get picked up
	[self setGamesFolderPath: newPath];
}

- (BOOL) importOldGamesFolderFromPath: (NSString *)path
{
	NSFileManager *manager = [NSFileManager defaultManager];
	if ([manager fileExistsAtPath: path])
	{
		[self freshenImporterDropletAtPath: path addIfMissing: YES];
		
		NSString *backgroundPath = [path stringByAppendingPathComponent: @".background"];
		//Check if the old path has a .background folder: if so,
		//then automatically apply the games-folder appearance.
		if ([manager fileExistsAtPath: backgroundPath])
		{
			[self setAppliesShelfAppearanceToGamesFolder: YES];
			[self applyShelfAppearanceToPath: path switchToShelfMode: NO];
		}
		
		//Set the actual games folder last, so that any icon changes from
		//applyShelfAppearanceToPath:switchToShelfMode will get picked up
		[self setGamesFolderPath: path];
		
		return YES;
	}
	return NO;
}

+ (NSSet *) keyPathsForValuesAffectingGamesFolderIcon
{
	return [NSSet setWithObjects: @"gamesFolderPath", @"appliesShelfAppearanceToGamesFolder", nil];
}

- (NSImage *) gamesFolderIcon
{
	NSImage *icon = nil;
	NSString *path = [self gamesFolderPath];
	if (path) icon = [[NSWorkspace sharedWorkspace] iconForFile: path];
	//If no games folder has been set, or the path couldn't be found, then fall back on our default icon
	if (!icon) icon = [NSImage imageNamed: @"gamefolder"];
	
	return icon;
}

- (NSString *) oldGamesFolderPath
{
	//Check for an alias reference from 0.8x versions of Boxer
	NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex: 0];
	NSString *oldAliasPath = [libraryPath stringByAppendingPathComponent: @"Preferences/Boxer/Default Folder"];
	
	//Resolve the previous games folder location from that alias
	NDAlias *alias = [NDAlias aliasWithContentsOfFile: oldAliasPath];
	return [alias path];
}

- (NSString *) fallbackGamesFolderPath
{
	return [NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES) objectAtIndex: 0];
}

- (void) applyShelfAppearanceToPath: (NSString *)path switchToShelfMode: (BOOL)switchMode
{	
	//Apply our shelf icon to the folder, if it doesn't have a custom icon of its own
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	
	if (![workspace fileHasCustomIcon: path])
	{
		NSImage *image = [NSImage imageNamed: @"gamefolder"];
		[workspace setIcon: image forFile: path options: 0];
	}
	
	//Now apply the icon mode appearance to the folder's Finder window
	
	NSURL *folderURL = [NSURL fileURLWithPath: path];
	
	//Detect which version of Finder is running, and switch the background image we use accordingly
	//(Leopard has different icon-view spacing than Snow Leopard)
	
	FinderApplication *finder = [SBApplication applicationWithBundleIdentifier: @"com.apple.finder"];
	
	BOOL isLeopardFinder = [[self class] isRunningOnLeopard];
	
	NSString *backgroundImageResource = (isLeopardFinder) ? @"ShelvesForLeopard" : @"ShelvesForSnowLeopard";
	
	NSURL *backgroundImageURL = [NSURL fileURLWithPath: [[NSBundle mainBundle] pathForImageResource: backgroundImageResource]];
	
	//Go go Scripting Bridge
	FinderFolder *folder			= [[finder folders] objectAtLocation: folderURL];
	FinderFile *backgroundPicture	= [[finder files] objectAtLocation: backgroundImageURL];
	
	//IMPLEMENTATION NOTE: [folder containerWindow] returns an SBObject instead of a FinderWindow.
	//So to actually DO anything with that window, we need to retrieve the value manually instead.
	//Furthermore, [FinderFinderWindow class] doesn't exist at compile time, so we need to retrieve
	//THAT at runtime too.
	//FFFFUUUUUUUUUCCCCCCCCKKKK AAAAAPPPPLLLLEEESSCCRRRIIPPPPTTTT.
	FinderFinderWindow *window = (FinderFinderWindow *)[folder propertyWithClass: NSClassFromString(@"FinderFinderWindow") code: (AEKeyword)'cwnd'];
	
	FinderIconViewOptions *options = window.iconViewOptions;
	
	options.textSize			= 12;
	options.iconSize			= 128;
	options.backgroundPicture	= backgroundPicture;
	options.labelPosition		= FinderEposBottom;
	options.showsItemInfo		= NO;
	if (options.arrangement == FinderEarrNotArranged)
		options.arrangement		= FinderEarrArrangedByName;
	
	if (switchMode) window.currentView = FinderEcvwIconView;
}

- (void) removeShelfAppearanceFromPath: (NSString *)path
{
	NSURL *folderURL = [NSURL fileURLWithPath: path];
	NSURL *parentFolderURL = [NSURL fileURLWithPath: [path stringByDeletingLastPathComponent]];
	
	FinderApplication *finder	= [SBApplication applicationWithBundleIdentifier: @"com.apple.finder"];
	FinderFolder *folder		= [[finder folders] objectAtLocation: folderURL];
	FinderFolder *parentFolder	= [[finder folders] objectAtLocation: parentFolderURL];
	
	//To reset the window appearance, copy its properties from its parent folder
	Class windowClass = NSClassFromString(@"FinderFinderWindow");
	AEKeyword propertyCode = (AEKeyword)'cwnd';
	FinderFinderWindow *window = (FinderFinderWindow *)[folder propertyWithClass: windowClass code: propertyCode];
	FinderFinderWindow *parentWindow = (FinderFinderWindow *)[parentFolder propertyWithClass: windowClass code: propertyCode];
	
	FinderIconViewOptions *options = window.iconViewOptions;
	FinderIconViewOptions *parentOptions = parentWindow.iconViewOptions;
	
	options.iconSize		= parentOptions.iconSize;
	options.backgroundColor	= parentOptions.backgroundColor;
	options.textSize		= parentOptions.textSize;
	options.labelPosition	= parentOptions.labelPosition;
	options.showsItemInfo	= parentOptions.showsItemInfo;
}

- (BOOL) appliesShelfAppearanceToGamesFolder
{
	return [[NSUserDefaults standardUserDefaults] boolForKey: @"applyShelfAppearance"];
}

- (void) setAppliesShelfAppearanceToGamesFolder: (BOOL)flag
{
	[[NSUserDefaults standardUserDefaults] setBool: flag forKey: @"applyShelfAppearance"];
}

- (void) addSampleGamesToPath: (NSString *)path
{
	NSString *sourcePath = [[NSBundle mainBundle] pathForResource: @"Sample Games" ofType: nil];
	
	BXSampleGamesCopy *copyOperation = [[BXSampleGamesCopy alloc] initFromPath: sourcePath
																		toPath: path];
	
	[generalQueue addOperation: copyOperation];
	[copyOperation release];
}


- (void) promptForMissingGamesFolderInWindow: (NSWindow *)window
{
	NSAlert *alert = [[NSAlert alloc] init];
	[alert setMessageText: NSLocalizedString(@"Boxer can no longer find your games folder.",
											 @"Bold message shown in alert when Boxer cannot find the user’s games folder at startup.")];
	
	[alert setInformativeText: NSLocalizedString(@"Make sure the disk containing your games folder is connected.",
												 @"Explanatory text shown in alert when Boxer cannot find the user’s games folder at startup.")];
	
	[alert addButtonWithTitle: NSLocalizedString(@"Locate folder…",
												 @"Button to display a file open panel to choose a new location for the games folder.")];
	
	[alert addButtonWithTitle: NSLocalizedString(@"Create folder…",
												 @"Button to automatically create a new games folder in the default location.")];
	
	[[alert addButtonWithTitle: NSLocalizedString(@"Cancel",
												  @"Button to cancel without making a new games folder.")] setKeyEquivalent: @"\e"];
	
	if (window)
	{
		[alert beginSheetModalForWindow: window
						  modalDelegate: self
						 didEndSelector: @selector(_gamesFolderPromptDidEnd:returnCode:window:)
							contextInfo: window];
	}
	else
	{
		NSInteger returnCode = [alert runModal];
		[self _gamesFolderPromptDidEnd: alert returnCode: returnCode window: nil];
	}
}

- (void) _gamesFolderPromptDidEnd: (NSAlert *)alert
					   returnCode: (NSInteger)returnCode
						   window: (NSWindow *)window
{
	[[alert window] close];
	switch(returnCode)
	{
		case NSAlertFirstButtonReturn:
			[[BXGamesFolderPanelController controller] showGamesFolderPanelForWindow: window];
			break;
		case NSAlertSecondButtonReturn:
			//This will run modally, after which we can reveal the games folder it has made
			[self orderFrontFirstRunPanel: self];
			if ([self gamesFolderPath]) [self revealGamesFolder: self];
			break;
	}
}

- (void) addImporterDropletToPath: (NSString *)folderPath
{
	return [self freshenImporterDropletAtPath: folderPath addIfMissing: YES];
}

- (void) freshenImporterDropletAtPath: (NSString *)folderPath addIfMissing: (BOOL)addIfMissing
{
	NSString *dropletPath = [[NSBundle mainBundle] pathForResource: @"Game Importer Droplet" ofType: @"app"];
	
	if (dropletPath && folderPath)
	{
		BXHelperAppCheck *checkOperation = [[BXHelperAppCheck alloc] initWithTargetPath: folderPath
																		   forAppAtPath: dropletPath];
		[checkOperation setAddIfMissing: addIfMissing];
		
		//Cancel any currently-active check for the droplet
		for (NSOperation *operation in [[self generalQueue] operations])
		{
			if ([operation isKindOfClass: [BXHelperAppCheck class]] &&
				[[(BXHelperAppCheck *)operation appPath] isEqualToString: dropletPath]) [operation cancel];
		}
		
		[generalQueue addOperation: checkOperation];
		[checkOperation release];
	}
}

- (IBAction) revealGamesFolder: (id)sender
{
	NSString *path = [self gamesFolderPath];
	BOOL revealed = NO;
	
	if (path) revealed = [self revealPath: path];
	
	if (revealed)
	{
		//Each time after we open the game folder, reapply the shelf appearance.
		//We do this because Finder can sometimes 'lose' the appearance.
		//IMPLEMENTATION NOTE: we now do this after the folder has opened,
		//to avoid a delay while applying the style.
		if ([self appliesShelfAppearanceToGamesFolder])
		{
			[self applyShelfAppearanceToPath: path switchToShelfMode: NO];
		}
		
		//Also check that there's an up-to-date game importer droplet in the folder.
		[self freshenImporterDropletAtPath: path addIfMissing: NO];
	}

	else if (![self gamesFolderChosen])
	{
		//If the user hasn't chosen a games folder location yet, then show them
		//the first-run panel to choose one, then reveal the new folder afterwards (if one was created).
		[self orderFrontFirstRunPanel: self];
		if ([self gamesFolderPath]) [self revealGamesFolder: self];
	}
	else
	{
		//If we do have a games folder path but can't open it, then it was probably
		//deleted behind our backs, so prompt the user to relocate it.
		NSWindow *window = [sender respondsToSelector: @selector(window)] ? [sender window] : nil;
		[self promptForMissingGamesFolderInWindow: window];
	}
}
@end


@implementation BXSampleGamesCopy
@synthesize sourcePath, targetPath;

- (id) initFromPath: (NSString *)source toPath: (NSString *)target
{
	if ((self = [super init]))
	{
		[self setSourcePath: source];
		[self setTargetPath: target];
		manager = [[NSFileManager alloc] init];
		workspace = [[NSWorkspace alloc] init];
	}
	return self;
}

- (void) dealloc
{
	[self setSourcePath: nil], [sourcePath release];
	[self setTargetPath: nil], [targetPath release];
	[manager release], manager = nil;
	[workspace release], workspace = nil;
	[super dealloc];
}

- (void) main
{
	if ([self isCancelled]) return;
	
	NSDictionary *attrs	= [NSDictionary dictionaryWithObject: [NSNumber numberWithBool: YES]
													  forKey: NSFileExtensionHidden];
	
	for (NSString *gamePath in [manager contentsOfDirectoryAtPath: sourcePath error: NULL])
	{
		if ([self isCancelled]) return;
		
		NSString *gameSource		= [sourcePath stringByAppendingPathComponent: gamePath];
		NSString *gameDestination	= [targetPath stringByAppendingPathComponent: gamePath];
		
		//If the folder already has a game of that name, don't copy the game
		//(we don’t want to overwrite someone's savegames)
		if (![manager fileExistsAtPath: gameDestination])
		{
			[manager copyItemAtPath: gameSource toPath: gameDestination error: NULL];
			[manager setAttributes: attrs ofItemAtPath: gameDestination error: NULL];
			
			NSString *gameName = [[gamePath lastPathComponent] stringByDeletingPathExtension];
			NSString *iconPath = [[NSBundle mainBundle] pathForResource: gameName
																 ofType: @"jpg"
															inDirectory: @"Sample Game Icons"];
			
			//Generate a cover art image from this icon (cheaper than storing a full icns file)
			if (iconPath)
			{
				NSImage *image = [[NSImage alloc] initWithContentsOfFile: iconPath];
				if (image)
				{
					NSImage *iconForGame = [BXCoverArt coverArtWithImage: image];
					[workspace setIcon: iconForGame forFile: gameDestination options: 0];
				}
				[image release];
			}
		}
	}	
}

@end


@implementation BXHelperAppCheck
@synthesize targetPath, appPath, addIfMissing;

- (id) initWithTargetPath: (NSString *)pathToCheck forAppAtPath: (NSString *)pathToApp
{
	if ((self = [super init]))
	{
		[self setTargetPath: pathToCheck];
		[self setAppPath: pathToApp];
		manager = [[NSFileManager alloc] init];
	}
	return self;
}

- (void) dealloc
{
	[self setTargetPath: nil], [targetPath release];
	[self setAppPath: nil], [appPath release];
	[manager release], manager = nil;
	
	[super dealloc];
}

- (void) main
{
	//Bail out early if already cancelled
	if ([self isCancelled]) return;
	
	//Bail out early if we don't have the necessary paths
	if (!targetPath || !appPath) return;
	
	//Get the properties of the app for comparison
	NSBundle *app		= [NSBundle bundleWithPath: appPath];
	NSString *appName	= [[app objectForInfoDictionaryKey: @"CFBundleDisplayName"]
							stringByAppendingPathExtension: @"app"];
	
	NSString *appVersion	= [app objectForInfoDictionaryKey: (NSString *)kCFBundleVersionKey];
	NSString *appIdentifier = [app bundleIdentifier];
	
	BXPathEnumerator *enumerator = [BXPathEnumerator enumeratorAtPath: targetPath];
	[enumerator setSkipSubdirectories: YES];
	[enumerator setSkipPackageContents: YES];
	[enumerator setFileTypes: [NSSet setWithObject: @"com.apple.application"]];
	
	//Trawl through the games folder looking for apps with the same identifier
	for (NSString *filePath in enumerator)
	{
		//Bail out if we're cancelled
		if ([self isCancelled]) return;

		NSBundle *checkedApp = [NSBundle bundleWithPath: filePath];
		if ([[checkedApp bundleIdentifier] isEqualToString: appIdentifier])
		{
			//Check if the app is up-to-date: if not, replace it with our own app
			NSString *checkedAppVersion = [checkedApp objectForInfoDictionaryKey: (NSString *)kCFBundleVersionKey];
			if (NSOrderedAscending == [checkedAppVersion compare: appVersion options: NSNumericSearch])
			{
				BOOL deleted = [manager removeItemAtPath: filePath error: nil];
				if (deleted)
				{
					NSString *newPath = [[filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent: appName];
					[manager copyItemAtPath: appPath toPath: newPath error: nil];
				}
			}
			//Bail out once we've found a matching app
			return;
		}
	}
	
	//If we got this far, then we didn't find any droplet:
	//copy a new one into the target folder if desired
	if (addIfMissing)
	{
		NSString *newPath = [targetPath stringByAppendingPathComponent: appName];
		[manager copyItemAtPath: appPath toPath: newPath error: nil];
	}
}
@end