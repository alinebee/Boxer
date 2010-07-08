/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXPaths category extends NSString to add a few helpful path-related methods.

#import <Cocoa/Cocoa.h>

@interface NSString (BXPaths)

//Performs a sort comparison based on the number of components in the file path, from shallowest to deepest.
- (NSComparisonResult) pathDepthCompare: (NSString *)comparison;

//Not currently used and should be moved to a different category.
//- (NSString *) stringByReplacingCharactersInSet: (NSCharacterSet *)characterSet withString: (NSString *) replacement;

//Returns an NSString path relative to another path:
//This standardizes both paths, trims any shared parent path, and then adds "../"s as necessary.
//e.g. [@"/Library/Frameworks" pathRelativeToPath: @"/Library/Caches"] will return @"../Frameworks".
- (NSString *) pathRelativeToPath: (NSString *)basePath;

//A stricter version of hasPrefix:, which checks whether one path is contained inside another.
//Note that this does no path standardization - you should do this first if needed.
- (BOOL) isRootedInPath: (NSString *)rootPath;

@end
