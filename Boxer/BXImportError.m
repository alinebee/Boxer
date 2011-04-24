/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXImportError.h"


NSString * const BXImportErrorDomain = @"BXImportErrorDomain";


@implementation BXImportError

+ (NSString *)displayNameForPath: (NSString *)path
{
	NSString *displayName			= [[NSFileManager defaultManager] displayNameAtPath: path];
	if (!displayName) displayName	= [path lastPathComponent];
	return displayName;
}
@end


@implementation BXImportNoExecutablesError

+ (id) errorWithSourcePath: (NSString *)sourcePath userInfo: (NSDictionary *)userInfo
{
	NSString *descriptionFormat = NSLocalizedString(@"“%@” does not contain any MS-DOS programs.",
													@"Error message shown when importing a folder with no executables in it. %@ is the display filename of the imported path.");
	
	NSString *suggestion = NSLocalizedString(@"This folder may contain a game for another platform which is not supported by Boxer.",
											 @"Explanation text shown when importing a folder with no executables in it.");
	
	NSString *description = [NSString stringWithFormat: descriptionFormat, [self displayNameForPath: sourcePath], nil];
	
	
	NSMutableDictionary *defaultInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										description,	NSLocalizedDescriptionKey,
										suggestion,		NSLocalizedRecoverySuggestionErrorKey,
										sourcePath,		NSFilePathErrorKey,
										nil];
	
	if (userInfo) [defaultInfo addEntriesFromDictionary: userInfo];
	
	return [self errorWithDomain: BXImportErrorDomain
							code: BXImportNoExecutablesInSourcePath
						userInfo: defaultInfo];
}

@end


@implementation BXImportWindowsOnlyError

+ (id) errorWithSourcePath: (NSString *)sourcePath userInfo: (NSDictionary *)userInfo
{
	NSString *descriptionFormat = NSLocalizedString(
		@"“%@” is a Microsoft Windows game or application, which Boxer does not support.",
		@"Error message shown when importing a folder that contains a Windows-only game. %@ is the display filename of the imported path."
	);
	
	NSString *suggestion = NSLocalizedString(
		@"You may be able to run it in a Windows emulator instead, such as CrossOver Games.",
		@"Informative text of warning sheet after running a Windows-only executable or importing a Windows-only game."
	);
	
	NSString *description = [NSString stringWithFormat: descriptionFormat, [self displayNameForPath: sourcePath], nil];
	
	NSMutableDictionary *defaultInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										description,	NSLocalizedDescriptionKey,
										suggestion,		NSLocalizedRecoverySuggestionErrorKey,
										sourcePath,		NSFilePathErrorKey,
										nil];
	
	if (userInfo) [defaultInfo addEntriesFromDictionary: userInfo];
	
	return [self errorWithDomain: BXImportErrorDomain
							code: BXImportSourcePathIsWindowsOnly
						userInfo: defaultInfo];
}

- (NSString *) helpAnchor
{
	return @"windows-only-programs";
}
@end
