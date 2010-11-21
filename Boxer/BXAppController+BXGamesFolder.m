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


@implementation BXAppController (BXGamesFolder)

+ (BOOL) isLeopardFinder
{	
	//IMPLEMENTATION NOTE: we used to do this by checking the version of Finder itself;
	//however, this proved to be unreliable and extremely cumbersome. Now we just check
	//the version of OS X itself.
	SInt32 versionMajor = 10, versionMinor = 0;
	
	Gestalt(gestaltSystemVersionMajor, &versionMajor);
	Gestalt(gestaltSystemVersionMinor, &versionMinor);
	
	return versionMajor == 10 && versionMinor < 6;
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
	}
	return gamesFolderPath;
}

- (void) setGamesFolderPath: (NSString *)newPath
{
	if (![gamesFolderPath isEqualToString: newPath])
	{
		[gamesFolderPath release];
		gamesFolderPath = [newPath copy];
		
		//Store the new path in the preferences as an alias, so that users can move it around.
		NDAlias *alias = [NDAlias aliasWithPath: newPath];
		[[NSUserDefaults standardUserDefaults] setObject: [alias data] forKey: @"gamesFolder"];
		
		//Finally, check that the folder has an up-to-date importer droplet in it.
		[self checkForImporterDroplet];
	}
}

+ (NSSet *) keyPathsForValuesAffectingGamesFolderIcon
{
	return [NSSet setWithObject: @"gamesFolderPath"];
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
	
	BOOL isLeopardFinder = [[self class] isLeopardFinder];
	
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
	NSString *path = [self gamesFolderPath];
	
	if (path && [[NSFileManager defaultManager] fileExistsAtPath: path])
	{
		if (flag)
		{
			[self applyShelfAppearanceToPath: path switchToShelfMode: YES];
		}
		else
		{
			//Restore the folder to its unshelfed state
			[self removeShelfAppearanceFromPath: path];
		}		
	}
}

- (void) addSampleGamesToPath: (NSString *)path
{
	NSString *sampleGamesPath = [[NSBundle mainBundle] pathForResource: @"Sample Games" ofType: nil];
	
	NSFileManager *manager	= [NSFileManager defaultManager];
	NSWorkspace *workspace	= [NSWorkspace sharedWorkspace];
	NSDictionary *attrs		= [NSDictionary dictionaryWithObject: [NSNumber numberWithBool: YES]
														  forKey: NSFileExtensionHidden];
	
	for (NSString *gamePath in [manager contentsOfDirectoryAtPath: sampleGamesPath error: NULL])
	{
		NSString *sourcePath		= [sampleGamesPath stringByAppendingPathComponent: gamePath];
		NSString *destinationPath	= [path stringByAppendingPathComponent: gamePath];
		
		//If the folder already has a game of that name, don't copy the game (we don’t want to 
		if (![manager fileExistsAtPath: destinationPath])
		{
			[manager copyItemAtPath: sourcePath toPath: destinationPath error: NULL];
			
			[manager setAttributes: attrs ofItemAtPath: destinationPath error: NULL];
		
			NSString *gameName = [[gamePath lastPathComponent] stringByDeletingPathExtension];
			NSImage *iconForGame = [NSImage imageNamed: gameName];
			if (iconForGame) [workspace setIcon: iconForGame forFile: destinationPath options: 0];
		}
	}
}


