/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXGamebox.h"
#import "NSWorkspace+ADBIconHelpers.h"
#import "BXFileTypes.h"
#import "BXDrive.h"
#import "RegexKitLite.h"
#import "ADBDigest.h"
#import "NSData+HexStrings.h"
#import "NSURL+ADBFilesystemHelpers.h"
#import "NSError+ADBErrorHelpers.h"


#pragma mark - Constants

typedef NS_ENUM(NSInteger, BXGameboxDocumentationOperation) {
    BXGameboxDocumentationCopy,
    BXGameboxDocumentationMove,
    BXGameboxDocumentationSymlink,
};


NSString * const BXGameIdentifierGameInfoKey        = @"BXGameIdentifier";
NSString * const BXGameIdentifierTypeGameInfoKey    = @"BXGameIdentifierType";
NSString * const BXTargetProgramGameInfoKey         = @"BXDefaultProgramPath";
NSString * const BXLaunchersGameInfoKey             = @"BXLaunchers";
NSString * const BXCloseOnExitGameInfoKey           = @"BXCloseAfterDefaultProgram";

NSString * const BXTargetSymlinkName			= @"DOSBox Target";
NSString * const BXConfigurationFileName		= @"DOSBox Preferences";
NSString * const BXConfigurationFileExtension	= @"conf";
NSString * const BXGameInfoFileName				= @"Game Info";
NSString * const BXGameInfoFileExtension		= @"plist";
NSString * const BXDocumentationFolderName		= @"Documentation";


NSString * const BXLauncherTitleKey         = @"BXLauncherTitle";
NSString * const BXLauncherRelativePathKey  = @"BXLauncherPath";
NSString * const BXLauncherURLKey           = @"BXLauncherURL";
NSString * const BXLauncherArgsKey          = @"BXLauncherArguments";
NSString * const BXLauncherDefaultKey       = @"BXLauncherIsDefault";


NSString * const BXGameboxErrorDomain = @"BXGameboxErrorDomain";

//When calculating a digest from the gamebox's EXEs, read only the first 64kb of each EXE.
#define BXGameIdentifierEXEDigestStubLength 65536

//The gamebox will cache the results of an isWritable check for this many seconds
//to prevent repeated hits to the filesystem.
#define BXGameboxWritableCheckCacheDuration 3.0


#pragma mark - Private method declarations

@interface BXGamebox ()
@property (readwrite, strong, nonatomic) NSDictionary *gameInfo;

+ (NSSet *) executableExclusions;
+ (NSArray *) URLsForMeaningfulExecutablesInLocation: (NSURL *)baseURL
                                searchSubdirectories: (BOOL)searchSubdirs;

//Returns a new auto-generated identifier based on the meaningful
//executbales found inside the gamebox (if any are present), or a random UUID.
//On return, type will be the type of identifier generated.
- (NSString *) _generatedIdentifierOfType: (BXGameIdentifierType *)type;

//Lazily populates the launchers array from the game info the first time the array is accessed.
- (void) _populateLaunchers;

//Rewrite the launchers array in the game info.
- (void) _persistLaunchers;

//Save the game info back to the gamebox.
- (void) _persistGameInfo;

@end


@implementation BXGamebox
@synthesize gameInfo = _gameInfo;
@synthesize undoDelegate = _undoDelegate;

//We ignore files with these names when considering which programs are important enough to list
//TODO: read this data from a configuration plist instead
+ (NSSet *) executableExclusions
{
	static NSSet *exclusions = nil;
	if (!exclusions) exclusions = [[NSSet alloc] initWithObjects:
		@"dos4gw.exe",
		@"pkunzip.exe",
		@"lha.com",
		@"arj.exe",
		@"deice.exe",
		@"pkunzjr.exe",
	nil];
	return exclusions;
}

+ (BXGamebox *) bundleWithURL: (NSURL *)URL
{
	return [[self alloc] initWithURL: URL];
}

- (void) dealloc
{
    [self.undoDelegate removeAllUndoActionsForClient: self];
}

#pragma mark - Launchers

- (void) _populateLaunchers
{
    if (!_launchers)
    {
        NSArray *recordedLaunchers = [self gameInfoForKey: BXLaunchersGameInfoKey];
        
        _launchers = [[NSMutableArray alloc] initWithCapacity: recordedLaunchers.count];
        
        if (recordedLaunchers.count)
        {
            //Resolve each relative launcher path to an absolute URL before storing it.
            for (NSDictionary *launcher in recordedLaunchers)
            {
                NSString *relativePath = [launcher objectForKey: BXLauncherRelativePathKey];
                NSURL *absoluteURL = [self.resourceURL URLByAppendingPathComponent: relativePath];
                
                NSMutableDictionary *resolvedLauncher = [launcher mutableCopy];
                [resolvedLauncher setObject: absoluteURL forKey: BXLauncherURLKey];
                
                [_launchers addObject: resolvedLauncher];
            }
        }
        
        //If no launchers have been defined for this gamebox, create and record a launcher item
        //based on the original target program of the gamebox specified by a previous Boxer version.
        else
        {
            NSURL *targetURL = self.legacyTargetURL;
            if (targetURL)
            {
                NSString *titleFormat = NSLocalizedString(@"Launch %@", @"Placeholder title for a game launcher autogenerated from a gamebox's previous default program. %@ will be the name of the gamebox itself.");
                
                NSString *launcherTitle = [NSString stringWithFormat: titleFormat, self.gameName];
                
                [self addLauncherWithURL: targetURL arguments: nil title: launcherTitle];
            }
        }
    }
}

- (NSArray *) launchers
{
    [self _populateLaunchers];
    return _launchers;
}

- (void) _persistLaunchers
{
    NSMutableArray *sanitisedLaunchers = [NSMutableArray arrayWithCapacity: self.launchers.count];
    for (NSDictionary *launcher in self.launchers)
    {
        NSMutableDictionary *sanitisedLauncher = [launcher mutableCopy];
        
        //Strip out the absolute URL: we don't want to persist this into the plist.
        [sanitisedLauncher removeObjectForKey: BXLauncherURLKey];
        [sanitisedLaunchers addObject: sanitisedLauncher];
    }
    
    [self setGameInfo: sanitisedLaunchers
               forKey: BXLaunchersGameInfoKey];
}

