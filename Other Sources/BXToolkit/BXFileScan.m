/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXFileScan.h"
#import "BXPathEnumerator.h"
#import "NSWorkspace+BXFileTypes.h"


#pragma mark -
#pragma mark Constants

NSString * const BXFileScanLastMatchKey = @"BXFileScanLastMatch";


#pragma mark -
#pragma mark Implementation


@implementation BXFileScan
@synthesize basePath, matchingPaths, maxMatches;
@synthesize fileTypes, predicate;
@synthesize skipSubdirectories, skipPackageContents, skipHiddenFiles;

#pragma mark -
#pragma mark Initialization and deallocation

+ (id) scanWithBasePath: (NSString *)path
{
    BXFileScan *scan = [[self alloc] init];
    [scan setBasePath: path];
    
    return [scan autorelease];
}

- (id) init
{
    if ((self = [super init]))
    {
        matchingPaths = [[NSMutableArray alloc] initWithCapacity: 10];
        maxMatches = 0;
        
		workspace = [[NSWorkspace alloc] init];
		manager	= [[NSFileManager alloc] init];
        
		//Skip hidden files by default
		[self setSkipHiddenFiles: YES];
    }
    
    return self;
}

- (void) dealloc
{
    [matchingPaths release], matchingPaths = nil;
    
	[self setFileTypes: nil],       [fileTypes release];
	[self setBasePath: nil],        [basePath release];
    [self setPredicate: nil],       [predicate release];
    
	[manager release], manager = nil;
	[workspace release], workspace = nil;
    
    [super dealloc];
}


#pragma mark -
#pragma mark Performing the scan

- (NSString *) lastMatch
{
    return [matchingPaths lastObject];
}

- (BOOL) isMatchingPath: (NSString *)relativePath
{
    if ([self skipHiddenFiles] && [[relativePath lastPathComponent] hasPrefix: @"."]) return NO;
    
    if ([self predicate] && ![[self predicate] evaluateWithObject: relativePath]) return NO;
    
    if ([self fileTypes])
    {
        NSString *fullPath = [[self basePath] stringByAppendingPathComponent: relativePath];
        if (![workspace file: fullPath matchesTypes: [self fileTypes]]) return NO;
    }
    
    return YES;
}

- (BOOL) shouldScanSubpath: (NSString *)relativePath
{
    if ([self skipSubdirectories]) return NO;
    
    if ([self skipPackageContents])
    {
        NSString *fullPath = [[self basePath] stringByAppendingPathComponent: relativePath];
        if ([workspace isFilePackageAtPath: fullPath]) return NO;
    }
    
    return YES;
}

- (void) addMatchingPath: (NSString *)relativePath
{
    NSString *fullPath = [[self basePath] stringByAppendingPathComponent: relativePath];
    
    //Ensures KVO notifications are sent properly
	[[self mutableArrayValueForKey: @"matchingPaths"] addObject: fullPath];
}

- (BOOL) canStart
{
    //If no base path has been set, we cannot begin
    return ([self basePath] != nil);
}

- (void) main
{
    //Empty the matches before we begin
    [matchingPaths removeAllObjects];    
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSDirectoryEnumerator *enumerator = [manager enumeratorAtPath: [self basePath]];
    
    for (NSString *relativePath in enumerator)
    {
        if ([self isCancelled]) break;
        
        NSString *fileType = [[enumerator fileAttributes] fileType];
        if ([fileType isEqualToString: NSFileTypeDirectory])
        {
            if (![self shouldScanSubpath: relativePath])
                [enumerator skipDescendents];
        }
            
        if ([self isMatchingPath: relativePath])
        {
            [self addMatchingPath: relativePath];
            
            NSDictionary *userInfo = [NSDictionary dictionaryWithObject: [self lastMatch]
                                                                 forKey: BXFileScanLastMatchKey];
            
            [self _sendInProgressNotificationWithInfo: userInfo];
        }
        
        if ([self isCancelled] || ([self maxMatches] && [matchingPaths count] >= [self maxMatches])) break;
    }
    
    [pool drain];
    
    [self setSucceeded: ![self error]];
}

@end
