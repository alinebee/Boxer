/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXAppController+BXGamesFolder.h"
#import "BXBaseAppController+BXSupportFiles.h"

#import "NSWorkspace+ADBFileTypes.h"
#import "NSWorkspace+ADBIconHelpers.h"
#import "BXGamesFolderPanelController.h"

#import "BXShelfArt.h"
#import "NSImage+ADBSaveImages.h"

#import "BXSampleGamesCopy.h"
#import "BXShelfAppearanceOperation.h"
#import "NSString+ADBPaths.h"
#import "NSURL+ADBFilesystemHelpers.h"
#import "NSURL+ADBAliasHelpers.h"
#import "ADBAppKitVersionHelpers.h"

//For determining maximum Finder folder-background sizes
#import <OpenGL/OpenGL.h>
#import <OpenGL/CGLMacro.h>
#import <OpenGL/glu.h>


#pragma mark - Constants

NSString * const BXGamesFolderErrorDomain = @"BXGamesFolderErrorDomain";

/// Boxer 1.3.x and below stored the games folder as a serialized alias record under this user defaults key.
NSString * const BXGamesFolderAliasUserDefaultsKey = @"gamesFolder";

/// Modern versions of Boxer store the games folder as NSURL bookmark data under this user defaults key.
NSString * const BXGamesFolderBookmarkUserDefaultsKey = @"gamesFolderURLBookmark";



#pragma mark - Private method declarations

@interface BXAppController (BXGamesFolderPrivate)

/// The maximum size of artwork to generate.
/// This corresponds to Finder's own builtin max size, independent of hardware.
+ (NSSize) _maxArtworkSize;

/// The size of shelf artwork to generate.
/// This is dependent on the Finder version and the current graphics chipset.
- (NSSize) _shelfArtworkSize;

/// Callback for the 'we-couldnt-find-your-games-folder' sheet.
- (void) _gamesFolderPromptDidEnd: (NSAlert *)alert
					   returnCode: (NSInteger)returnCode
						   window: (NSWindow *)window;

/// Returns whether the specified path is a reserved system directory.
/// Used by validateGamesFolderURL:error:
+ (BOOL) _isReservedURL: (NSURL *)URL;

@end




@implementation BXAppController (BXGamesFolder)

+ (NSArray *) commonGamesFolderURLs
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
    });
    
	return URLs;
}

+ (NSString *) preferredGamesFolderURL
{
    return [[self commonGamesFolderURLs] objectAtIndex: 0];
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
	//in 10.6 and above, regardless of OpenGL texture limits; backgrounds
	//larger than this will be shrunk by Finder to fit within 4000x4000,
	//with undesirable consequences.
	
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
            BOOL supportsRectangleTextures = gluCheckExtension((const GLubyte *)"GL_ARB_texture_rectangle", extensions) == GL_TRUE;
            
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
    BOOL useRetinaAssets = NO;
    //10.7 and up
    if ([[NSScreen mainScreen] respondsToSelector: @selector(convertRectToBacking:)])
    {
        NSRect backingPixel = [[NSScreen mainScreen] convertRectToBacking: NSMakeRect(0, 0, 1, 1)];
        useRetinaAssets = (backingPixel.size.width >= 2.0);
    }
    
    NSURL *supportURL = [self supportURLCreatingIfMissing: NO error: NULL];
	NSURL *artworkFolderURL = [supportURL URLByAppendingPathComponent: @"Shelf artwork"];
    
	NSString *artworkName = useRetinaAssets ? @"Shelves@2x.jpg" : @"Shelves.jpg";
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
		NSSize artworkPixelSize = self._shelfArtworkSize;
		
		//If an appropriate size could not be determined, bail out
		if (NSEqualSizes(artworkPixelSize, NSZeroSize)) return nil;
		
        NSImage *shelfTemplate =[NSImage imageNamed: @"ShelfTemplate"];
		
		BXShelfArt *shelfArt = [[BXShelfArt alloc] initWithSourceImage: shelfTemplate];
		
		NSImage *tiledShelf = [shelfArt tiledImageWithPixelSize: artworkPixelSize];
		
		
        BOOL imageSaved = [tiledShelf saveToURL: artworkURL
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
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults dataForKey: BXGamesFolderBookmarkUserDefaultsKey] != nil)
        return YES;
    
    if ([defaults dataForKey: BXGamesFolderAliasUserDefaultsKey] != nil)
        return YES;
    
    return NO;
}