- (void) insertObject: (NSDictionary *)object inLaunchersAtIndex: (NSUInteger)index
{
    //Ensure the launchers array has been lazily populated from the game info.
    [self _populateLaunchers];
    [_launchers insertObject: object atIndex: index];
    
    //Sync the revised launcher data back into the game info.
    [self _persistLaunchers];
}

- (void) removeObjectFromLaunchersAtIndex: (NSUInteger)index
{
    //Ensure the launchers array has been lazily populated from the game info.
    [self _populateLaunchers];
    [_launchers removeObjectAtIndex: index];
    
    //Sync the revised launcher data back into the game info.
    [self _persistLaunchers];
}

- (void) insertLauncher: (NSDictionary *)launcher atIndex: (NSUInteger)index
{
    [[self mutableArrayValueForKey: @"launchers"] insertObject: launcher atIndex: index];
}

- (void) addLauncher: (NSDictionary *)launcher
{
    [[self mutableArrayValueForKey: @"launchers"] addObject: launcher];
}

- (void) insertLauncherWithURL: (NSURL *)URL
                     arguments: (NSString *)launchArguments
                         title: (NSString *)title
                       atIndex: (NSUInteger)index
{
    NSAssert(URL != nil, @"URL must be provided.");
    NSAssert1([URL isBasedInURL: self.resourceURL], @"Launcher URL must be located within gamebox: %@", URL);
    
    NSString *relativePath = [URL pathRelativeToURL: self.resourceURL];
    
    if (title.length)
        title = [title copy];
    else
        title = relativePath.lastPathComponent;
    
    
    NSMutableDictionary *launcher = [@{ BXLauncherTitleKey:         title,
                                        BXLauncherRelativePathKey:  relativePath,
                                        BXLauncherURLKey:           URL
                                      } mutableCopy];
    
    if (launchArguments.length)
    {
        launchArguments = [launchArguments copy];
        [launcher setObject: launchArguments forKey: BXLauncherArgsKey];
    }
    
    [self insertLauncher: launcher atIndex: index];
}

- (void) addLauncherWithURL: (NSURL *)URL
                  arguments: (NSString *)launchArguments
                      title: (NSString *)title
{
    [self insertLauncherWithURL: URL
                      arguments: launchArguments
                          title: title
                        atIndex: self.launchers.count];
}

- (BOOL) validateLauncherURL: (NSURL **)ioValue error:(NSError **)outError
{
    NSURL *URL = *ioValue;
    
    //Yes I know this is a validation method but supplying a nil URL indicates a programming error.
    NSAssert(URL != nil, @"A launcher must have a URL.");
    
    if (![URL isBasedInURL: self.resourceURL])
	{
		if (outError)
		{
			NSString *format = NSLocalizedString(@"The file “%@” was not located inside this gamebox.",
												 @"Error message shown when trying to add a launcher pointing to a URL outside the gamebox. %@ is the display filename of the URL in question.");
			
			NSString *displayName = URL.lastPathComponent;
			NSString *description = [NSString stringWithFormat: format, displayName];
			
			NSDictionary *userInfo = @{
                                        NSURLErrorKey: URL,
                                        NSLocalizedDescriptionKey: description,
                                        };
			
			*outError = [NSError errorWithDomain: BXGameboxErrorDomain
											code: BXLauncherURLOutsideGameboxError
										userInfo: userInfo];
		}
		return NO;
	}
    return YES;
}

- (void) removeLauncherAtIndex: (NSUInteger)index
{
    [[self mutableArrayValueForKey: @"launchers"] removeObjectAtIndex: index];
}

- (void) removeLauncher: (NSDictionary *)launcher
{
    //Ensure we fire off KVO notifications for removing the entry.
    NSMutableArray *launchers = [self mutableArrayValueForKey: @"launchers"];
    [launchers removeObject: launcher];
    
    //Persist the revised launcher array back into the game info
    [self _persistLaunchers];
}

+ (NSSet *) keyPathsForValuesAffectingDefaultLauncher
{
    return [NSSet setWithObjects: @"launchers", @"defaultLauncherIndex", nil];
}

- (NSDictionary *) defaultLauncher
{
    NSUInteger index = self.defaultLauncherIndex;
    if (index != NSNotFound)
        return [self.launchers objectAtIndex: index];
    else
        return nil;
}

+ (NSSet *) keyPathsForValuesAffectingDefaultLauncherIndex
{
    return [NSSet setWithObject: @"launchers"];
}

- (NSUInteger) defaultLauncherIndex
{
    NSUInteger i, numLaunchers = self.launchers.count;
    for (i=0; i<numLaunchers; i++)
    {
        NSDictionary *launcher = [self.launchers objectAtIndex: i];
        NSNumber *defaultFlag = [launcher objectForKey: BXLauncherDefaultKey];
        if (defaultFlag.boolValue)
            return i;
    }
    return NSNotFound;
}

- (void) setDefaultLauncherIndex: (NSUInteger)newIndex
{
    NSUInteger oldIndex = self.defaultLauncherIndex;
    if (oldIndex != newIndex)
    {
        [self willChangeValueForKey: @"launchers"];
        if (oldIndex != NSNotFound)
        {
            NSMutableDictionary *oldDefaultLauncher = [self.launchers objectAtIndex: oldIndex];
            [oldDefaultLauncher removeObjectForKey: BXLauncherDefaultKey];
        }
        
        if (newIndex != NSNotFound)
        {
            NSMutableDictionary *newDefaultLauncher = [self.launchers objectAtIndex: newIndex];
            [newDefaultLauncher setObject: [NSNumber numberWithBool: YES]
                                   forKey: BXLauncherDefaultKey];
        }
        
        [self _persistLaunchers];
        
        [self didChangeValueForKey: @"launchers"];
    }
}

