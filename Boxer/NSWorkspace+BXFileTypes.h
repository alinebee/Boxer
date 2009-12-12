/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXFileTypes category extends NSWorkspace's methods for dealing with Uniform Type Identifiers (UTIs).

#import <Cocoa/Cocoa.h>

@interface NSWorkspace (BXFileTypes)
//Returns whether the file at the specified path matches any of the specified UTI filetypes:
//i.e. whether the file's UTI is equal to *or inherits from* any of those types.
- (BOOL) file: (NSString *)filePath matchesTypes: (NSArray *)acceptedTypes;

//Returns the nearest parent folder of the specified path which matches any of the specified UTIs,
//or nil if no folder matched. This may return filePath, if the file itself matches the specified types.
- (NSString *)parentOfFile: (NSString *)filePath matchingTypes: (NSArray *)acceptedTypes;
@end
