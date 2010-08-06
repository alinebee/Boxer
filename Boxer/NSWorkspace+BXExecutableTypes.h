/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXExecutableTypes category extends NSWorkspace to add methods for verifying MS-DOS executables.

#import "NSWorkspace+BXFileTypes.h"

@interface NSWorkspace (BXExecutableTypes)

//Returns whether the file at the specified path is a windows-only executable.
//(This is determined using the UNIX file command, and occasionally results in false positives.)
- (BOOL) isWindowsOnlyExecutableAtPath: (NSString *)filePath;

@end
