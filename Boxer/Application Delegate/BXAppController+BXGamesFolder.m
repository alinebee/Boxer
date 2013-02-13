/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXAppController+BXGamesFolder.h"
#import "BXBaseAppController+BXSupportFiles.h"

#import "NDAlias+AliasFile.h"
#import "NSWorkspace+BXFileTypes.h"
#import "NSWorkspace+BXIcons.h"
#import "BXGamesFolderPanelController.h"

#import "BXShelfArt.h"
#import "NSImage+BXSaveImages.h"

#import "BXSampleGamesCopy.h"
#import "BXShelfAppearanceOperation.h"
#import "NSString+BXPaths.h"
#import "BXAppKitVersionHelpers.h"
#import "NSURL+BXFilesystemHelpers.h"

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
//Used by validateGamesFolderURL:error:
+ (BOOL) _isReservedURL: (NSURL *)URL;

@end




@implementation BXAppController (BXGamesFolder)

+ (NSArray *) defaultGamesFolderURLs
{
	static NSArray *URLs = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        NSString *defaultName = NSLocalizedString(@"DOS Games",
                                                  @"The default name for the games folder.");
        
        NSFileManager *manager = [NSFileManager defaultManager];
        
        NSURL *homeURL      = [NSURL fileURLWithPath: NSHomeDirectory()];
        NSURL *docsURL      = [[manager URLsForDirectory: NSDocumentDirectory inDomains: NSUserDomainMask] objectAtIndex: 0];
        NSURL *userAppURL   = [[manager URLsForDirectory: NSApplicationDirectory inDomains: NSUserDomainMask] objectAtIndex: 0];
        NSURL *appURL       = [[manager URLsForDirectory: NSApplicationDirectory inDomains: NSLocalDomainMask] objectAtIndex: 0];
        
        URLs = @[
            [homeURL URLByAppendingPathComponent: defaultName],
            [docsURL URLByAppendingPathComponent: defaultName],
            [userAppURL URLByAppendingPathComponent: defaultName],
            [appURL URLByAppendingPathComponent: defaultName],
        ];
        [URLs retain];
    });
    
	return URLs;
}

+ (NSString *) preferredGamesFolderURL
{
    return [[self defaultGamesFolderURLs] objectAtIndex: 0];
}

+ (NSSet *) reservedURLs
{
	static NSMutableSet *reservedURLs = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
		NSFileManager *manager = [NSFileManager defaultManager];
        
        reservedURLs = [[NSMutableSet alloc] initWithObjects: [NSURL fileURLWithPath: NSHomeDirectory()], nil];
        
#define NUM_DIRs 7
        NSSearchPathDirectory reservedDirs[NUM_DIRs] = {
            NSDocumentDirectory,
            NSAllApplicationsDirectory,
            NSAllLibrariesDirectory,
            NSDesktopDirectory,
            NSDownloadsDirectory,
            NSUserDirectory,
            NSSharedPublicDirectory,
        };
        
        for (NSUInteger i=0; i<NUM_DIRs; i++)
        {
            NSArray *searchURLs = [manager URLsForDirectory: reservedDirs[i] inDomains: NSAllDomainsMask];
            [reservedURLs addObjectsFromArray: searchURLs];
        }
	});
    
	return reservedURLs;
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
	NSSize maxArtworkSize = self._maxArtworkSize;
	
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


