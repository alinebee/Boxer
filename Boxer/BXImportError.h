/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXImportError defines custom import-related errors.

#import <Foundation/Foundation.h>


//Error domains and codes
extern NSString * const BXImportErrorDomain;
enum
{ 
	BXImportNoExecutablesInSourcePath,
	BXImportSourcePathIsWindowsOnly,
};

@interface BXImportError : NSError
@end

@interface BXImportNoExecutablesError : BXImportError
+ (id) errorWithSourcePath: (NSString *)sourcePath userInfo: (NSDictionary *)userInfo;
@end

@interface BXImportWindowsOnlyError : BXImportError
+ (id) errorWithSourcePath: (NSString *)sourcePath userInfo: (NSDictionary *)userInfo;
- (NSString *) helpAnchor;
@end