#pragma mark - Gamebox metadata

- (BOOL) closeOnExit
{
    return [[self gameInfoForKey: BXCloseOnExitGameInfoKey] boolValue];
}

- (void) setCloseOnExit: (BOOL)closeOnExit
{
    [self setGameInfo: [NSNumber numberWithBool: closeOnExit]
               forKey: BXCloseOnExitGameInfoKey];
}

//Set/return the cover art associated with this game package (currently, the package file's icon)
- (NSImage *) coverArt
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	if ([workspace fileHasCustomIcon: self.bundlePath])
	{
		return [workspace iconForFile: self.bundlePath];
	}
	else return nil;
}

- (void) setCoverArt: (NSImage *)image
{
	[[NSWorkspace sharedWorkspace] setIcon: image forFile: self.bundlePath options: 0];
}

- (NSDictionary *) gameInfo
{
	//Load the game info from the gamebox's plist file the first time we need it.
	if (_gameInfo == nil)
	{
		NSMutableDictionary *info = nil;
		
		NSString *infoPath = [self pathForResource: BXGameInfoFileName ofType: BXGameInfoFileExtension];
		if (infoPath) info = [NSMutableDictionary dictionaryWithContentsOfFile: infoPath];
		
		//If there was no plist file in the gamebox, create an empty dictionary instead.
		if (!info) info = [NSMutableDictionary dictionaryWithCapacity: 10];
		
        self.gameInfo = info;
	}
	
	return _gameInfo;
}

- (id) gameInfoForKey: (NSString *)key
{
	return [self.gameInfo objectForKey: key];
}

- (void) setGameInfo: (id)info forKey: (NSString *)key
{
	[self willChangeValueForKey: @"gameInfo"];
	
	if (![[self gameInfoForKey: key] isEqual: info])
	{
        if (info)
            [(NSMutableDictionary *)self.gameInfo setObject: info forKey: key];
        else
            [(NSMutableDictionary *)self.gameInfo removeObjectForKey: key];
        
		[self _persistGameInfo];		
	}
	[self didChangeValueForKey: @"gameInfo"];
}

- (NSString *) gameIdentifier
{
	NSString *identifier = [self gameInfoForKey: BXGameIdentifierGameInfoKey];
	
	//If we don't have an identifier yet, generate a new one and add it to the game's metadata.
	if (!identifier)
	{
		BXGameIdentifierType generatedType = 0;
		identifier = [self _generatedIdentifierOfType: &generatedType];

		[(NSMutableDictionary *)self.gameInfo setObject: identifier forKey: BXGameIdentifierGameInfoKey];
		[(NSMutableDictionary *)self.gameInfo setObject: [NSNumber numberWithUnsignedInteger: generatedType]
                                                 forKey: BXGameIdentifierTypeGameInfoKey];
        
		[self _persistGameInfo];
	}
	
	return identifier;
}

- (void) setGameIdentifier: (NSString *)identifier
{
	[(NSMutableDictionary *)self.gameInfo setObject: identifier forKey: BXGameIdentifierGameInfoKey];
	[(NSMutableDictionary *)self.gameInfo setObject: [NSNumber numberWithUnsignedInteger: BXGameIdentifierUserSpecified]
                                             forKey: BXGameIdentifierTypeGameInfoKey];
}

- (NSString *) gameName
{
	NSFileManager *manager = [NSFileManager defaultManager];
	NSString *displayName = [manager displayNameAtPath: self.bundlePath];

	//Strip the extension if it's .boxer, otherwise leave path extension intact
	//(as it could be a version number component, e.g. the ".1" in "Windows 3.1")
	if ([displayName.pathExtension.lowercaseString isEqualToString: @"boxer"])
		displayName = displayName.stringByDeletingPathExtension;
	
	return displayName;
}


- (void) refresh
{
    self.gameInfo = nil;
}

#pragma mark - Gamebox contents

- (NSArray *) URLsOfVolumesMatchingTypes: (NSSet *)fileTypes
{
    NSDirectoryEnumerationOptions options = NSDirectoryEnumerationSkipsSubdirectoryDescendants | NSDirectoryEnumerationSkipsHiddenFiles;
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL: self.resourceURL
                                                             includingPropertiesForKeys: @[NSURLTypeIdentifierKey]
                                                                                options: options
                                                                           errorHandler: NULL];
    
    NSMutableArray *matches = [NSMutableArray arrayWithCapacity: 10];
    for (NSURL *URL in enumerator)
    {
        if ([URL matchingFileType: fileTypes] != nil)
            [matches addObject: URL];
    }
    return matches;
}

- (NSArray *) hddVolumeURLs
{
    return [self URLsOfVolumesMatchingTypes: [BXFileTypes hddVolumeTypes]];
}

- (NSArray *) cdVolumeURLs
{
    return [self URLsOfVolumesMatchingTypes: [BXFileTypes cdVolumeTypes]];
}

- (NSArray *) floppyVolumeURLs
{
    return [self URLsOfVolumesMatchingTypes: [BXFileTypes floppyVolumeTypes]];
}