- (NSURL *) shelfArtworkURL
{
    NSURL *supportURL = [self supportURLCreatingIfMissing: NO error: NULL];
	NSURL *artworkFolderURL = [supportURL URLByAppendingPathComponent: @"Shelf artwork"];
	NSString *artworkName = @"Snow Leopard.jpg";
	NSURL *artworkURL = [artworkFolderURL URLByAppendingPathComponent: artworkName];
	
	//If there's no suitable artwork yet, then generate a new image
	if (![artworkURL checkResourceIsReachableAndReturnError: NULL])
	{
		//Ensure the base folder exists
		BOOL folderCreated = [[NSFileManager defaultManager] createDirectoryAtURL: artworkFolderURL
                                                      withIntermediateDirectories: YES
                                                                       attributes: nil
                                                                            error: NULL];
		
		//Don't continue if folder creation failed for some reason
		if (!folderCreated) return nil;
		
		//Now, generate new artwork appropriate for the current Finder version
		NSSize artworkSize = self._shelfArtworkSize;
		
		//If an appropriate size could not be determined, bail out
		if (NSEqualSizes(artworkSize, NSZeroSize)) return nil;
		
		NSString *shelfTemplate = @"ShelfTemplateSnowLeopard";
		
		BXShelfArt *shelfArt = [[BXShelfArt alloc] initWithSourceImage: [NSImage imageNamed: shelfTemplate]];
		
		NSImage *tiledShelf = [shelfArt tiledImageWithSize: artworkSize];
		
		[shelfArt release];
		
        BOOL imageSaved = [tiledShelf saveToPath: artworkURL.path
										withType: NSJPEGFileType
									  properties: @{ NSImageCompressionFactor: @(1.0)}
										   error: NULL];
		
		//Bail out if the image could not be saved properly
		if (!imageSaved) return NO;
	}
	
	//If we got this far then we have a pre-existing or newly-generated shelf image at the specified path.
	return artworkURL;
}

+ (NSSet *) keyPathsForValuesAffectingGamesFolderChosen
{
	return [NSSet setWithObject: @"gamesFolderURL"];
}

- (BOOL) gamesFolderChosen
{
	return [[NSUserDefaults standardUserDefaults] dataForKey: @"gamesFolder"] != nil;
}


- (NSURL *) gamesFolderURL
{
	//Load the games folder path from our preferences alias the first time we need it
	if (!_gamesFolderURL)
	{
		NSData *aliasData = [[NSUserDefaults standardUserDefaults] dataForKey: @"gamesFolder"];
		
		if (aliasData)
		{
			NDAlias *alias = [NDAlias aliasWithData: aliasData];
			_gamesFolderURL = [alias.URL copy];
			
			//If the alias was updated while resolving it because the target had moved,
			//then re-save the new alias data
			if (alias.changed)
			{
				[[NSUserDefaults standardUserDefaults] setObject: alias.data forKey: @"gamesFolder"];
			}
		}
		else
		{
			//If no games folder has been set yet, look for one from Boxer 0.8x.
			NSURL *legacyURL = self.legacyGamesFolderURL;
            BOOL foundLegacyURL = NO;
			if (legacyURL)
            {
                foundLegacyURL = [self adoptLegacyGamesFolderFromURL: legacyURL error: nil];
            }
            
            //If that fails, try one of the default locations to see if a folder is there.
            if (!foundLegacyURL)
            {
                for (NSURL *URL in [self.class defaultGamesFolderURLs])
                {
                    if ([URL checkResourceIsReachableAndReturnError: NULL])
                    {
                        self.gamesFolderURL = URL;
                        break;
                    }
                }
            }
		}
	}
	return [[_gamesFolderURL retain] autorelease];
}

- (void) setGamesFolderURL: (NSURL *)newURL
{
	if (![_gamesFolderURL isEqual: newURL])
	{
		[_gamesFolderURL release];
		_gamesFolderURL = [newURL copy];
		
		if (newURL != nil)
		{
			//Store the new path in the preferences as an alias, so that users can move it around.
			NDAlias *alias = [NDAlias aliasWithURL: newURL];
			[[NSUserDefaults standardUserDefaults] setObject: alias.data forKey: @"gamesFolder"];
		}
	}
}

+ (BOOL) _isReservedURL: (NSURL *)URL
{
	//Reject reserved paths
	if ([[self.class reservedURLs] containsObject: URL]) return YES;
	
    NSFileManager *manager = [NSFileManager defaultManager];
    
	//Reject paths located inside system library folders (though we allow them within the user's own Library folder)
	NSArray *libraryURLs = [manager URLsForDirectory: NSAllLibrariesDirectory inDomains: NSLocalDomainMask | NSSystemDomainMask];
	for (NSURL *libraryURL in libraryURLs)
    {
        if ([URL isBasedInURL: libraryURL]) return YES;
    }
    
	//Reject base home folder paths (though accept any folder within them, of course.)
	NSArray *userDirectoryURLs = [manager URLsForDirectory: NSUserDirectory inDomains: NSAllDomainsMask];
    NSURL *parentURL = URL.URLByDeletingLastPathComponent;
	for (NSURL *userDirectoryURL in userDirectoryURLs)
    {
        if ([parentURL isEqual: userDirectoryURL]) return YES;
    }

	//If we got this far then it's not a recognised reserved URL.
	return NO;
}

