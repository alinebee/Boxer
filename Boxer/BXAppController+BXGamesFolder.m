/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXAppController+BXGamesFolder.h"
#import "BXAppController+BXSupportFiles.h"

#import "NDAlias+AliasFile.h"
#import "NSWorkspace+BXFileTypes.h"
#import "BXGamesFolderPanelController.h"

#import "BXShelfArt.h"
#import "NSImage+BXSaveImages.h"

#import "BXSampleGamesCopy.h"
#import "BXShelfAppearanceOperation.h"
#import "BXHelperAppCheck.h"
#import "NSString+BXPaths.h"
#import "BXAppKitVersionHelpers.h"

//For determining maximum Finder folder-background sizes
#import <OpenGL/OpenGL.h>
#import <OpenGL/CGLMacro.h>
#import <OpenGL/glu.h>


#pragma mark -
#pragma mark Error constants

NSString * const BXGamesFolderErrorDomain = @"BXGamesFolderErrorDomain";



#pragma mark -
#pragma mark Private method declarations

@interface BXAppController (BXGamesFolderPrivate)

//The maximum size of artwork to generate.
//This corresponds to Finder's own builtin max size, independent of hardware.
+ (NSSize) _maxArtworkSize;

//The size of shelf artwork to generate.
//This is dependent on the Finder version and the current graphics chipset.
- (NSSize) _shelfArtworkSize;

//Callback for the 'we-couldnt-find-your-games-folder' sheet.
- (void) _gamesFolderPromptDidEnd: (NSAlert *)alert
					   returnCode: (NSInteger)returnCode
						   window: (NSWindow *)window;

//Returns whether the specified path is a reserved system directory.
//Used by validateGamesFolderPath:error:
+ (BOOL) _isReservedPath: (NSString *)path;

@end




@implementation BXAppController (BXGamesFolder)


+ (NSArray *) defaultGamesFolderPaths
{
	static NSArray *paths = nil;
	if (!paths)
	{
		NSString *defaultName = NSLocalizedString(@"DOS Games", @"The default name for the games folder.");
        
		NSString *docsPath      = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex: 0];
		NSString *homePath		= NSHomeDirectory();
		NSString *appPath		= [NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSLocalDomainMask, YES) objectAtIndex: 0];
		NSString *userAppPath	= [NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSUserDomainMask, YES) objectAtIndex: 0];
		
		paths = [[NSArray alloc] initWithObjects:
				 [homePath stringByAppendingPathComponent: defaultName],
				 [docsPath stringByAppendingPathComponent: defaultName],
				 [userAppPath stringByAppendingPathComponent: defaultName],
				 [appPath stringByAppendingPathComponent: defaultName],
				 nil];
	}
    
	return paths;
}

+ (NSString *) preferredGamesFolderPath
{
    return [[self defaultGamesFolderPaths] objectAtIndex: 0];
}

+ (NSSet *) reservedPaths
{
	static NSMutableSet *reservedPaths = nil;
	if (!reservedPaths)
	{
		reservedPaths = [[NSMutableSet alloc] initWithObjects: NSHomeDirectory(), nil];
        
		[reservedPaths addObjectsFromArray: NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSAllDomainsMask, YES)];
		[reservedPaths addObjectsFromArray: NSSearchPathForDirectoriesInDomains(NSAllApplicationsDirectory, NSAllDomainsMask, YES)];
		[reservedPaths addObjectsFromArray: NSSearchPathForDirectoriesInDomains(NSAllLibrariesDirectory, NSAllDomainsMask, YES)];
		[reservedPaths addObjectsFromArray: NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSAllDomainsMask, YES)];
		[reservedPaths addObjectsFromArray: NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSAllDomainsMask, YES)];
		[reservedPaths addObjectsFromArray: NSSearchPathForDirectoriesInDomains(NSUserDirectory, NSAllDomainsMask, YES)];
