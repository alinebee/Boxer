/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXPackage.h"
#import "NSString+BXPaths.h"
#import "NSWorkspace+BXFileTypes.h"
#import "NSWorkspace+BXIcons.h"
#import "BXAppController.h"
#import "RegexKitLite.h"
#import "BXDigest.h"
#import "NSData+HexStrings.h"
#import "BXPathEnumerator.h"

#pragma mark -
#pragma mark Constants

//Application-wide constants.
NSString * const BXGameIdentifierKey = @"BXGameIdentifier";
NSString * const BXGameIdentifierTypeKey = @"BXGameIdentifierType";

NSString * const BXTargetSymlinkName			= @"DOSBox Target";
NSString * const BXConfigurationFileName		= @"DOSBox Preferences";
NSString * const BXConfigurationFileExtension	= @"conf";
NSString * const BXGameInfoFileName				= @"Game Info";
NSString * const BXGameInfoFileExtension		= @"plist";
NSString * const BXDocumentationFolderName		= @"Documentation";

NSString * const BXGameboxErrorDomain = @"BXGameboxErrorDomain";


//When calculating a digest from the gamebox's EXEs, read only the first 64kb of each EXE.
#define BXGameIdentifierEXEDigestStubLength 65536


#pragma mark -
#pragma mark Private method declarations

@interface BXPackage ()
@property (readwrite, retain, nonatomic) NSDictionary *gameInfo;

//Arrays of paths to discovered files of particular types within the gamebox.
//BXPackage's documentation and executables accessors call these internal methods and cache the results.
- (NSArray *) _foundDocumentation;
- (NSArray *) _foundExecutables;
- (NSArray *) _foundResourcesOfTypes: (NSSet *)fileTypes startingIn: (NSString *)basePath;

//Returns a new auto-generated identifier based on this gamebox's name.
//On return, type will be the type of identifier generated.
- (NSString *) _generatedIdentifierOfType: (BXGameIdentifierType *)type;

//Save the game info back to the gamebox.
- (void) _persistGameInfo;
@end


@implementation BXPackage
@synthesize gameInfo;

+ (NSSet *) documentationTypes
{
	static NSSet *types = nil;
	if (!types) types = [[NSSet alloc] initWithObjects:
		@"public.jpeg",
		@"public.plain-text",
		@"public.png",
		@"com.compuserve.gif",
		@"com.adobe.pdf",
		@"public.rtf",
		@"com.microsoft.bmp",
		@"com.microsoft.word.doc",
		@"public.html",
	nil];
	return types;
}

//We ignore files with these names when considering which documentation files are likely to be worth showing
//TODO: read this data from a configuration plist instead
+ (NSSet *) documentationExclusions
{
	static NSSet *exclusions = nil;
	if (!exclusions) exclusions = [[NSSet alloc] initWithObjects:
		@"install.gif",
		@"install.txt",
		@"interp.txt",
		@"order.txt",
		@"orderfrm.txt",
		@"license.txt",
	nil];
	return exclusions;
}

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

+ (BXPackage *)bundleWithPath: (NSString *)path
{
	return [[[self alloc] initWithPath: path] autorelease];
}

- (void) dealloc
{
	[self setGameInfo: nil], [gameInfo release];
	[super dealloc];
}

- (NSArray *) hddVolumes	{ return [self volumesOfTypes: [BXAppController hddVolumeTypes]]; }
- (NSArray *) cdVolumes		{ return [self volumesOfTypes: [BXAppController cdVolumeTypes]]; }
- (NSArray *) floppyVolumes	{ return [self volumesOfTypes: [BXAppController floppyVolumeTypes]]; }

- (NSArray *) volumesOfTypes: (NSSet *)acceptedTypes
{
	BXPathEnumerator *enumerator = [BXPathEnumerator enumeratorAtPath: [self resourcePath]];
	[enumerator setSkipSubdirectories: YES];
	[enumerator setFileTypes: acceptedTypes];
	return [enumerator allObjects];
}

- (NSString *) gamePath { return [self bundlePath]; }

- (NSString *) targetPath
{
	//Retrieve the target path from the symlink the first time it is requested, then cache it for later
	if (!targetPath)
	{
		NSString *symlinkPath = [self pathForResource: BXTargetSymlinkName ofType: nil];
		targetPath = [symlinkPath stringByResolvingSymlinksInPath];
	
		//If the path is unchanged, this indicates a broken link
		if ([targetPath isEqualToString: symlinkPath]) targetPath = nil;
		else [targetPath copy];
	}
	return targetPath;
}