- (BOOL) validateGamesFolderURL: (inout NSURL **)ioValue error: (out NSError **)outError
{
	NSURL *URL = *ioValue;
	
	//Accept nil paths, since these will clear the preference.
	if (!URL)
        return YES;
	
	URL = URL.URLByStandardizingPath;
	
	if ([self.class _isReservedURL: URL])
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
			
			NSString *displayName = nil;
			[URL getResourceValue: &displayName forKey: NSURLLocalizedNameKey error: NULL];
			if (!displayName)
                displayName = URL.lastPathComponent;
			
			NSString *description = [NSString stringWithFormat: descriptionFormat, displayName];

			NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: description,
                NSLocalizedRecoverySuggestionErrorKey: explanation,
                NSURLErrorKey: URL,
            };
			
			*outError = [NSError errorWithDomain: BXGamesFolderErrorDomain
											code: BXGamesFolderURLInvalid
										userInfo: userInfo];
		}
		
		return NO;
	}
	
    //Warn if we do not currently have write permission to access that URL
    NSNumber *writeableFlag = nil;
    [URL getResourceValue: &writeableFlag forKey: NSURLIsWritableKey error: NULL];
    
    if (!writeableFlag.boolValue)
    {
        if (outError)
        {
            NSString *descriptionFormat = NSLocalizedString(@"Boxer cannot write to the “%1$@” folder.",
                                                            @"Error shown when chosen games folder was read-only. %1$@ is the name of the folder.");
            
            NSString *explanation = NSLocalizedString(@"Please check the file permissions, or choose a different folder.",
                                                      @"Explanatory text shown when chosen games folder was read-only.");
            
			NSString *displayName = nil;
			[URL getResourceValue: &displayName forKey: NSURLLocalizedNameKey error: NULL];
            if (!displayName)
                displayName	= URL.lastPathComponent;
            
            NSString *description = [NSString stringWithFormat: descriptionFormat, displayName];
            
			NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: description,
                NSLocalizedRecoverySuggestionErrorKey: explanation,
                NSURLErrorKey: URL,
            };
            
            *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                            code: NSFileWriteNoPermissionError
                                        userInfo: userInfo];
        }
        return NO;
    }
	
	//If we got this far, the URL is OK.
	return YES;
}


- (BOOL) assignGamesFolderURL: (NSURL *)URL
              withSampleGames: (BOOL)addSampleGames
              shelfAppearance: (BXShelfAppearance)applyShelfAppearance
              createIfMissing: (BOOL)createIfMissing
                        error: (NSError **)outError
{
    NSAssert(URL != nil, @"nil URL provided to assignGamesFolderURL:withSampleGames:shelfAppearance:createIfMissing:error:");
    
    NSError *reachabilityError = nil;
    if (![URL checkResourceIsReachableAndReturnError: &reachabilityError])
    {
        //If we're allowed, create the folder if it's not there already.
        if (createIfMissing)
        {
            BOOL created = [[NSFileManager defaultManager] createDirectoryAtURL: URL
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
                *outError = reachabilityError;
            }
            return NO;
        }
    }
    
    //Verify that the path is acceptable to us.
    //FIXME: we should be validating this BEFORE auto-creating the directory, not after.
    BOOL isValid = [self validateGamesFolderURL: &URL error: outError];
    if (!isValid) return NO;
    
    //If we got this far, we can go ahead and assign this as our games folder path.
    //Apply the requested options now.
	if (applyShelfAppearance == BXShelfAuto)
	{
		applyShelfAppearance = self.appliesShelfAppearanceToGamesFolder;
	}
	else
	{
        //Update the option to reflect the shelf appearance requested.
        self.appliesShelfAppearanceToGamesFolder = (BOOL)applyShelfAppearance;
	}

	if (applyShelfAppearance)
    {
		[self applyShelfAppearanceToURL: URL
                          andSubFolders: YES
                      switchToShelfMode: YES];
	}
    
	if (addSampleGames)
    {
        [self addSampleGamesToURL: URL];
	}
    
    self.gamesFolderURL = URL;
    return YES;
}