#ifdef NSSharedPublicDirectory
		//10.6-only
		[reservedPaths addObjectsFromArray: NSSearchPathForDirectoriesInDomains(NSSharedPublicDirectory, NSAllDomainsMask, YES)];
#endif
	}
	return reservedPaths;
}


- (NSSize) _maxArtworkSize
{
	//4000 appears to be the upper bound for Finder background images
	//in Snow Leopard, regardless of OpenGL texture limits; backgrounds
	//larger than this will be shrunk by Finder to fit within 4000x4000,
	//with undesirable consequences.
	
	//(Leopard Finder doesn't seem to have this behaviour,
	//but 4000x4000 is a reasonable size for us to stop at anyway.)
	
	return NSMakeSize(4000, 4000);
}

- (NSSize) _shelfArtworkSize
{
	NSSize maxArtworkSize = [self _maxArtworkSize];
	
	//10.5 is happy with the largest image we can make.
	if (isRunningOnLeopard())
	{
		return maxArtworkSize;
	}
	else
	{
		//Snow Leopard's and Lion's Finder use OpenGL textures for 
		//rendering the window background, so we are limited by the
		//current renderer's maximum texture size.
		GLint maxTextureSize = 0;
		
		CGOpenGLDisplayMask displayMask = CGDisplayIDToOpenGLDisplayMask (CGMainDisplayID());
		CGLPixelFormatAttribute attrs[] = {kCGLPFADisplayMask, displayMask, 0};
		
		CGLPixelFormatObj pixelFormat = NULL;
		GLint numFormats = 0;
		CGLChoosePixelFormat(attrs, &pixelFormat, &numFormats);
		
		if (pixelFormat)
		{
			CGLContextObj testContext = NULL;
			
			CGLCreateContext(pixelFormat, NULL, &testContext);
			CGLDestroyPixelFormat(pixelFormat);
			
			if (testContext)
			{
				CGLContextObj cgl_ctx = testContext;
				
				//Just to be safe, check if rectangle textures are supported,
				//falling back on the square texture size otherwise
				const GLubyte *extensions = glGetString(GL_EXTENSIONS);
				BOOL supportsRectangleTextures = gluCheckExtension((const GLubyte *)"GL_ARB_texture_rectangle", extensions);
				
				GLenum textureSizeField = supportsRectangleTextures ? GL_MAX_RECTANGLE_TEXTURE_SIZE_ARB : GL_MAX_TEXTURE_SIZE;
				glGetIntegerv(textureSizeField, &maxTextureSize);
				
				CGLDestroyContext (testContext);
			}
		}
		
		//Crop the GL size to the maximum Finder background size
		//(see the note under +_maxArtworkSize for details)
		return NSMakeSize(MIN((CGFloat)maxTextureSize, maxArtworkSize.width),
						  MIN((CGFloat)maxTextureSize, maxArtworkSize.height));
	}
}


