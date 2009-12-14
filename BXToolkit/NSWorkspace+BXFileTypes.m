/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "NSWorkspace+BXFileTypes.h"

@implementation NSWorkspace (BXFileTypes)
- (BOOL) file: (NSString *)filePath matchesTypes: (NSArray *)acceptedTypes
{
	NSString *fileType = [self typeOfFile: filePath error: nil];
	if (fileType)
	{
		NSString *fileExtension	= [filePath pathExtension];
		BOOL testExtension		= [fileExtension length] > 0;

		for (NSString *acceptedType in acceptedTypes)
		{
			if ([self type: fileType conformsToType: acceptedType]) return YES;
			//NSWorkspace typeOfFile: has a bug whereby it may return an overly generic UTI for a file or folder
			//instead of a proper specific UTI. So, we also also check the file extension to be sure.
			if (testExtension && [self filenameExtension: fileExtension isValidForType: acceptedType]) return YES;
		}
	}
	return NO;
}

- (NSString *)parentOfFile: (NSString *)filePath matchingTypes: (NSArray *)acceptedTypes
{
	do
	{
		if ([self file: filePath matchesTypes: acceptedTypes]) return filePath;
		filePath = [filePath stringByDeletingLastPathComponent];
	}
	while ([filePath length] && ![filePath isEqualToString: @"/"]);
	return nil;
}
@end
