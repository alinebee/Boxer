/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXIcons is an NSWorkspace category to add methods for handling file and folder icons.

#import <Cocoa/Cocoa.h>

@interface NSWorkspace (BXIcons)

//Returns whether the file or folder at the specified path has a custom icon resource.
- (BOOL) fileHasCustomIcon: (NSString *)path;

@end