- (NSArray *) bundledDrives
{
    NSMutableArray *bundledVolumes = [NSMutableArray arrayWithCapacity: 10];
    [bundledVolumes addObjectsFromArray: self.floppyVolumeURLs];
    [bundledVolumes addObjectsFromArray: self.hddVolumeURLs];
    [bundledVolumes addObjectsFromArray: self.cdVolumeURLs];
    
    BOOL hasProperDriveC = NO;
    NSMutableArray *drives = [NSMutableArray arrayWithCapacity: bundledVolumes.count];
    
    for (NSURL *volumeURL in bundledVolumes)
    {
        BXDrive *drive = [BXDrive driveWithContentsOfURL: volumeURL letter: nil type: BXDriveAutodetect];
        [drives addObject: drive];
        
        if ([drive.letter isEqualToString: @"C"])
            hasProperDriveC = YES;
    }
    
    //If we don't contain an explicit drive C, that means we're an old-style gamebox:
    //In this case, use the base folder of the gamebox itself as drive C.
    if (!hasProperDriveC)
    {
        BXDrive *drive = [BXDrive driveWithContentsOfURL: self.resourceURL
                                                  letter: @"C"
                                                    type: BXDriveHardDisk];
        
        [drives addObject: drive];
    }
    
    //Sort the drives first by letter and then by filename.
    NSArray *descriptors = @[[NSSortDescriptor sortDescriptorWithKey: @"letter" ascending: YES],
                             [NSSortDescriptor sortDescriptorWithKey: @"sourceURL.lastPathComponent" ascending: YES]];
    [drives sortUsingDescriptors: descriptors];
    
    return drives;
}

- (NSURL *) configurationFileURL
{
	NSString *fileName = [BXConfigurationFileName stringByAppendingPathExtension: BXConfigurationFileExtension];
	return [self.resourceURL URLByAppendingPathComponent: fileName];
}

- (NSURL *) legacyTargetURL
{
    NSString *targetPath = [self gameInfoForKey: BXTargetProgramGameInfoKey];
    
    //Resolve the path from a gamebox-relative path into an absolute URL
    if (targetPath)
    {
        return [self.resourceURL URLByAppendingPathComponent: targetPath];
    }
    //If there's no target path stored in game info, check for an old-style symlink
    else
    {
        NSURL *symlinkURL = [self URLForResource: BXTargetSymlinkName withExtension: nil];
        
        if (symlinkURL)
        {
            NSURL *resolvedURL = symlinkURL.URLByResolvingSymlinksInPath;
            
            //If the resolved symlink is the same location as the symlink itself,
            //this indicates it was a broken link that could not be resolved
            if ([symlinkURL isEqual: resolvedURL])
            {
                return nil;
            }
            else
            {
                return resolvedURL;
            }
        }
        else return nil;
    }
}

- (BOOL) isWritable
{
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    BOOL cacheExpired = _nextWriteableCheckTime < now;
    //Periodically re-check whether the gamebox is still writable.
    if (cacheExpired)
    {
        NSNumber *writeableFlag = nil;
        BOOL checkWriteable = [self.bundleURL getResourceValue: &writeableFlag forKey: NSURLIsWritableKey error: NULL];
        
        if (checkWriteable)
        {
            _lastWritableStatus = writeableFlag.boolValue;
        }
        //If we couldn't determine the writeability of the gamebox, assume the answer is no.
        else
        {
            _lastWritableStatus = NO;
        }
        _nextWriteableCheckTime = now + BXGameboxWritableCheckCacheDuration;
    }
    
    return _lastWritableStatus;
}


#pragma mark - Private methods

//Write the game info back to the plist file
- (void) _persistGameInfo
{
	if (_gameInfo)
	{
		NSString *infoName = [BXGameInfoFileName stringByAppendingPathExtension: BXGameInfoFileExtension];
		NSString *infoPath = [self.resourcePath stringByAppendingPathComponent: infoName];
		[_gameInfo writeToFile: infoPath atomically: YES];
	}
}

+ (NSArray *) URLsForMeaningfulExecutablesInLocation: (NSURL *)location searchSubdirectories: (BOOL)searchSubdirs
{
    NSArray *properties = @[NSURLTypeIdentifierKey];
    NSDirectoryEnumerationOptions options = NSDirectoryEnumerationSkipsHiddenFiles;
    if (!searchSubdirs)
        options |= NSDirectoryEnumerationSkipsSubdirectoryDescendants;
    
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL: location
                                                             includingPropertiesForKeys: properties
                                                                                options: options
                                                                           errorHandler: NULL];
    
    NSMutableArray *executableURLs = [NSMutableArray array];
    NSSet *exclusions = [self executableExclusions];
    for (NSURL *URL in enumerator)
    {
        if (![URL matchingFileType: [BXFileTypes executableTypes]])
            continue;
        
        if ([exclusions containsObject: URL.lastPathComponent.lowercaseString])
             continue;
        
        [executableURLs addObject: URL];
    }
    
    return executableURLs;
}

- (NSString *) _generatedIdentifierOfType: (BXGameIdentifierType *)type
{
    NSString *identifier = nil;
    
	//If the gamebox contains executables, generate an identifier based on their hash.
	//TODO: move the choice of executables off to BXSession
	NSArray *foundExecutables = [self.class URLsForMeaningfulExecutablesInLocation: self.resourceURL
                                                              searchSubdirectories: YES];
	if (foundExecutables.count)
	{
		NSData *digest = [ADBDigest SHA1DigestForURLs: foundExecutables
										   upToLength: BXGameIdentifierEXEDigestStubLength
                                                error: NULL];
        
        //If one or more of the files couldn't be read for some reason,
        //then don't bother and fall back on a UUID.
        if (digest)
        {
            *type = BXGameIdentifierEXEDigest;
            identifier = digest.stringWithHexBytes;
        }
	}
	
	//Otherwise, generate a UUID.
	if (!identifier)
	{
		CFUUIDRef     UUID;
		CFStringRef   UUIDString;
		
		UUID = CFUUIDCreate(kCFAllocatorDefault);
		UUIDString = CFUUIDCreateString(kCFAllocatorDefault, UUID);
		
		NSString *identifierWithUUID = [NSString stringWithString: (__bridge NSString *)UUIDString];
		
		CFRelease(UUID);
		CFRelease(UUIDString);
		
		*type = BXGameIdentifierUUID;
		identifier = identifierWithUUID;
	}
    
    return identifier;
}

@end


@implementation BXGamebox (BXGameDocumentation)