- (void) checkForGamesFolder
{
	//Check at startup whether we have a games folder set
	if (![self gamesFolderPath])
	{
		//If no games folder has been set yet, try and import it from Boxer 0.8x.
		//IMPLEMENTATION NOTE: we confirm the absence of the user default before importing,
		//because gamesFolderPath could be nil if the folder was set but not currently
		//accessible (and we don't want to overwrite the setting if so.)
		if ([[NSUserDefaults standardUserDefaults] objectForKey: @"gamesFolder"] == nil)
		{
			NSFileManager *manager = [NSFileManager defaultManager];
			NSString *oldPath = [self oldGamesFolderPath];
			if (oldPath && [manager fileExistsAtPath: oldPath])
			{
				[self setGamesFolderPath: oldPath];
				
				NSString *backgroundPath = [oldPath stringByAppendingPathComponent: @".background"];
				//Check if the old path has a .background folder: if so,
				//then automatically apply the games-folder appearance.
				if ([manager fileExistsAtPath: backgroundPath])
				{
					[self setAppliesShelfAppearanceToGamesFolder: YES];
				}
			}
		}
		
		//If we couldn't import a games folder, then prompt the user to choose one
		//(or to reinsert the disk on which their games folder was stored)
		if (![self gamesFolderPath])
		{
			//TODO: show the games folder chooser here!
		}
	}
}

- (void) checkForImporterDroplet
{
	NSString *dropletPath = [[NSBundle mainBundle] pathForResource: @"Game Importer Droplet" ofType: @"app"];
	NSString *folderPath = [self gamesFolderPath];
	
	if (dropletPath && folderPath)
	{
		BXHelperAppCheck *checkOperation = [[BXHelperAppCheck alloc] initWithTargetPath: folderPath
																		   forAppAtPath: dropletPath];
		
		//Cancel any currently-active check for the droplet
		for (NSOperation *operation in [[self generalQueue] operations])
		{
			if ([operation isKindOfClass: [BXHelperAppCheck class]] &&
				[[(BXHelperAppCheck *)operation appPath] isEqualToString: dropletPath]) [operation cancel];
		}
		
		[generalQueue addOperation: checkOperation];
	}
}

- (IBAction) revealGamesFolder: (id)sender
{
	NSString *path = [self gamesFolderPath];
	if (path)
	{
		//If the sender is a button with an image, animate the opening from the button
		if ([sender respondsToSelector:@selector(cell)] && [[sender cell] image])
		{
			NSRect imageRect = [[sender cell] imageRectForBounds: [sender bounds]];
			
			NSWorkspace *ws = [NSWorkspace sharedWorkspace];
			//NOTE: the intended animation does not play, so this currently acts as if
			//NSWorkspace openFile: was called. It's unclear if this is being called
			//wrongly or if the documented behaviour is simply unimplemented.
			[ws openFile: path
			   fromImage: [[sender cell] image]
					  at: imageRect.origin
				  inView: sender];
		}
		else
		{
			[self revealPath: path];
		}
		
		//Each time after we open the game folder, reapply the shelf appearance.
		//We do this because Finder can sometimes 'lose' the appearance.
		//IMPLEMENTATION NOTE: we now do this after the folder has opened,
		//to avoid a delay while applying the style.
		if ([self appliesShelfAppearanceToGamesFolder])
		{
			[self applyShelfAppearanceToPath: path switchToShelfMode: NO];
		}
	}
}
@end



@implementation BXHelperAppCheck
@synthesize targetPath, appPath;

- (id) initWithTargetPath: (NSString *)pathToCheck forAppAtPath: (NSString *)pathToApp
{
	if ((self = [super init]))
	{
		[self setTargetPath: pathToCheck];
		[self setAppPath: pathToApp];
	}
	return self;
}

- (void) dealloc
{
	[self setTargetPath: nil], [targetPath release];
	[self setAppPath: nil], [appPath release];
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
	NSString *appName	= [[app objectForInfoDictionaryKey: @"CFBundleDisplayName"] stringByAppendingPathExtension: @"app"];
	
	NSString *appVersion	= [app objectForInfoDictionaryKey: (NSString *)kCFBundleVersionKey];
	NSString *appIdentifier = [app bundleIdentifier];
	
	NSFileManager *manager = [NSFileManager defaultManager];
	
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
	
	//If we got this far, then we didn't find any droplet: copy a new one into the target folder
	NSString *newPath = [targetPath stringByAppendingPathComponent: appName];
	[manager copyItemAtPath: appPath toPath: newPath error: nil];
}
@end