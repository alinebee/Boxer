/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXSessionError.h"
#import "BXDrive.h"
#import "BXGamebox.h"
#import "BXValueTransformers.h"

NSString * const BXSessionErrorDomain = @"BXSessionErrorDomain";

@implementation BXSessionError

//Helper method for getting human-readable names from paths.
+ (NSString *) displayNameForPath: (NSString *)path
{
	NSString *displayName			= [[NSFileManager defaultManager] displayNameAtPath: path];
	if (!displayName) displayName	= [path lastPathComponent];
	return displayName;
}

@end

@implementation BXImportError
@end


@implementation BXSessionCannotMountSystemFolderError

+ (id) errorWithPath: (NSString *)folderPath userInfo: (NSDictionary *)userInfo
{
    NSString *descriptionFormat = NSLocalizedString(@"MS-DOS is not permitted to access OS X system folders like “%@”.",
                                                    @"Error message shown when user tries to mount a system folder as a DOS drive. %@ is the requested folder path."
                                                    );
    
    NSString *suggestion = NSLocalizedString(@"Instead, choose one of your own folders, or a disc mounted in OS X.", @"Recovery suggestion shown when user tries to mount a system folder as a DOS drive.");
    
    NSString *description = [NSString stringWithFormat: descriptionFormat, [self displayNameForPath: folderPath]];
    NSMutableDictionary *defaultInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                        description,    NSLocalizedDescriptionKey,
                                        suggestion,     NSLocalizedRecoverySuggestionErrorKey,
                                        folderPath,     NSFilePathErrorKey,
                                        nil];
    
	if (userInfo) [defaultInfo addEntriesFromDictionary: userInfo];
    
	return [self errorWithDomain: BXSessionErrorDomain
							code: BXSessionCannotMountSystemFolder
						userInfo: defaultInfo];
}
@end


@implementation BXImportNoExecutablesError

+ (id) errorWithSourcePath: (NSString *)sourcePath userInfo: (NSDictionary *)userInfo
{
	NSString *descriptionFormat = NSLocalizedString(@"“%@” does not contain any MS-DOS programs.",
													@"Error message shown when importing a folder with no executables in it. %@ is the display filename of the imported path.");
	
	NSString *suggestion = NSLocalizedString(@"This folder may contain a game for another platform which is not supported by Boxer.",
											 @"Explanation text shown when importing a folder with no executables in it.");
	
	NSString *description = [NSString stringWithFormat: descriptionFormat, [self displayNameForPath: sourcePath]];
	
	
	NSMutableDictionary *defaultInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										description,	NSLocalizedDescriptionKey,
										suggestion,		NSLocalizedRecoverySuggestionErrorKey,
										sourcePath,		NSFilePathErrorKey,
										nil];
	
	if (userInfo) [defaultInfo addEntriesFromDictionary: userInfo];
	
	return [self errorWithDomain: BXSessionErrorDomain
							code: BXImportNoExecutablesInSourcePath
						userInfo: defaultInfo];
}

@end


@implementation BXImportWindowsOnlyError

+ (id) errorWithSourcePath: (NSString *)sourcePath userInfo: (NSDictionary *)userInfo
{
	NSString *descriptionFormat = NSLocalizedString(
		@"“%@” is a Windows game. Boxer only supports MS-DOS games.",
		@"Error message shown when importing a folder that contains a Windows-only game or Windows installer. %@ is the display filename of the imported path."
	);
	
	NSString *suggestion = NSLocalizedString(
		@"You can run this game in a Windows emulator instead. For more help, click the ? button.",
		@"Informative text of warning sheet after importing a Windows-only game."
	);
	
	NSString *description = [NSString stringWithFormat: descriptionFormat, [self displayNameForPath: sourcePath]];
	
	NSMutableDictionary *defaultInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										description,	NSLocalizedDescriptionKey,
										suggestion,		NSLocalizedRecoverySuggestionErrorKey,
										sourcePath,		NSFilePathErrorKey,
										nil];
	
	if (userInfo) [defaultInfo addEntriesFromDictionary: userInfo];
	
	return [self errorWithDomain: BXSessionErrorDomain
							code: BXImportSourcePathIsWindowsOnly
						userInfo: defaultInfo];
}

- (NSString *) helpAnchor
{
	return @"windows-games";
}
@end


@implementation BXImportHybridCDError

+ (id) errorWithSourcePath: (NSString *)sourcePath userInfo: (NSDictionary *)userInfo
{
	NSString *descriptionFormat = NSLocalizedString(@"“%@” is a Mac+PC hybrid disc, which Boxer cannot import.",
                                                    @"Error message shown when importing a hybrid Mac/PC CD. %@ is the display filename of the imported path.");
	
	NSString *suggestion = NSLocalizedString(@"You can insert the disc into a Windows PC instead, and copy the DOS version of the game from there to your Mac. For more help, click the ? button.",
                                             @"Informative text of warning sheet when importing a hybrid Mac/PC CD.");
	
	NSString *description = [NSString stringWithFormat: descriptionFormat, [self displayNameForPath: sourcePath]];
	
	NSMutableDictionary *defaultInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										description,	NSLocalizedDescriptionKey,
										suggestion,		NSLocalizedRecoverySuggestionErrorKey,
										sourcePath,		NSFilePathErrorKey,
										nil];
	
	if (userInfo) [defaultInfo addEntriesFromDictionary: userInfo];
	
	return [self errorWithDomain: BXSessionErrorDomain
							code: BXImportSourcePathIsHybridCD
						userInfo: defaultInfo];
}

