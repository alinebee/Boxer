/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
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

- (NSArray *) fullPathComponents
{
	//Bail out early for empty strings
	if (![self length]) return [NSArray array];
	
	NSString *path = [self stringByStandardizingPath];
	NSString *rootPath = @"/";
	
	//Build an array of complete paths for each component
	NSMutableArray *paths = [[NSMutableArray alloc] initWithCapacity: 10];
	do
	{
		[paths addObject: path];
		path = [path stringByDeletingLastPathComponent];
	}
	while ([path length] && ![path isEqualToString: rootPath]);
	
	//Reverse the array to put the components back in their original order
	NSArray *reverse = [[paths reverseObjectEnumerator] allObjects];
	[paths release];
	return reverse;
}

@end


@implementation NSArray (BXPaths)

- (NSArray *) pathsFilteredToDepth: (NSUInteger)maxRelativeDepth
{
	//IMPLEMENTATION NOTE: this could be optimised in several ways, e.g. by discarding as we sort,
	//then filtering the remainder; or by sorting first, determining the max depth, then jumping
	//to the middle of the array and working our way back/forward till we meet the cutoff point.
	
	NSArray *sortedPaths = [self sortedArrayUsingSelector: @selector(pathDepthCompare:)];
	NSMutableArray *filteredPaths = [NSMutableArray arrayWithCapacity: [sortedPaths count]];
	
	NSInteger maxDepth = -1;
	for (NSString *path in sortedPaths)
	{
		NSInteger pathDepth = [[path pathComponents] count];
		if (maxDepth == -1) maxDepth = pathDepth + maxRelativeDepth;
		
		if (pathDepth <= maxDepth) [filteredPaths addObject: path];
		//Stop looking once we get beyond the maximum depth
		else break;
	}
	return filteredPaths;
}

@end