- (void) setTargetPath: (NSString *)path
{
	if (![targetPath isEqualToString: path])
	{
		[targetPath release];
		targetPath = [path copy];
		
		//Now persist the target path as a symlink
		//----------------------------------------
		
		NSFileManager *manager	= [NSFileManager defaultManager];
		NSString *linkLocation	= [[self resourcePath] stringByAppendingPathComponent: BXTargetSymlinkName];
		
		//Todo: handle errors better (at all)!
		//First, attempt to delete any existing link
		[manager removeItemAtPath: linkLocation error: nil];
		
		//If a new path was specified, create a new link
		if (path)
		{
			//Make the link relative to the game package
			NSString *basePath		= [self resourcePath];
			NSString *relativePath	= [path pathRelativeToPath: basePath];
		
			[manager createSymbolicLinkAtPath: linkLocation withDestinationPath: relativePath error: nil];
		}
	}
}

- (BOOL) validateTargetPath: (id *)ioValue error: (NSError **)outError
{
	NSString *filePath = *ioValue;
	NSFileManager *manager = [NSFileManager defaultManager];
	
	//If the file does not exist, show an error
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
	
	//Reject target paths that are not located inside the gamebox
	if (![filePath isRootedInPath: [self gamePath]])
	{
		if (outError)
		{
			NSString *format = NSLocalizedString(@"The file “%@” was not located inside this gamebox.",
												 @"Error message shown when trying to set the target path of a gamebox to a file outside the gamebox. %@ is the display filename of the file in question.");
			
			NSString *displayName = [manager displayNameAtPath: filePath];
			NSString *description = [NSString stringWithFormat: format, displayName, nil];
			
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


- (NSString *) configurationFile
{
	return [self pathForResource: BXConfigurationFileName ofType: BXConfigurationFileExtension];
}


- (void) setConfigurationFile: (NSString *)filePath
{
	NSString *configLocation = [self configurationFilePath];
	
	if (![filePath isEqualToString: configLocation])
	{
		NSFileManager *manager = [NSFileManager defaultManager];
	
		//First, attempt to delete any existing configuration file
		[manager removeItemAtPath: configLocation error: nil];
		//Now, copy the new file in its place (if one was provided)
		if (filePath) [manager copyItemAtPath: filePath toPath: configLocation error: nil];		
	}
}

- (NSString *) configurationFilePath
{
	NSString *fileName = [BXConfigurationFileName stringByAppendingPathExtension: BXConfigurationFileExtension];
	return [[self resourcePath] stringByAppendingPathComponent: fileName];
}

//Set/return the cover art associated with this game package (currently, the package file's icon)
- (NSImage *) coverArt
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	if ([workspace fileHasCustomIcon: [self bundlePath]])
	{
		return [workspace iconForFile: [self bundlePath]];
	}
	else return nil;
}

- (void) setCoverArt: (NSImage *)image
{
	[[NSWorkspace sharedWorkspace] setIcon: image forFile: [self bundlePath] options: 0];
}

- (NSArray *) executables
{
	return [self _foundExecutables];
}

- (NSArray *) documentation
{
	return [self _foundDocumentation];
}

- (NSDictionary *) gameInfo
{
	//Load the game info from the gamebox's plist file the first time we need it.
	if (gameInfo == nil)
	{
		NSMutableDictionary *info = nil;
		
		NSString *infoPath = [self pathForResource: BXGameInfoFileName ofType: BXGameInfoFileExtension];
		if (infoPath) info = [NSMutableDictionary dictionaryWithContentsOfFile: infoPath];
		
		//If there was no plist file in the gamebox, create an empty dictionary instead.
		if (!info) info = [NSMutableDictionary dictionaryWithCapacity: 10];
		
		[self setGameInfo: info];
	}
	
	return gameInfo;
}

- (id) gameInfoForKey: (NSString *)key
{
	return [[self gameInfo] objectForKey: key];
}

- (void) setGameInfo: (id)info forKey: (NSString *)key
{
	[self willChangeValueForKey: @"gameInfo"];
	
	BOOL changed = !([[self gameInfoForKey: key] isEqual: info]);
	if (changed)
	{
		[(NSMutableDictionary *)[self gameInfo] setObject: info forKey: key];
		[self _persistGameInfo];		
	}
	[self didChangeValueForKey: @"gameInfo"];
}

- (NSString *) gameIdentifier
{
	NSString *identifier = [self gameInfoForKey: BXGameIdentifierKey];
	
	//If we don't have an identifier yet, generate a new one and add it to the game's metadata.
	if (!identifier)
	{
		BXGameIdentifierType generatedType = 0;
		identifier = [self _generatedIdentifierOfType: &generatedType];

		[gameInfo setObject: identifier forKey: BXGameIdentifierKey];
		[gameInfo setObject: [NSNumber numberWithUnsignedInteger: generatedType]
					 forKey: BXGameIdentifierTypeKey];
		[self _persistGameInfo];
	}
	
	return identifier;
}

- (NSString *) setGameIdentifier: (NSString *)identifier
{
	[gameInfo setObject: identifier forKey: BXGameIdentifierKey];
	[gameInfo setObject: [NSNumber numberWithUnsignedInteger: BXGameIdentifierUserSpecified]
				 forKey: BXGameIdentifierTypeKey];
}

- (NSString *) gameName
{
	NSFileManager *manager = [NSFileManager defaultManager];
	NSString *displayName = [manager displayNameAtPath: [self bundlePath]];

	//Strip the extension if it's .boxer, otherwise leave path extension intact
	//(as it could be a version number component, e.g. the ".1" in "Windows 3.1")
	if ([[[displayName pathExtension] lowercaseString] isEqualToString: @"boxer"])
		displayName = [displayName stringByDeletingPathExtension];
	
	return displayName;
}

- (void) refresh
{
	[self setGameInfo: nil];
}



#pragma mark -
#pragma mark Private methods

//Write the game info back to the plist file
- (void) _persistGameInfo
{
	if (gameInfo)
	{
		NSString *infoName = [BXGameInfoFileName stringByAppendingPathExtension: BXGameInfoFileExtension];
		NSString *infoPath = [[self resourcePath] stringByAppendingPathComponent: infoName];
		[gameInfo writeToFile: infoPath atomically: YES];
	}
}


//Trawl the package looking for DOS executables
//TODO: move filtering upstairs to BXSession, as we should not be determining application behaviour here.
- (NSArray *) _foundExecutables
{
	NSArray *foundExecutables	= [self _foundResourcesOfTypes: [BXAppController executableTypes] startingIn: [self gamePath]];
	NSPredicate *notExcluded	= [NSPredicate predicateWithFormat: @"NOT lastPathComponent.lowercaseString IN %@", [[self class] executableExclusions]];
	
	return [foundExecutables filteredArrayUsingPredicate: notExcluded];
}

- (NSArray *) _foundDocumentation
{
	//First, check if there is an explicitly-named documentation folder and use the contents of that if so
	NSArray *docsFolderContents = [self pathsForResourcesOfType: nil inDirectory: BXDocumentationFolderName];
	if ([docsFolderContents count])
	{
		NSPredicate *notHidden	= [NSPredicate predicateWithFormat: @"NOT lastPathComponent BEGINSWITH %@", @".", nil];
		return [docsFolderContents filteredArrayUsingPredicate: notHidden];
	}

	//Otherwise, go trawling through the entire game package looking for likely documentation
	NSArray *foundDocumentation	= [self _foundResourcesOfTypes: [[self class] documentationTypes] startingIn: [self gamePath]];
	NSPredicate *notExcluded	= [NSPredicate predicateWithFormat: @"NOT lastPathComponent.lowercaseString IN %@", [[self class] documentationExclusions]];

	return [foundDocumentation filteredArrayUsingPredicate: notExcluded];
}

- (NSArray *) _foundResourcesOfTypes: (NSSet *)fileTypes startingIn: (NSString *)basePath
{
	NSWorkspace *workspace	= [NSWorkspace sharedWorkspace];
	NSMutableArray *matches	= [NSMutableArray arrayWithCapacity: 10];
	
	for (NSString *path in [BXPathEnumerator enumeratorAtPath: basePath])
	{
		//Note that we don't use our own smarter file:matchesTypes: function for this,
		//because there are some inherited filetypes that we want to avoid matching.
		if ([fileTypes containsObject: [workspace typeOfFile: path error: nil]]) [matches addObject: path];
	}
	return matches;	
}

- (NSString *) _generatedIdentifierOfType: (BXGameIdentifierType *)type
{
	//If the gamebox contains executables, generate an identifier based on their hash.
	//TODO: move the choice of executables off to BXSession
	NSArray *foundExecutables = [self executables];
	if ([foundExecutables count])
	{
		NSData *digest = [BXDigest SHA1DigestForFiles: foundExecutables
										   upToLength: BXGameIdentifierEXEDigestStubLength];
		*type = BXGameIdentifierEXEDigest;
		
		return [digest stringWithHexBytes];
	}
	
	//Otherwise, generate a UUID.
	else
	{	
		CFUUIDRef     UUID;
		CFStringRef   UUIDString;
		
		UUID = CFUUIDCreate(kCFAllocatorDefault);
		UUIDString = CFUUIDCreateString(kCFAllocatorDefault, UUID);
		
		NSString *identifierWithUUID = [NSString stringWithString: (NSString *)UUIDString];
		
		CFRelease(UUID);
		CFRelease(UUIDString);
		
		*type = BXGameIdentifierUUID;

		return identifierWithUUID;
	}
}

@end