- (BOOL) adoptLegacyGamesFolderFromURL: (NSURL *)URL error: (out NSError **)outError
{
	if ([URL checkResourceIsReachableAndReturnError: outError])
	{
		//Check if the old path has a .background folder: if so,
		//then automatically apply the games-folder appearance.
		NSURL *backgroundURL = [URL URLByAppendingPathComponent: @".background"];
		if ([backgroundURL checkResourceIsReachableAndReturnError: NULL])
		{
            self.appliesShelfAppearanceToGamesFolder = YES;
			[self applyShelfAppearanceToURL: URL andSubFolders: YES switchToShelfMode: NO];
		}
		
        self.gamesFolderURL = URL;
        
		return YES;
	}
    else
    {
        return NO;
    }
}

+ (NSSet *) keyPathsForValuesAffectingGamesFolderIcon
{
	return [NSSet setWithObjects: @"gamesFolderURL", @"appliesShelfAppearanceToGamesFolder", nil];
}

- (NSImage *) gamesFolderIcon
{
    BOOL hasCustomIcon = [[NSWorkspace sharedWorkspace] fileHasCustomIcon: self.gamesFolderURL.path];
    if (hasCustomIcon)
    {
        return [[NSWorkspace sharedWorkspace] iconForFile: self.gamesFolderURL.path];
    }
    else
    {
        return [NSImage imageNamed: @"gamefolder"];
    }
}

- (NSURL *) legacyGamesFolderURL
{
	//Check for an alias reference from 0.8x versions of Boxer
	NSURL *libraryURL = [[[NSFileManager defaultManager] URLsForDirectory: NSLibraryDirectory inDomains: NSUserDomainMask] objectAtIndex: 0];
    
    [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex: 0];
	NSURL *legacyAliasURL = [libraryURL URLByAppendingPathComponent: @"Preferences/Boxer/Default Folder"];
	
	//Resolve the previous games folder location from that alias
	NDAlias *alias = [NDAlias aliasWithContentsOfURL: legacyAliasURL];
	return alias.URL;
}

- (NSURL *) fallbackGamesFolderURL
{
    return [[[NSFileManager defaultManager] URLsForDirectory: NSDesktopDirectory inDomains: NSUserDomainMask] objectAtIndex: 0];
}

- (void) applyShelfAppearanceToURL: (NSURL *)URL
                     andSubFolders: (BOOL)applyToSubFolders
                 switchToShelfMode: (BOOL)switchMode
{	
	//NOTE: if no shelf artwork could be found or generated, then bail out early
	NSURL *backgroundImageURL = self.shelfArtworkURL;
    if (!backgroundImageURL)
        return;
	
	NSImage *folderIcon = [NSImage imageNamed: @"gamefolder"];
	
	BXShelfAppearanceApplicator *applicator = [[BXShelfAppearanceApplicator alloc] initWithTargetURL: URL
																				  backgroundImageURL: backgroundImageURL
                                                                                                icon: folderIcon];
	
    applicator.appliesToSubFolders = applyToSubFolders;
    applicator.switchToIconView = switchMode;
	
	for (id operation in self.generalQueue.operations)
	{
		//Check for other operations that are currently being performed on this path
		if ([operation respondsToSelector: @selector(targetURL)] && [[operation targetURL] isEqual: URL])
		{
			//Cancel any currently-active shelf-appearance application or removal being applied to this path
			if ([operation isKindOfClass: [BXShelfAppearanceOperation class]])
                [operation cancel];
			
			//For other types of operations, mark them as a dependency to avoid performing
			//many simultaneous file operations on the same location.
			//(Among other things this avoids potential concurrency problems with
            //our icon-setting methods.)
			else [applicator addDependency: operation];
		}
	}
	
	[self.generalQueue addOperation: applicator];
	[applicator release];
}