//We ignore files whose names match this pattern when considering which documentation files are likely to be worth showing.
//TODO: read this from a configuration plist instead.
+ (NSSet *) documentationExclusions
{
	static NSSet *exclusions = nil;
	if (!exclusions) exclusions = [[NSSet alloc] initWithObjects:
                                   @"(^|/)install",
                                   @"(^|/)interp",
                                   @"(^|/)order",
                                   @"(^|/)orderfrm",
                                   @"(^|/)license",
                                   nil];
	return exclusions;
}

- (void) refreshDocumentation
{
    [self willChangeValueForKey: @"hasDocumentationFolder"];
    [self willChangeValueForKey: @"documentationURLs"];
    
    //This is where we'd clear any documentation cache, if we had one.
    
    [self didChangeValueForKey: @"documentationURLs"];
    [self didChangeValueForKey: @"hasDocumentationFolder"];
}

- (NSURL *) documentationFolderURL
{
    return [self.resourceURL URLByAppendingPathComponent: BXDocumentationFolderName isDirectory: YES];
}

- (BOOL) createDocumentationFolderIfMissingWithError: (out NSError **)outError
{
    NSURL *docsURL = self.documentationFolderURL;
    
    //If the directory already exists, return now
    if ([docsURL checkResourceIsReachableAndReturnError: NULL])
    {
        return YES;
    }
    //Otherwise, create the directory anew.
    else
    {
        [self willChangeValueForKey: @"hasDocumentationFolder"];
        [self willChangeValueForKey: @"documentationURLs"];
        
        BOOL created = [[NSFileManager defaultManager] createDirectoryAtURL: docsURL
                                                withIntermediateDirectories: YES
                                                                 attributes: nil
                                                                      error: outError];
        
        if (created)
        {
            //Record an undo operation to delete the new directory.
            //Note that unlike trashDocumentationFolderWithError: this will completely delete the directory,
            //including its contents: we assume that by the stage that this undo operation is performed,
            //any subsequently-added documentation files will have been undone also.
            NSUndoManager *undoManager = [self.undoDelegate undoManagerForClient: self operation: _cmd];
            if (undoManager.isUndoRegistrationEnabled)
            {
                id undoProxy = [undoManager prepareWithInvocationTarget: self];
                [undoProxy _removeDocumentationFolderWithError: NULL];
            }
        }
        
        [self didChangeValueForKey: @"documentationURLs"];
        [self didChangeValueForKey: @"hasDocumentationFolder"];
        
        return created;
    }
}

- (BOOL) _removeDocumentationFolderWithError: (out NSError **)outError
{
    [self willChangeValueForKey: @"hasDocumentationFolder"];
    [self willChangeValueForKey: @"documentationURLs"];
    
    NSURL *docsURL = self.documentationFolderURL;
    BOOL removed = [[NSFileManager defaultManager] removeItemAtURL: docsURL error: outError];
    if (removed)
    {
        //Record an undo operation to recreate the documentation folder.
        NSUndoManager *undoManager = [self.undoDelegate undoManagerForClient: self operation: _cmd];
        if (undoManager.isUndoRegistrationEnabled)
        {
            id undoProxy = [undoManager prepareWithInvocationTarget: self];
            [undoProxy createDocumentationFolderIfMissingWithError: NULL];
        }
    }
    
    [self didChangeValueForKey: @"documentationURLs"];
    [self didChangeValueForKey: @"hasDocumentationFolder"];
    
    return removed;
}

- (NSURL *) trashDocumentationFolderWithError: (out NSError **)outError
{
    [self willChangeValueForKey: @"hasDocumentationFolder"];
    [self willChangeValueForKey: @"documentationURLs"];
    
    NSURL *docsURL = self.documentationFolderURL;
    NSURL *trashedURL = nil;
    
    BOOL trashed = [[NSFileManager defaultManager] trashItemAtURL: docsURL resultingItemURL: &trashedURL error: outError];
    if (trashed)
    {
        //Record an undo operation to put the item back from the trash
        NSUndoManager *undoManager = [self.undoDelegate undoManagerForClient: self operation: _cmd];
        if (undoManager.isUndoRegistrationEnabled)
        {
            id undoProxy = [undoManager prepareWithInvocationTarget: self];
            [undoProxy _restoreTrashedDocumentationFolder: trashedURL error: NULL];
        }
    }
    
    [self didChangeValueForKey: @"documentationURLs"];
    [self didChangeValueForKey: @"hasDocumentationFolder"];
    
    return trashedURL;
}

- (BOOL) _restoreTrashedDocumentationFolder: (NSURL *)trashedURL error: (NSError **)outError
{
    [self willChangeValueForKey: @"hasDocumentationFolder"];
    [self willChangeValueForKey: @"documentationURLs"];
    
    NSURL *restoredURL = self.documentationFolderURL;
    
    BOOL restored = [[NSFileManager defaultManager] moveItemAtURL: trashedURL toURL: restoredURL error: outError];
    if (restored)
    {
        //Record an undo operation to re-trash the file
        NSUndoManager *undoManager = [self.undoDelegate undoManagerForClient: self operation: _cmd];
        if (undoManager.isUndoRegistrationEnabled)
        {
            id undoProxy = [undoManager prepareWithInvocationTarget: self];
            [undoProxy trashDocumentationFolderWithError: NULL];
        }
    }
    
    [self didChangeValueForKey: @"documentationURLs"];
    [self didChangeValueForKey: @"hasDocumentationFolder"];
    
    return restored;
}

- (NSArray *) populateDocumentationFolderCreatingIfMissing: (BOOL)createIfMissing error: (out NSError **)outError
{
    NSURL *docsURL = self.documentationFolderURL;
    //If desired, create the folder if it is missing. If it doesn't exist and we can't create it, bail out now.
    if (createIfMissing)
    {
        BOOL createdOrExists = [self createDocumentationFolderIfMissingWithError: outError];
        if (!createdOrExists)
            return nil;
    }
    
    //If the folder is now available, search the rest of the gamebox for documentation files to fill it with.
    if ([docsURL checkResourceIsReachableAndReturnError: outError])
    {
        NSArray *foundDocumentation = [self.class URLsForDocumentationInLocation: self.bundleURL
                                                            searchSubdirectories: YES];
        
        for (NSURL *documentURL in foundDocumentation)
        {
            NSURL *symlinkURL = [self addDocumentationSymlinkToURL: documentURL
                                                         withTitle: nil
                                                          ifExists: BXGameboxDocumentationRename
                                                             error: outError];
            
            //If any of the documentation items couldn't be created, bail out and treat the whole operation
            //as having failed.
            if (!symlinkURL)
                return nil;
        }
        
        return self.documentationURLs;
    }
    else return nil;
}

