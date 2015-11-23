/*
 *  Copyright (c) 2013, Alun Bestor (alun.bestor@gmail.com)
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *		Redistributions of source code must retain the above copyright notice, this
 *	    list of conditions and the following disclaimer.
 *
 *		Redistributions in binary form must reproduce the above copyright notice,
 *	    this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 *	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 */

#import "NSString+ADBPaths.h"

@implementation NSString (ADBPaths)

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
	return reverse;
}

@end


@implementation NSArray (ADBPaths)

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