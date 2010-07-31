/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "NSWorkspace+BXFileTypes.h"
#import "RegexKitLite.h"

@implementation NSWorkspace (BXFileTypes)

- (BOOL) file: (NSString *)filePath matchesTypes: (NSSet *)acceptedTypes
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

- (NSString *) parentOfFile: (NSString *)filePath matchingTypes: (NSSet *)acceptedTypes
{
	do
	{
		if ([self file: filePath matchesTypes: acceptedTypes]) return filePath;
		filePath = [filePath stringByDeletingLastPathComponent];
	}
	while ([filePath length] && ![filePath isEqualToString: @"/"]);
	return nil;
}

- (BOOL) isWindowsExecutableAtPath: (NSString *)filePath
{
	//Short-circuit: only bother checking EXE files.
	if (![self file: filePath matchesTypes: [NSSet setWithObject: @"com.microsoft.windows-executable"]]) return NO;
	
	NSPipe *outputPipe = [NSPipe pipe];
	NSTask *fileMagic = [[NSTask alloc] init];
	
	[fileMagic setLaunchPath: @"/usr/bin/file"];
	[fileMagic setArguments: [NSArray arrayWithObjects: @"-b", filePath, nil]];
	[fileMagic setStandardOutput: outputPipe];
	
	[fileMagic launch];
	[fileMagic waitUntilExit];
	
	int status = [fileMagic terminationStatus];
	[fileMagic release];
	
	if (status == 0)
	{
		NSData *output = [[outputPipe fileHandleForReading] readDataToEndOfFile];
		NSString *outputString = [[NSString alloc] initWithData: output encoding: NSUTF8StringEncoding];
		
		BOOL isWindowsOnly = [outputString isMatchedByRegex: @"[^(OS/2 or )]Windows"];
		[outputString release];
		return isWindowsOnly;
	}
	//If there was a problem, assume the file wasn't a windows executable
	//TODO: we should populate an error message
	else return NO;
}
@end