- (BOOL) hasDocumentationFolder
{
    return [self.documentationFolderURL checkResourceIsReachableAndReturnError: NULL];
}

- (NSURL *) _addDocumentationFromURL: (NSURL *)documentationURL
                           withTitle: (NSString *)title
                           operation: (BXGameboxDocumentationOperation)operation
                            ifExists: (BXGameboxDocumentationConflictBehaviour)conflictBehaviour
                               error: (out NSError **)outError
{    
    NSFileManager *manager = [[NSFileManager alloc] init];
    NSURL *docsURL = self.documentationFolderURL;
    
    //Do not import files that are already rooted in the documentation folder itself.
    if ([documentationURL isBasedInURL: docsURL])
        return documentationURL;
    
    //Create the documentation URL if it's not already there, and fail if we cannot create it.
    BOOL created = [self createDocumentationFolderIfMissingWithError: outError];
    if (!created)
        return nil;
    
    //Make the copy/symlink in a temporary folder before moving it to the final documentation folder.
    NSURL *intermediateBaseURL = [manager URLForDirectory: NSItemReplacementDirectory
                                                 inDomain: NSUserDomainMask
                                        appropriateForURL: docsURL
                                                   create: YES
                                                    error: outError];
    
    NSURL *intermediateURL;
    if (intermediateBaseURL)
    {
        intermediateURL = [intermediateBaseURL URLByAppendingPathComponent: documentationURL.lastPathComponent
                                                               isDirectory: NO];
        
        BOOL succeeded;
        if (operation == BXGameboxDocumentationSymlink)
        {
            succeeded = [manager createSymbolicLinkAtURL: intermediateURL
                                      withDestinationURL: documentationURL
                                                   error: outError];
        }
        else
        {
            succeeded = [manager copyItemAtURL: documentationURL
                                         toURL: intermediateURL
                                         error: outError];
        }
        
        //If for some reason we couldn't copy or symlink, clean up our temporary folder before we bail out.
        if (!succeeded)
        {
            [manager removeItemAtURL: intermediateBaseURL error: NULL];
            return nil;
        }
    }
    //If we couldn't create the temporary folder, bail out.
    else
    {
        return nil;
    }
    
    //Once we've created the intermediate file, try moving it to the final destination.
    if (!title.length)
        title = documentationURL.lastPathComponent.stringByDeletingPathExtension;

    NSString *destinationName = [title stringByAppendingPathExtension: documentationURL.pathExtension];
    NSURL *destinationURL = [docsURL URLByAppendingPathComponent: destinationName isDirectory: NO];
    NSUInteger increment = 1;
    NSError *moveError = nil;
    
    [self willChangeValueForKey: @"documentationURLs"];
    
    while (![manager moveItemAtURL: intermediateURL toURL: destinationURL error: &moveError])
    {
        //If file couldn't be moved because there already was a file at the destination,
        //then decide what to do based on our conflict resolution behaviour.
        //IMPLEMENTATION NOTE: NSFileWriteFileExistsError was only defined in 10.7 and may not be returned
        //by 10.6 and below. So, we also check if the symlink URL could be accessed, and if it could then
        //we assume that this pre-existing file was the failure reason.
        if ([moveError matchesDomain: NSCocoaErrorDomain code: NSFileWriteFileExistsError] ||
            [destinationURL checkResourceIsReachableAndReturnError: NULL])
        {
            //If we should overwrite the existing item, or if the existing item is a symlink
            //to this same resource, then simply replace it with the temporary file.
            if (conflictBehaviour == BXGameboxDocumentationReplace || [destinationURL.URLByResolvingSymlinksInPath isEqual: documentationURL])
            {
                BOOL swapped = [manager replaceItemAtURL: destinationURL
                                           withItemAtURL: intermediateURL
                                          backupItemName: nil
                                                 options: 0
                                        resultingItemURL: NULL
                                                   error: outError];
                
                //If we cannot replace the existing item then bail out. We'll clean up downstairs.
                if (!swapped)
                {
                    destinationURL = nil;
                    break;
                }
            }
            //Otherwise, append a number to the destination name and try again.
            else
            {
                increment += 1;
                destinationName = [NSString stringWithFormat: @"%@ (%lu).%@", title, (unsigned long)
                                   increment, documentationURL.pathExtension];
                destinationURL = [docsURL URLByAppendingPathComponent: destinationName isDirectory: NO];
            }
        }
        //If the move operation failed for some other reason, the error isn't one we know how to deal with
        //and we should pass it upstream.
        else
        {
            if (outError)
                *outError = moveError;
            
            destinationURL = nil;
        }
    }
    
    [self didChangeValueForKey: @"documentationURLs"];
    
    //Clean up our temporary folder on our way out, regardless of success or failure.
    [manager removeItemAtURL: intermediateBaseURL error: NULL];
    
    if (destinationURL != nil)
    {
        //If we succeeded, record an undo operation for this.
        NSUndoManager *undoManager = [self.undoDelegate undoManagerForClient: self operation: _cmd];
        if (undoManager.isUndoRegistrationEnabled)
        {
            id undoProxy = [undoManager prepareWithInvocationTarget: self];
            //NOTE: error information will be lost if the document cannot be trashed,
            //since we will have no upstream context for it.
            [undoProxy removeDocumentationURL: destinationURL
                                 resultingURL: NULL
                                        error: NULL];
        }
        
        //If this was a move operation and we succeeded, then finish by removing the original file.
        if (operation == BXGameboxDocumentationMove)
            [manager removeItemAtURL: documentationURL error: NULL];
    }
    
    return destinationURL;
}