- (NSString *) shelfArtworkPath
{
	BOOL isLeopardFinder = isRunningOnLeopard();
	
	NSString *artworkFolderPath = [[self supportPathCreatingIfMissing: NO] stringByAppendingPathComponent: @"Shelf artwork"];
	NSString *artworkName = isLeopardFinder ? @"Leopard.jpg" : @"Snow Leopard.jpg";
	NSString *artworkPath = [artworkFolderPath stringByAppendingPathComponent: artworkName];
	
	//If there's no suitable artwork yet, then generate a new image
	NSFileManager *manager = [NSFileManager defaultManager];
	if (![manager fileExistsAtPath: artworkPath])
	{
		//Ensure the base folder exists
		BOOL folderCreated = [manager createDirectoryAtPath: artworkFolderPath
								withIntermediateDirectories: YES
												 attributes: nil
													  error: NULL];
		
		//Don't continue if folder creation failed for some reason
		if (!folderCreated) return nil;
		
		//Now, generate new artwork appropriate for the current Finder version
		NSSize artworkSize = [self _shelfArtworkSize];
		
		
		//If an appropriate size could not be determined, bail out
		if (NSEqualSizes(artworkSize, NSZeroSize)) return nil;
		
		NSString *shelfTemplate = isLeopardFinder ? @"ShelfTemplateLeopard" : @"ShelfTemplateSnowLeopard";
		
		BXShelfArt *shelfArt = [[BXShelfArt alloc] initWithSourceImage: [NSImage imageNamed: shelfTemplate]];
		
		NSImage *tiledShelf = [shelfArt tiledImageWithSize: artworkSize];
		
		[shelfArt release];
		
		
		NSDictionary *properties = [NSDictionary dictionaryWithObject: [NSNumber numberWithFloat: 1.0f] 
															   forKey: NSImageCompressionFactor];
		
		BOOL imageSaved = [tiledShelf saveToPath: artworkPath
										withType: NSJPEGFileType
									  properties: properties
										   error: NULL];
		
		//Bail out if the image could not be saved properly
		if (!imageSaved) return NO;
	}
	
	//If we got this far then we have a pre-existing or newly-generated shelf image at the specified path.
	return artworkPath;
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
			//If no games folder has been set yet, look for one from Boxer 0.8x.
			NSString *oldPath = [self oldGamesFolderPath];
            BOOL foundOldPath = NO;
			if (oldPath)
            {
                foundOldPath = [self importOldGamesFolderFromPath: oldPath error: nil];
            }
            
            //If that fails, try one of the default locations to see if a folder is there.
            if (!foundOldPath)
            {
                NSFileManager *manager = [[NSFileManager alloc] init];
                
                for (NSString *path in [[self class] defaultGamesFolderPaths])
                {
                    BOOL isDir;
                    if ([manager fileExistsAtPath: path isDirectory: &isDir] && isDir)
                    {
                        [self setGamesFolderPath: path];
                        break;
                    }
                }
                [manager release];
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
		
		if (newPath)
		{
			//Store the new path in the preferences as an alias, so that users can move it around.
			NDAlias *alias = [NDAlias aliasWithPath: newPath];
			[[NSUserDefaults standardUserDefaults] setObject: [alias data] forKey: @"gamesFolder"];
		}
	}
}

+ (BOOL) _isReservedPath: (NSString *)path
{
	//Reject reserved paths
	if ([[[self class] reservedPaths] containsObject: path]) return YES;
	
	//Reject paths located inside system library folders (though we allow them within the user's own Library folder)
	NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSAllLibrariesDirectory, NSLocalDomainMask | NSSystemDomainMask, YES);
	for (NSString *libraryPath in libraryPaths) if ([path isRootedInPath: libraryPath]) return YES;
	
	//Reject base home folder paths
	NSArray *userDirectoryPaths = NSSearchPathForDirectoriesInDomains(NSUserDirectory, NSAllDomainsMask, YES);
	NSString *parentPath = [path stringByDeletingLastPathComponent];
	for (NSString *userDirectoryPath in userDirectoryPaths) if ([parentPath isEqualToString: userDirectoryPath]) return YES;

	//If we got this far then it's not a recognised reserved path
	return NO;
}

