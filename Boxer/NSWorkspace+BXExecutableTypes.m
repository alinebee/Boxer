/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "NSWorkspace+BXExecutableTypes.h"
#import "RegexKitLite.h"

@implementation NSWorkspace (BXExecutableTypes)

- (BOOL) isWindowsOnlyExecutableAtPath: (NSString *)filePath
{
	//Short-circuit: only bother checking EXE files, not other types.
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
		
		BOOL isWindowsOnly = ([outputString rangeOfString: @"Windows"].location != NSNotFound);
		[outputString release];
		return isWindowsOnly;
	}
	//If there was a problem, assume the file wasn't a windows executable
	//TODO: we should populate an error message
	else return NO;
}

@end