- (NSURL *) addDocumentationFileFromURL: (NSURL *)documentationURL
                              withTitle: (NSString *)title
                               ifExists: (BXGameboxDocumentationConflictBehaviour)conflictBehaviour
                                  error: (out NSError **)outError
{
    return [self _addDocumentationFromURL: documentationURL
                                withTitle: title
                                operation: BXGameboxDocumentationCopy
                                 ifExists: conflictBehaviour
                                    error: outError];
}

//Adds a symlink to the specified URL into the gamebox's documentation folder, creating it if it is missing.
//Returns YES on success, or NO and populates outError on failure.
- (NSURL *) addDocumentationSymlinkToURL: (NSURL *)documentationURL
                               withTitle: (NSString *)title
                                ifExists: (BXGameboxDocumentationConflictBehaviour)conflictBehaviour
                                   error: (out NSError **)outError
{
    return [self _addDocumentationFromURL: documentationURL
                                withTitle: title
                                operation: BXGameboxDocumentationSymlink
                                 ifExists: conflictBehaviour
                                    error: outError];
}

- (BOOL) _isSymlinkAtURL: (NSURL *)URL
{
    NSNumber *symlinkFlag = nil;
    BOOL checked = [URL getResourceValue: &symlinkFlag forKey: NSURLIsSymbolicLinkKey error: NULL];
    
    return (checked && symlinkFlag.boolValue);
}

- (BOOL) removeDocumentationURL: (NSURL *)documentationURL
                   resultingURL: (out NSURL **)resultingURL
                          error: (out NSError **)outError
{
    if ([documentationURL isBasedInURL: self.documentationFolderURL])
    {
        //IMPLEMENTATION NOTE: NSFileManager's trashItemAtURL: does a Very Bad Thing and resolves symlinks
        //without telling us, trashing the original file instead of the symlink. So, we first check if the
        //specified URL is a symlink: if so, we delete it instead of trashing.        
        if ([self _isSymlinkAtURL: documentationURL])
        {
            NSURL *targetURL = documentationURL.URLByResolvingSymlinksInPath;
            
            [self willChangeValueForKey: @"documentationURLs"];
            
            BOOL removed = [[NSFileManager defaultManager] removeItemAtURL: documentationURL
                                                                     error: outError];
            
            [self didChangeValueForKey: @"documentationURLs"];
            
            if (removed)
            {
                NSUndoManager *undoManager = [self.undoDelegate undoManagerForClient: self operation: _cmd];
                if (undoManager.isUndoRegistrationEnabled)
                {
                    NSString *restoredTitle = documentationURL.lastPathComponent.stringByDeletingPathExtension;
                    
                    id undoProxy = [undoManager prepareWithInvocationTarget: self];
                    //NOTE: error information will be lost if the document cannot be restored,
                    //since we will have no upstream context for it.
                    [undoProxy _addDocumentationFromURL: targetURL
                                              withTitle: restoredTitle
                                              operation: BXGameboxDocumentationSymlink
                                               ifExists: BXGameboxDocumentationRename
                                                  error: NULL];
                }
                
                if (resultingURL)
                    *resultingURL = targetURL;
                
                return YES;
            }
            else
                return NO;
        }
        else
        {
            [self willChangeValueForKey: @"documentationURLs"];
            
            NSURL *trashedURL = nil;
            BOOL removed = [[NSFileManager defaultManager] trashItemAtURL: documentationURL
                                                         resultingItemURL: &trashedURL
                                                                    error: outError];
            
            [self didChangeValueForKey: @"documentationURLs"];
            
            if (removed)
            {
                NSUndoManager *undoManager = [self.undoDelegate undoManagerForClient: self operation: _cmd];
                if (undoManager.isUndoRegistrationEnabled)
                {
                    NSString *restoredTitle = documentationURL.lastPathComponent.stringByDeletingPathExtension;
                    
                    id undoProxy = [undoManager prepareWithInvocationTarget: self];
                    //NOTE: error information will be lost if the document cannot be restored,
                    //since we will have no upstream context for it.
                    [undoProxy _addDocumentationFromURL: trashedURL
                                              withTitle: restoredTitle
                                              operation: BXGameboxDocumentationMove
                                               ifExists: BXGameboxDocumentationRename
                                                  error: NULL];
                }
                
                if (resultingURL)
                    *resultingURL = trashedURL;
                
                return YES;
            }
            else
                return NO;
        }
    }
    else
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain: BXGameboxErrorDomain
                                            code: BXDocumentationNotInFolderError
                                        userInfo: @{ NSURLErrorKey: documentationURL }];
        }
        return NO;
    }
}

- (BOOL) canTrashDocumentationURL: (NSURL *)documentationURL
{
    return [documentationURL isBasedInURL: self.documentationFolderURL] && self.isWritable;
}

- (BOOL) canAddDocumentationFromURL: (NSURL *)documentationURL
{
    return self.hasDocumentationFolder && self.isWritable;
}

- (NSArray *) documentationURLs
{
    NSURL *docsURL = self.documentationFolderURL;
    
    //If the documentation folder exists, return everything inside it.
    if ([docsURL checkResourceIsReachableAndReturnError: NULL])
    {
        NSArray *properties = @[NSURLTypeIdentifierKey];
        NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL: docsURL
                                                                 includingPropertiesForKeys: properties
                                                                                    options: NSDirectoryEnumerationSkipsHiddenFiles
                                                                               errorHandler: NULL];
        
        return enumerator.allObjects;
    }
    //Otherwise, search the rest of the gamebox for documentation.
    else
    {
        return [self.class URLsForDocumentationInLocation: self.bundleURL searchSubdirectories: YES];
    }
}

