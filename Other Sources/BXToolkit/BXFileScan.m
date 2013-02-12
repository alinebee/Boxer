/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
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
@synthesize basePath = _basePath;
@synthesize matchingPaths = _matchingPaths;
@synthesize maxMatches = _maxMatches;
@synthesize fileTypes = _fileTypes;
@synthesize predicate = _predicate;
@synthesize skipSubdirectories = _skipSubdirectories;
@synthesize skipPackageContents = _skipPackageContents;
@synthesize skipHiddenFiles = _skipHiddenFiles;

#pragma mark -
#pragma mark Initialization and deallocation

+ (id) scanWithBasePath: (NSString *)path
{
    BXFileScan *scan = [[self alloc] init];
    scan.basePath = path;
    
    return [scan autorelease];
}

- (id) init
{
    if ((self = [super init]))
    {
        _matchingPaths = [[NSMutableArray alloc] initWithCapacity: 10];
        
		_workspace = [[NSWorkspace alloc] init];
		_manager	= [[NSFileManager alloc] init];
        
		//Skip hidden files by default
		self.skipHiddenFiles = YES;
        self.maxMatches = 0;
    }
    
    return self;
}

- (void) dealloc
{
    self.fileTypes = nil;
    self.basePath = nil;
    self.predicate = nil;
    
    [_matchingPaths release], _matchingPaths = nil;
	[_manager release], _manager = nil;
	[_workspace release], _workspace = nil;
    
    [super dealloc];
}


#pragma mark -
#pragma mark Performing the scan

- (NSString *) lastMatch
{
    return [_matchingPaths lastObject];
}

- (NSString *) fullPathFromRelativePath: (NSString *)relativePath
{
    return [self.basePath stringByAppendingPathComponent: relativePath];
}

- (BOOL) matchAgainstPath: (NSString *)relativePath
{
    if ([self isMatchingPath: relativePath])
    {
        [self addMatchingPath: relativePath];
        
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject: self.lastMatch
                                                             forKey: BXFileScanLastMatchKey];
        
        [self _sendInProgressNotificationWithInfo: userInfo];
        
        //Check if we have enough matches now: if so, stop scanning.
        if (self.maxMatches && _matchingPaths.count >= self.maxMatches) return NO;
    }
    
    return YES;
}

- (BOOL) isMatchingPath: (NSString *)relativePath
{
    if (self.skipHiddenFiles && [relativePath.lastPathComponent hasPrefix: @"."]) return NO;
    
    if (self.predicate && ![self.predicate evaluateWithObject: relativePath]) return NO;
    
    if (self.fileTypes)
    {
        NSString *fullPath = [self fullPathFromRelativePath: relativePath];
        if (![_workspace file: fullPath matchesTypes: self.fileTypes]) return NO;
    }
    
    return YES;
}

- (BOOL) shouldScanSubpath: (NSString *)relativePath
{
    if (self.skipSubdirectories) return NO;
    
    if (self.skipPackageContents)
    {
        NSString *fullPath = [self fullPathFromRelativePath: relativePath];
        if ([_workspace isFilePackageAtPath: fullPath]) return NO;
    }
    
    return YES;
}

- (void) addMatchingPath: (NSString *)relativePath
{
    //Ensures KVO notifications are sent properly
	[[self mutableArrayValueForKey: @"matchingPaths"] addObject: relativePath];
}

- (BOOL) shouldPerformOperation
{
    //If no base path has been set, we cannot begin
    return [super shouldPerformOperation] && (self.basePath != nil);
}

- (id <BXFilesystemEnumeration>) enumerator
{
    return (id <BXFilesystemEnumeration>)[_manager enumeratorAtPath: self.basePath];
}

- (void) performOperation
{
    //In case we were cancelled upstairs in willStart
    //Empty the matches before we begin
    [_matchingPaths removeAllObjects];
    
    id <BXFilesystemEnumeration> enumerator = self.enumerator;
    
    for (NSString *relativePath in enumerator)
    {
        if (self.isCancelled) break;
        
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
        NSString *fileType = enumerator.fileAttributes.fileType;
        if ([fileType isEqualToString: NSFileTypeDirectory])
        {
            if (![self shouldScanSubpath: relativePath])
                [enumerator skipDescendents];
        }
        
        BOOL keepScanning = [self matchAgainstPath: relativePath];
        
        [pool drain];
        
        if (self.isCancelled || !keepScanning) break;
    }
}

@end
