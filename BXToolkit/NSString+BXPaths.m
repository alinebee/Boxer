/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "NSString+BXPaths.h"

@implementation NSString (BXPaths)

- (NSComparisonResult) pathDepthCompare: (NSString *)comparison
{
	NSUInteger v1 = [[self pathComponents] count];
    NSUInteger v2 = [[comparison pathComponents] count];
	
    if (v1 < v2)		return NSOrderedAscending;
    else if (v1 > v2)	return NSOrderedDescending;
    else				return NSOrderedSame;
}

/*
- (NSString *) stringByReplacingCharactersInSet: (NSCharacterSet *)characterSet withString: (NSString *) replacement
{
	NSArray *parts = [self componentsSeparatedByCharactersInSet: characterSet];
	return [parts componentsJoinedByString: replacement];
}
*/

- (NSString *) pathRelativeToPath: (NSString *)basePath
{
	//First, standardize both paths
	basePath				= [basePath stringByStandardizingPath];
	NSString *originalPath	= [self stringByStandardizingPath];
	
	NSArray *components		= [originalPath pathComponents];
	NSArray *baseComponents	= [basePath pathComponents];
	NSUInteger numInPath	= [components count];
	NSUInteger numInBase	= [baseComponents count];
	NSUInteger from, upTo	= MIN(numInBase, numInPath);
	
	//Skip over any common prefixes
	for (from=0; from<upTo; from++)
	{
		if (![[components objectAtIndex: from] isEqualToString: [baseComponents objectAtIndex: from]]) break;
	}
	
	NSUInteger i, stepsBack = (numInBase - from);
	NSMutableArray *relativeComponents = [NSMutableArray arrayWithCapacity: stepsBack + numInPath - from];
	//First, add the steps to get back to the first common directory
	for (i=0; i<stepsBack; i++) [relativeComponents addObject: @".."];
	//Then, add the steps from there to the original path
	[relativeComponents addObjectsFromArray: [components subarrayWithRange: NSMakeRange(from, numInPath - from)]];
	
	return [NSString pathWithComponents: relativeComponents];
}

- (BOOL) isRootedInPath: (NSString *)rootPath
{
	//A quick way of catching paths that won't match
	if (![self hasPrefix: rootPath]) return NO;
	
	NSArray *components		= [self pathComponents];
	NSArray *rootComponents = [rootPath pathComponents];
	NSUInteger lastIndex	= [rootComponents count] - 1;
	
	//Now test whether the last component in the root path is equal to the equivalent in our own path
	return [[components objectAtIndex: lastIndex] isEqualToString: [rootComponents lastObject]];
}

@end