- (BOOL) validateGamesFolderPath: (id *)ioValue error: (NSError **)outError
{
	NSString *path = *ioValue;
	
	//Accept nil paths, since these will clear the preference
	if (!path) return YES;
	
	path = [path stringByStandardizingPath];
	
	NSFileManager *manager = [NSFileManager defaultManager];
	if ([[self class] _isReservedPath: path])
	{
		if (outError)
		{
			NSString *descriptionFormat = NSLocalizedString(
				@"“%1$@” is a special OS X folder and not suitable for storing your DOS games.",
				@"Error message shown after choosing a reserved folder as the location for the DOS Games folder. %1$@ is the display name of the folder."
			);
			
			NSString *explanation = NSLocalizedString(
				@"Please create a subfolder, or choose a different folder you have created yourself.",
				@"Explanatory text for error message shown after failing to mount an image."
			);
			
			NSString *displayName			= [manager displayNameAtPath: path];
			if (!displayName) displayName	= [path lastPathComponent];
			
			NSString *description = [NSString stringWithFormat: descriptionFormat, displayName, nil];
					
			NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  description,	NSLocalizedDescriptionKey,
									  explanation,	NSLocalizedRecoverySuggestionErrorKey,
									  path,			NSFilePathErrorKey,
									  nil];
			
			*outError = [NSError errorWithDomain: BXGamesFolderErrorDomain
											code: BXGamesFolderPathInvalid
										userInfo: userInfo];
		}
		
		return NO;
	}
	//Warn if we do not have write permission to access that path
	else if (![manager isWritableFileAtPath: path])
	{
		if (outError)
		{
			NSString *descriptionFormat = NSLocalizedString(@"Boxer cannot write to the “%1$@” folder.",
															@"Error shown when chosen games folder was read-only. %1$@ is the name of the folder.");
			
			NSString *explanation = NSLocalizedString(@"Please check the file permissions, or choose a different folder.",
													  @"Explanatory text shown when chosen games folder was read-only.");
			
			NSString *displayName			= [manager displayNameAtPath: path];
			if (!displayName) displayName	= [path lastPathComponent];
			
			NSString *description = [NSString stringWithFormat: descriptionFormat, displayName, nil];
			
			NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  description, NSLocalizedDescriptionKey,
									  explanation, NSLocalizedRecoverySuggestionErrorKey,
									  path, NSFilePathErrorKey,
									  nil];
			
			*outError = [NSError errorWithDomain: NSCocoaErrorDomain
											code: NSFileWriteNoPermissionError
										userInfo: userInfo];
		}
		return NO;
	}
	
	//If we got this far,the path is OK 
	return YES;
}


- (BOOL) assignGamesFolderPath: (NSString *)path
			   withSampleGames: (BOOL)addSampleGames
			   importerDroplet: (BOOL)addImporterDroplet
			   shelfAppearance: (BXShelfAppearance)applyShelfAppearance
               createIfMissing: (BOOL)createIfMissing
                         error: (NSError **)outError
{
    NSAssert(path != nil, @"nil path provided to assignGamesFolderPath:withSampleGames:importerDroplet:shelfAppearance:createIfMissing:error:");
    
    NSFileManager *manager = [[[NSFileManager alloc] init] autorelease];
    
    if (![manager fileExistsAtPath: path])
    {
        //If we're allowed, create the folder if it's not there already.
        if (createIfMissing)
        {
            BOOL created = [manager createDirectoryAtPath: path
                              withIntermediateDirectories: YES
                                               attributes: nil
                                                    error: outError];
            
            if (!created) return NO;
        }
        //If we're not allowed, treat this as an error condition and bounce it back up.
        else
        {
            if (outError)
            {
                NSDictionary *userInfo = [NSDictionary dictionaryWithObject: path forKey: NSFilePathErrorKey];
                *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                                code: NSFileNoSuchFileError
                                            userInfo: userInfo];
            }
            return NO;
        }
    }
    
    //Verify that the path is acceptable to us.
    BOOL isValid = [self validateGamesFolderPath: &path error: outError];
    if (!isValid) return NO;
    
    //If we got this far, we can go ahead and assign this as our games folder path.
    //Apply the requested options now.
	if (applyShelfAppearance == BXShelfAuto)
	{
		applyShelfAppearance = [self appliesShelfAppearanceToGamesFolder];
	}
	else
	{
        //Update the option to reflect the shelf appearance requested.
		[self setAppliesShelfAppearanceToGamesFolder: (BOOL)applyShelfAppearance];
	}

	if (applyShelfAppearance)
    {
		[self applyShelfAppearanceToPath: path
                           andSubFolders: YES
                       switchToShelfMode: YES];
	}
    
	if (addSampleGames)			[self addSampleGamesToPath: path];
	if (addImporterDroplet)		[self addImporterDropletToPath: path];
	
	[self setGamesFolderPath: path];
    return YES;
}

