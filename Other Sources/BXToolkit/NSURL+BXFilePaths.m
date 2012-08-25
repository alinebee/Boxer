/*
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "NSURL+BXFilePaths.h"

@implementation NSURL (BXPaths)

- (NSString *) pathRelativeToURL: (NSURL *)baseURL
{
	//First, standardize both paths.
	baseURL                     = baseURL.URLByStandardizingPath;
	NSURL *originalURL          = self.URLByStandardizingPath;
    
    //Optimisation: if the original URL is already inside the base URL,
    //we can get the relative URL just by snipping off the front of the string.
    if ([originalURL isBasedInURL: baseURL])
    {
        NSUInteger prefixLength = baseURL.path.length;
        NSString *relativePath = [originalURL.path substringFromIndex: prefixLength];
        
        //Check if there's a stray slash on the front and remove that also.
        if ([relativePath hasPrefix: @"/"])
            relativePath = [relativePath substringFromIndex: 1];
        return relativePath;
    }
    //Otherwise, we need to go more in-depth and look at individual path components.
    else
    {
        NSArray *components         = originalURL.pathComponents;
        NSArray *baseComponents     = baseURL.pathComponents;
        NSUInteger numInOriginal	= components.count;
        NSUInteger numInBase        = baseComponents.count;
        NSUInteger from, upTo = MIN(numInBase, numInOriginal);
        
        //Skip over any common prefixes
        for (from=0; from < upTo; from++)
        {
            if (![[components objectAtIndex: from] isEqualToString: [baseComponents objectAtIndex: from]]) break;
        }
        
        NSUInteger i, stepsBack = (numInBase - from);
        NSMutableArray *relativeComponents = [NSMutableArray arrayWithCapacity: stepsBack + numInOriginal - from];
        //First, add the steps to get back to the first common directory
        for (i=0; i<stepsBack; i++) [relativeComponents addObject: @".."];
        //Then, add the steps from there to the original path
        [relativeComponents addObjectsFromArray: [components subarrayWithRange: NSMakeRange(from, numInOriginal - from)]];
        
        return [NSString pathWithComponents: relativeComponents];
    }
}

- (NSURL *) URLRelativeToURL: (NSURL *)baseURL
{
    NSString *relativePath = [self pathRelativeToURL: baseURL];
    return [NSURL URLWithString: relativePath relativeToURL: baseURL];
}

- (const char *) fileSystemRepresentation
{
    return self.path.fileSystemRepresentation;
}

+ (NSURL *) URLFromFileSystemRepresentation: (const char *)representation
{
    NSFileManager *manager = [[NSFileManager alloc] init];
    NSString *path = [manager stringWithFileSystemRepresentation: representation
                                                          length: strlen(representation)];
    
    
    return [NSURL fileURLWithPath: path];
}

- (BOOL) isBasedInURL: (NSURL *)baseURL
{
    NSString *basePath = baseURL.path;
    NSString *originalPath = self.path;
    
    //If the two paths are identical, then great! We have a winner.
    if ([originalPath isEqualToString: basePath])
        return YES;
    
    //Otherwise, ensure the base URL has a slash and then check for a common prefix.
    if (![basePath hasSuffix: @"/"])
        basePath = [basePath stringByAppendingString: @"/"];
    
    return [originalPath hasPrefix: basePath];
}

- (NSArray *) componentURLs
{	
	//Build an array of complete paths for each component of this URL
	NSMutableArray *components = [[NSMutableArray alloc] initWithCapacity: 10];
    
    NSURL *currentURL = self, *parentURL = nil;
	while (YES)
	{
        //NOTE: we insert each component in reverse order
        [components insertObject: currentURL atIndex: 0];
		parentURL = currentURL.URLByDeletingLastPathComponent;
        //We've reached the root once URLByDeletingLastPathComponent
        //returns an identical URL
        if ([parentURL isEqual: currentURL])
            break;
	}
	
    return components;
}

@end
