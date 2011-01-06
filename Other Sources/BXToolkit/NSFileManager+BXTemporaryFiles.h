/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXTemporaryFiles category extends NSFileManager with methods for creating temporary files
//and folders.

#import <Foundation/Foundation.h>

@interface NSFileManager (BXTemporaryFiles)

//Creates a new temporary directory with the specified prefix, to which will be appended a path
//extension of 8 randomly generated digits (a la mkdtemp().)
//Returns the full path to the new temporary directory, or nil and sets error if an error occurred.
- (NSString *) createTemporaryDirectoryWithPrefix: (NSString *)namePrefix error: (NSError **)error;

@end