- (void) removeShelfAppearanceFromURL: (NSURL *)URL
                        andSubFolders: (BOOL)applyToSubFolders
{
	//Revert the folder's appearance to that of its parent folder
	NSURL *parentURL = URL.URLByDeletingLastPathComponent;
	
	BXShelfAppearanceRemover *remover = [[BXShelfAppearanceRemover alloc] initWithTargetURL: URL
																		  appearanceFromURL: parentURL];
	
	[remover setAppliesToSubFolders: applyToSubFolders];
	
	for (id operation in self.generalQueue.operations)
	{
		//Check for other operations that are currently being performed on this path
		if ([operation respondsToSelector: @selector(targetURL)] && [[operation targetURL] isEqual: URL])
		{
			//Cancel any currently-active shelf-appearance application or removal being applied to this path
			if ([operation isKindOfClass: [BXShelfAppearanceOperation class]])
                [operation cancel];
			
			//For other types of operations, mark them as a dependency to avoid performing
			//many simultaneous file operations on the same location.
			else [remover addDependency: operation];
		}
	}
	
	[self.generalQueue addOperation: remover];
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

- (void) addSampleGamesToURL: (NSURL *)URL
{
	NSURL *sourceURL = [[NSBundle mainBundle] URLForResource: @"Sample Games" withExtension: nil];
	
	BXSampleGamesCopy *copyOperation = [[BXSampleGamesCopy alloc] initFromSourceURL: sourceURL
																		toTargetURL: URL];
	
	for (id operation in self.generalQueue.operations)
	{
		//Check for other operations that are currently being performed on this path
		if ([operation respondsToSelector: @selector(targetURL)] && [[operation targetURL] isEqual: URL])
		{
			//If we're already copying these sample games to the specified location,
			//don't bother repeating ourselves
			if ([operation isKindOfClass: [BXSampleGamesCopy class]] &&
				[[operation sourceURL] isEqual: sourceURL])
			{
				[copyOperation release];
				return;
			}
			
			//For other types of operations, mark them as a dependency to avoid performing
			//many simultaneous file operations on the same location.
			else [copyOperation addDependency: operation];
		}
	}
	
	[self.generalQueue addOperation: copyOperation];
	[copyOperation release];
}


- (void) promptForMissingGamesFolderInWindow: (NSWindow *)window
{
	NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Boxer can no longer find your games folder.",
                                          @"Bold message shown in alert when Boxer cannot find the user’s games folder.");
	
    alert.informativeText = NSLocalizedString(@"Make sure the disk containing your games folder is connected.",
                                              @"Explanatory text shown in alert when Boxer cannot find the user’s games folder at startup.");
	
	[alert addButtonWithTitle: NSLocalizedString(@"Locate folder…",
												 @"Button to display a file open panel to choose a new location for the games folder.")];
    
    NSButton *cancelButton = [alert addButtonWithTitle: NSLocalizedString(@"Cancel",
                                                                          @"Button to cancel without making a new games folder.")];
    
    cancelButton.keyEquivalent = @"\e";
	
	if (window)
	{
		[alert beginSheetModalForWindow: window
						  modalDelegate: self
						 didEndSelector: @selector(_gamesFolderPromptDidEnd:returnCode:window:)
							contextInfo: (__bridge void *)(window)];
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
        [alert.window orderOut: self];
            
        [[BXGamesFolderPanelController controller] showGamesFolderPanelForWindow: window];
	}
}

- (IBAction) revealGamesFolder: (id)sender
{
	NSURL *URL = self.gamesFolderURL;
	BOOL revealed = NO;
	
	if (URL)
        revealed = [self revealPath: URL.path];
	
	if (revealed)
	{
		//Each time after we open the game folder, reapply the shelf appearance.
		//We do this because Finder can sometimes 'lose' the appearance.
		if (self.appliesShelfAppearanceToGamesFolder)
		{
			[self applyShelfAppearanceToURL: URL andSubFolders: YES switchToShelfMode: NO];
		}
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
