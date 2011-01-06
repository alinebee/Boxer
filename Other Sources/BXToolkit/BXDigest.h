/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXDigest is a tool for generating hashes for sets of files.

#import <Foundation/Foundation.h>

@interface BXDigest : NSObject

//Returns an SHA1 digest built from every file in the specified file list.
+ (NSData *)SHA1DigestForFiles: (NSArray *)filePaths;

//Returns an SHA1 digest built from the first readLength bytes of every file in the specified file list.
//If readLength is 0, this behaves the same as SHA1DigestForFiles:
+ (NSData *)SHA1DigestForFiles: (NSArray *)filePaths upToLength: (NSUInteger)readLength;

@end