- (NSURL *) gamesFolderURL
{
	//Resolve the games folder URL from our user defaults bookmark the first time we need it.
	if (_gamesFolderURL == nil)
	{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
		NSData *bookmarkData = [defaults dataForKey: BXGamesFolderBookmarkUserDefaultsKey];
		
		if (bookmarkData)
		{
            BOOL dataIsStale;
            NSError *resolutionError;
            NSURL *folderURL = [NSURL URLByResolvingBookmarkData: bookmarkData
                                                         options: NSURLBookmarkResolutionWithoutUI
                                                   relativeToURL: nil
                                             bookmarkDataIsStale: &dataIsStale
                                                           error: &resolutionError];
            
            if (folderURL)
            {
                _gamesFolderURL = [folderURL.fileReferenceURL copy];
                
                //Re-save the bookmark data if it was stale (e.g. if the folder has moved or been renamed.)
                if (dataIsStale)
                {
                    NSData *updatedBookmarkData = [folderURL bookmarkDataWithOptions: 0
                                                      includingResourceValuesForKeys: nil
                                                                       relativeToURL: nil
                                                                               error: NULL];
                    if (updatedBookmarkData)
                        [defaults setObject: updatedBookmarkData forKey: BXGamesFolderBookmarkUserDefaultsKey];
                }
            }
            //TODO: properly handle failure to resolve the bookmark, e.g. by presenting a warning to the user.
            else
            {
            }
		}
        
        //Boxer 1.3.x and below: games folder was stored as a serialized alias record.
        else
        {
            NSData *aliasData = [defaults dataForKey: BXGamesFolderAliasUserDefaultsKey];
            
            if (aliasData != nil)
            {
                NSError *resolutionError;
                NSURL *folderURL = [NSURL URLByResolvingAliasRecord: aliasData
                                                            options: NSURLBookmarkResolutionWithoutUI
                                                      relativeToURL: nil
                                                bookmarkDataIsStale: NULL
                                                              error: &resolutionError];
                
                if (folderURL)
                {
                    //This will re-record the legacy games folder URL in user defaults,
                    //storing it as a bookmark this time instead of as an alias record.
                    self.gamesFolderURL = folderURL;
                }
                //TODO: properly handle failure to resolve the bookmark, e.g. by presenting a warning to the user.
                else
                {
                }
            }
            else
            {
                //If no games folder has been chosen yet, look for one from Boxer 0.8x.
                NSURL *legacyURL = self.legacyGamesFolderURL;
                if ([legacyURL checkResourceIsReachableAndReturnError: NULL])
                {
                    //This will re-record the legacy games folder URL in user defaults.
                    self.gamesFolderURL = legacyURL;
                    
                    //Check if the old folder had a .background folder: if so,
                    //then update the folder with our own games-folder appearance.
                    NSURL *backgroundURL = [legacyURL URLByAppendingPathComponent: @".background"];
                    if ([backgroundURL checkResourceIsReachableAndReturnError: NULL])
                    {
                        self.appliesShelfAppearanceToGamesFolder = YES;
                        [self applyShelfAppearanceToURL: legacyURL andSubFolders: YES switchToShelfMode: NO];
                    }
                    
                }
                
                //If a games folder from a previous Boxer version couldn't be found,
                //then check one of the usual games folder locations to see if a folder is there.
                else
                {
                    for (NSURL *URL in [self.class commonGamesFolderURLs])
                    {
                        if ([URL checkResourceIsReachableAndReturnError: NULL])
                        {
                            //This will re-record the legacy games folder URL in user defaults.
                            self.gamesFolderURL = URL;
                            break;
                        }
                    }
                }
            }
        }
	}
    
	return _gamesFolderURL;
}

- (void) setGamesFolderURL: (NSURL *)newURL
{
    //Use a file reference URL so that we can continue tracking the games folder
    //if it's moved or renamed while we're running.
    newURL = newURL.fileReferenceURL;
    
	if (![_gamesFolderURL isEqual: newURL])
	{
		_gamesFolderURL = newURL.fileReferenceURL;
		
        //Store the new location in user defaults as a bookmark, so that users can safely move the folder around.
		if (newURL != nil)
		{
            NSData *bookmarkData = [newURL bookmarkDataWithOptions: 0
                                    includingResourceValuesForKeys: nil
                                                     relativeToURL: nil
                                                             error: NULL];
            
            if (bookmarkData)
            {
                [[NSUserDefaults standardUserDefaults] setObject: bookmarkData
                                                          forKey: BXGamesFolderBookmarkUserDefaultsKey];
            }
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
	NSURL *libraryURL = [[[NSFileManager defaultManager] URLsForDirectory: NSLibraryDirectory inDomains: NSUserDomainMask] objectAtIndex: 0];
    
    [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex: 0];
	NSURL *legacyAliasURL = [libraryURL URLByAppendingPathComponent: @"Preferences/Boxer/Default Folder"];
	
    NSData *bookmarkData = [NSURL bookmarkDataWithContentsOfURL: legacyAliasURL error: NULL];
    if (bookmarkData)
    {
        NSURL *legacyURL = [NSURL URLByResolvingBookmarkData: bookmarkData
                                                     options: 0
                                               relativeToURL: nil
                                         bookmarkDataIsStale: NULL
                                                       error: NULL];
        
        //Will be nil if the bookmark could not be resolved
        return legacyURL;
    }
    else
    {
        return nil;
    }
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
		if ([operation respondsToSelector: @selector(targetURL)] && [[operation targetURL].filePathURL isEqual: URL])
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
				return;
			}
			
			//For other types of operations, mark them as a dependency to avoid performing
			//many simultaneous file operations on the same location.
			else [copyOperation addDependency: operation];
		}
	}
	
	[self.generalQueue addOperation: copyOperation];
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
                      completionHandler: ^(NSModalResponse returnCode) {
                          [self _gamesFolderPromptDidEnd:alert returnCode:returnCode window:window];
        }];
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
        revealed = [self revealURLsInFinder: @[URL]];
	
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