+ (NSArray *) URLsForDocumentationInLocation: (NSURL *)location searchSubdirectories: (BOOL)searchSubdirs
{
    NSArray *properties = @[NSURLTypeIdentifierKey];
    NSDirectoryEnumerationOptions options = NSDirectoryEnumerationSkipsHiddenFiles;
    if (!searchSubdirs)
        options |= NSDirectoryEnumerationSkipsSubdirectoryDescendants;
    
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL: location
                                                             includingPropertiesForKeys: properties
                                                                                options: options
                                                                           errorHandler: NULL];
    
    NSMutableArray *documentationURLs = [NSMutableArray array];
    for (NSURL *URL in enumerator)
    {
        if ([self isDocumentationFileAtURL: URL])
            [documentationURLs addObject: URL];
    }
    
    return documentationURLs;
}

+ (BOOL) isDocumentationFileAtURL: (NSURL *)URL
{
    NSString *fileType = URL.typeIdentifier;
    
    //Check if the specified file is of a type we recognise as documentation.
    //Note that we don't use our own smarter conformsToFileType: methods for this,
    //because there are some inherited filetypes that we want to avoid treating as documentation
    //(e.g. sourcecode files inherit from public.plain-text, and we don't want them to show
    //up in the documentation list.)
    if (!fileType || ![[BXFileTypes documentationTypes] containsObject: fileType])
        return NO;
    
    //Check if the specified file isn't on our blacklist of ignored documentation filenames.
    NSString *fileName = URL.lastPathComponent;
    for (NSString *pattern in [self documentationExclusions])
    {
        if ([fileName isMatchedByRegex: pattern
                               options: RKLCaseless
                               inRange: NSMakeRange(0, fileName.length)
                                 error: nil])
            return NO;
    }
    
    //If we get this far, it checks out as a documentation file.
    return YES;
}

@end


#pragma mark - Legacy API

#import "NSString+ADBPaths.h"
#import "ADBPathEnumerator.h"

@implementation BXGamebox (BXGameboxLegacyPathAPI)

+ (BXGamebox *) bundleWithPath: (NSString *)path
{
	return [[self alloc] initWithPath: path];
}

- (NSArray *) hddVolumes	{ return [self volumesOfTypes: [BXFileTypes hddVolumeTypes]]; }
- (NSArray *) cdVolumes		{ return [self volumesOfTypes: [BXFileTypes cdVolumeTypes]]; }
- (NSArray *) floppyVolumes	{ return [self volumesOfTypes: [BXFileTypes floppyVolumeTypes]]; }

- (NSArray *) volumesOfTypes: (NSSet *)acceptedTypes
{
	ADBPathEnumerator *enumerator = [ADBPathEnumerator enumeratorAtPath: self.resourcePath];
	enumerator.skipSubdirectories = YES;
	enumerator.fileTypes = acceptedTypes;
	return enumerator.allObjects;
}

- (NSString *) gamePath { return self.bundlePath; }

- (NSString *) targetPath
{
    NSString *targetPath = [self gameInfoForKey: BXTargetProgramGameInfoKey];
    
	//Resolve the path from a gamebox-relative path into an absolute path
    if (targetPath)
    {
        targetPath = [self.resourcePath stringByAppendingPathComponent: targetPath];
    }
    //If there's no target path stored in game info, check for an old-style symlink
    else
	{
		NSString *symlinkPath = [self pathForResource: BXTargetSymlinkName ofType: nil];
        targetPath = symlinkPath.stringByResolvingSymlinksInPath;
        
        if (targetPath)
        {
            //If the resolved symlink path is the same as the path to the symlink itself,
            //this indicates it was a broken link that could not be resolved
            if ([targetPath isEqualToString: symlinkPath]) targetPath = nil;
            else
            {
                //Once we've resolved the symlink, store it in the game info for future use
                self.targetPath = targetPath;
            }
        }
	}
    
	return targetPath;
}

- (void) setTargetPath: (NSString *)path
{
    if (path)
    {
        //Make the path relative to the game package
        NSString *basePath		= self.resourcePath;
        NSString *relativePath	= [path pathRelativeToPath: basePath];
        
        [self setGameInfo: relativePath forKey: BXTargetProgramGameInfoKey];
    }
    else
    {
        [self setGameInfo: nil forKey: BXTargetProgramGameInfoKey];
        
        //Delete any leftover symlink
		NSString *symlinkPath = [self pathForResource: BXTargetSymlinkName ofType: nil];
        [[NSFileManager defaultManager] removeItemAtPath: symlinkPath error: nil];
    }
}

- (BOOL) validateTargetPath: (id *)ioValue error: (NSError **)outError
{
	NSString *filePath = *ioValue;
    
    //Nil values will clear the target path
    if (filePath == nil) return YES;
    
	NSFileManager *manager = [NSFileManager defaultManager];
	
	//If the destination file does not exist, show an error
    //TWEAK: this condition is disabled for now, to allow links to files within
    //disk images.
    /*
     if (![manager fileExistsAtPath: filePath])
     {
     if (outError)
     {
     NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
     filePath, NSFilePathErrorKey,
     nil];
     *outError = [NSError errorWithDomain: NSCocoaErrorDomain
     code: NSFileNoSuchFileError
     userInfo: userInfo];
     }
     return NO;
     }
     */
	
	//Reject target paths that are not located inside the gamebox
	if (![filePath isRootedInPath: self.resourcePath])
	{
		if (outError)
		{
			NSString *format = NSLocalizedString(@"The file “%@” was not located inside this gamebox.",
												 @"Error message shown when trying to set the target path of a gamebox to a file outside the gamebox. %@ is the display filename of the file in question.");
			
			NSString *displayName = [manager displayNameAtPath: filePath];
			NSString *description = [NSString stringWithFormat: format, displayName];
			
			NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  filePath, NSFilePathErrorKey,
									  description, NSLocalizedDescriptionKey,
									  nil];
			
			*outError = [NSError errorWithDomain: BXGameboxErrorDomain
											code: BXTargetPathOutsideGameboxError
										userInfo: userInfo];
		}
		return NO;
	}
    
	return YES;
}

@end