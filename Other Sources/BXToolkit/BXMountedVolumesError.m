/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXMountedVolumesError.h"


NSString * const BXMountedVolumesErrorDomain = @"BXMountedVolumesErrorDomain";


@implementation BXMountedVolumesError

@end


@implementation BXCouldNotMountImageError

+ (id) errorWithImagePath: (NSString *)imagePath userInfo: (NSDictionary *)userInfo
{
	NSString *descriptionFormat = NSLocalizedString(
		@"The disk image “%@” could not be opened.",
		@"Error message shown after failing to mount an image. %@ is the display name of the disk image."
	);
	
	NSString *explanation = NSLocalizedString(
		@"The disk image file may be corrupted or incomplete.",
		@"Explanatory text for error message shown after failing to mount an image."
	);
	
	NSString *displayName			= [[NSFileManager defaultManager] displayNameAtPath: imagePath];
	if (!displayName) displayName	= imagePath.lastPathComponent;
	
	NSString *description = [NSString stringWithFormat: descriptionFormat, displayName];
	
	NSMutableDictionary *defaultInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										description,	NSLocalizedDescriptionKey,
										explanation,	NSLocalizedRecoverySuggestionErrorKey,
										imagePath,		NSFilePathErrorKey,
										nil];
	
	if (userInfo) [defaultInfo addEntriesFromDictionary: userInfo];
	
	return [self errorWithDomain: BXMountedVolumesErrorDomain
							code: BXMountedVolumesHDIUtilAttachFailed
						userInfo: defaultInfo];
}

@end