- (BOOL) importOldGamesFolderFromPath: (NSString *)path error: (NSError **)outError
{
	NSFileManager *manager = [[[NSFileManager alloc] init] autorelease];
    BOOL isDir;
	if ([manager fileExistsAtPath: path isDirectory: &isDir] && isDir)
	{
		[self freshenImporterDropletAtPath: path addIfMissing: YES];
		
		//Check if the old path has a .background folder: if so,
		//then automatically apply the games-folder appearance.
		NSString *backgroundPath = [path stringByAppendingPathComponent: @".background"];
		if ([manager fileExistsAtPath: backgroundPath])
		{
			[self setAppliesShelfAppearanceToGamesFolder: YES];
			[self applyShelfAppearanceToPath: path andSubFolders: YES switchToShelfMode: NO];
		}
		
		[self setGamesFolderPath: path];
		
		return YES;
	}
    else
    {
        if (outError)
        {
			NSDictionary *userInfo = [NSDictionary dictionaryWithObject: path forKey: NSFilePathErrorKey];
			*outError = [NSError errorWithDomain: NSCocoaErrorDomain
											code: NSFileNoSuchFileError
										userInfo: userInfo];
        }
        return NO;
    }
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

- (void) applyShelfAppearanceToPath: (NSString *)path
					  andSubFolders: (BOOL)applyToSubFolders
				  switchToShelfMode: (BOOL)switchMode
{	
	//NOTE: if no shelf artwork could be found or generated, then bail out early
	NSString *backgroundImagePath = [self shelfArtworkPath];
	if (backgroundImagePath == nil) return;
	
	NSImage *folderIcon = [NSImage imageNamed: @"gamefolder"];
	
	BXShelfAppearanceApplicator *applicator = [[BXShelfAppearanceApplicator alloc] initWithTargetPath: path
																				  backgroundImagePath: backgroundImagePath
																								 icon: folderIcon];
	
	[applicator setAppliesToSubFolders: applyToSubFolders];
	[applicator setSwitchToIconView: switchMode];
	
	for (id operation in [[self generalQueue] operations])
	{
		//Check for other operations that are currently being performed on this path
		if ([operation respondsToSelector: @selector(targetPath)] && [[operation targetPath] isEqualToString: path])
		{
			//Cancel any currently-active shelf-appearance application or removal being applied to this path
			if ([operation isKindOfClass: [BXShelfAppearanceOperation class]]) [operation cancel];
			
			//For other types of operations, mark them as a dependency to avoid performing
			//many simultaneous file operations on the same location.
			//(Among other things this avoids concurrency problems with NSWorkspace,
			//which has thread-unsafe methods like -setIcon:forFile:options:)
			else [applicator addDependency: operation];
		}
	}
	
	[[self generalQueue] addOperation: applicator];
	[applicator release];
}

- (void) removeShelfAppearanceFromPath: (NSString *)path
						 andSubFolders: (BOOL)applyToSubFolders
{
	//Revert the folder's appearance to that of its parent folder
	NSString *parentPath = [path stringByDeletingLastPathComponent];
	
	BXShelfAppearanceRemover *remover = [[BXShelfAppearanceRemover alloc] initWithTargetPath: path
																		  appearanceFromPath: parentPath];
	
	[remover setAppliesToSubFolders: applyToSubFolders];
	
	for (id operation in [[self generalQueue] operations])
	{
		//Check for other operations that are currently being performed on this path
		if ([operation respondsToSelector: @selector(targetPath)] && [[operation targetPath] isEqualToString: path])
		{
			//Cancel any currently-active shelf-appearance application or removal being applied to this path
			if ([operation isKindOfClass: [BXShelfAppearanceOperation class]]) [operation cancel];
			
			//For other types of operations, mark them as a dependency to avoid performing
			//many simultaneous file operations on the same location.
			//(Among other things this avoids concurrency problems with NSWorkspace,
			//which has thread-unsafe methods like -setIcon:forFile:options:)
			else [remover addDependency: operation];
		}
	}
	
	[[self generalQueue] addOperation: remover];
	[remover release];	
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
	
	for (id operation in [[self generalQueue] operations])
	{
		//Check for other operations that are currently being performed on this path
		if ([operation respondsToSelector: @selector(targetPath)] && [[operation targetPath] isEqualToString: path])
		{
			//If we're already copying these sample games to the specified location,
			//don't bother repeating ourselves
			if ([operation isKindOfClass: [BXSampleGamesCopy class]] &&
				[[operation sourcePath] isEqualToString: sourcePath])
			{
				[copyOperation release];
				return;
			}
			
			//For other types of operations, mark them as a dependency to avoid performing
			//many simultaneous file operations on the same location.
			//(Among other things this avoids concurrency problems with NSWorkspace,
			//which has thread-unsafe methods like -setIcon:forFile:options:)
			else [copyOperation addDependency: operation];
		}
	}
	
	[[self generalQueue] addOperation: copyOperation];
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
    [alert release];
}

- (void) _gamesFolderPromptDidEnd: (NSAlert *)alert
					   returnCode: (NSInteger)returnCode
						   window: (NSWindow *)window
{
    if (returnCode == NSAlertFirstButtonReturn)
	{
        //Hide the alert sheet now so that we can show a different sheet in the same window
        [[alert window] orderOut: self];
            
        [[BXGamesFolderPanelController controller] showGamesFolderPanelForWindow: window];
	}
}

- (void) addImporterDropletToPath: (NSString *)folderPath
{
	return [self freshenImporterDropletAtPath: folderPath addIfMissing: YES];
}

- (void) freshenImporterDropletAtPath: (NSString *)path addIfMissing: (BOOL)addIfMissing
{
	NSString *dropletPath = [[NSBundle mainBundle] pathForResource: @"Game Importer Droplet" ofType: @"app"];
	
	BXHelperAppCheck *checkOperation = [[BXHelperAppCheck alloc] initWithTargetPath: path
																	   forAppAtPath: dropletPath];
	[checkOperation setAddIfMissing: addIfMissing];
	
	for (id operation in [[self generalQueue] operations])
	{
		//Check for other operations that are currently being performed on this path
		if ([operation respondsToSelector: @selector(targetPath)] && [[operation targetPath] isEqualToString: path])
		{
			//Check for currently-active checks for this droplet
			if ([operation isKindOfClass: [BXHelperAppCheck class]] &&
				[[operation appPath] isEqualToString: dropletPath])
			{
				//If we're doing the same as the other check, or if we're only checking this time and not adding,
				//then let the other operation continue and cancel this one
				if (!addIfMissing || [operation addIfMissing])
				{
					[checkOperation release];
					return;
				}
				//Otherwise, cancel the other operation and replace it with our own
				else
				{
					[operation cancel];
				}
			}
			 
			//For other types of operations, mark them as a dependency to avoid performing
			//many simultaneous file operations on the same location.
			//(Among other things this avoids concurrency problems with NSWorkspace,
			//which has thread-unsafe methods like -setIcon:forFile:options:)
			else [checkOperation addDependency: operation];
		}
	}
	
	[[self generalQueue] addOperation: checkOperation];
	[checkOperation release];
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
		if ([self appliesShelfAppearanceToGamesFolder])
		{
			[self applyShelfAppearanceToPath: path andSubFolders: YES switchToShelfMode: NO];
		}
		
		//Also check that there's an up-to-date game importer droplet in the folder.
		[self freshenImporterDropletAtPath: path addIfMissing: NO];
	}

	else if (![self gamesFolderChosen] && [[NSUserDefaults standardUserDefaults] boolForKey: @"showFirstRunPanel"])
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