- (NSString *) helpAnchor
{
	return @"hybrid-cds";
}
@end

@implementation BXImportMacAppError

+ (id) errorWithSourcePath: (NSString *)sourcePath userInfo: (NSDictionary *)userInfo
{
	NSString *descriptionFormat = NSLocalizedString(@"“%@” is a Mac OS game. Boxer only supports MS-DOS games.",
                                                    @"Error message shown when importing a folder that contains a Mac game. %@ is the display filename of the imported path.");
	
	NSString *suggestion = NSLocalizedString(@"If you cannot play this game in OS X, you may be able to play it in a Classic Mac OS emulator instead. For more help, click the ? button.",
                                             @"Informative text of warning sheet after importing a Mac application.");
	
	NSString *description = [NSString stringWithFormat: descriptionFormat, [self displayNameForPath: sourcePath]];
	
	NSMutableDictionary *defaultInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										description,	NSLocalizedDescriptionKey,
										suggestion,		NSLocalizedRecoverySuggestionErrorKey,
										sourcePath,		NSFilePathErrorKey,
										nil];
	
	if (userInfo) [defaultInfo addEntriesFromDictionary: userInfo];
	
	return [self errorWithDomain: BXSessionErrorDomain
							code: BXImportSourcePathIsMacOSApp
						userInfo: defaultInfo];
}

- (NSString *) helpAnchor
{
	return @"macos-games";
}
@end


@implementation BXImportDriveUnavailableError

+ (id) errorWithSourcePath: (NSString *)sourcePath drive: (BXDrive *)drive userInfo: (NSDictionary *)userInfo
{
    NSString *drivePath = drive.sourceURL.path;
	NSString *descriptionFormat = NSLocalizedString(@"“%1$@” requires extra files that are currently unavailable.",
                                                    @"Error message shown when importing a folder that has missing drives. %1$@ is the display filename of the imported path.");
	
	NSString *suggestionFormat = NSLocalizedString(@"Please ensure that the resource “%1$@” is available, then retry the import.",
                                                   @"Informative text of warning shown when importing a folder that has missing drives. %1$@ is the missing drive path.");
	
    //NSValueTransformer *drivePathFormatter = [[BXDisplayPathTransformer alloc] initWithJoiner: @" ▸ " maxComponents: 0];
    
	NSString *description = [NSString stringWithFormat: descriptionFormat, [self displayNameForPath: sourcePath]];
    NSString *suggestion = [NSString stringWithFormat: suggestionFormat, drivePath];
	
    //[drivePathFormatter release];
    
	NSMutableDictionary *defaultInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										description,	NSLocalizedDescriptionKey,
										suggestion,		NSLocalizedRecoverySuggestionErrorKey,
										sourcePath,		NSFilePathErrorKey,
										nil];
	
	if (userInfo) [defaultInfo addEntriesFromDictionary: userInfo];
	
	return [self errorWithDomain: BXSessionErrorDomain
							code: BXImportDriveUnavailable
						userInfo: defaultInfo];
}
@end



@implementation BXGameStateGameboxMismatchError

+ (id) errorWithStateURL: (NSURL *)stateURL gamebox: (BXGamebox *)gamebox userInfo: (NSDictionary *)userInfo
{
    NSString *displayName = stateURL.lastPathComponent;
    [stateURL getResourceValue: &displayName forKey: NSURLLocalizedNameKey error: NULL];
    
	NSString *descriptionFormat = NSLocalizedString(@"“%1$@” contains game data for a different game.",
                                                    @"Error message shown when importing a folder that has missing drives. %1$@ is the display filename of the imported path.");
	
	NSString *suggestionFormat = NSLocalizedString(@"Please provide a game data file that was exported from %1$@.",
                                                   @"Informative text of warning shown when importing a folder that has missing drives. %1$@ is the missing drive path.");
	
    //NSValueTransformer *drivePathFormatter = [[BXDisplayPathTransformer alloc] initWithJoiner: @" ▸ " maxComponents: 0];
    
	NSString *description = [NSString stringWithFormat: descriptionFormat, displayName];
    NSString *suggestion = [NSString stringWithFormat: suggestionFormat, gamebox.gameName];
	
    //[drivePathFormatter release];
    
	NSMutableDictionary *defaultInfo = [NSMutableDictionary dictionaryWithDictionary: @{
        NSLocalizedDescriptionKey: description,
        NSLocalizedRecoverySuggestionErrorKey: suggestion,
        NSURLErrorKey: stateURL
    }];
	
	if (userInfo) [defaultInfo addEntriesFromDictionary: userInfo];
	
	return [self errorWithDomain: BXSessionErrorDomain
							code: BXGameStateGameboxMismatch
						userInfo: defaultInfo];
}
@end