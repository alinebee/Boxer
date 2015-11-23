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

#import "ADBFileScan.h"
#import "ADBPathEnumerator.h"
#import "NSWorkspace+ADBFileTypes.h"


#pragma mark -
#pragma mark Constants

NSString * const ADBFileScanLastMatchKey = @"ADBFileScanLastMatch";


#pragma mark -
#pragma mark Implementation


@implementation ADBFileScan
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
    ADBFileScan *scan = [[self alloc] init];
    scan.basePath = path;
    
    return scan;
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
                                                             forKey: ADBFileScanLastMatchKey];
        
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

- (NSDirectoryEnumerator *) enumerator
{
    return [_manager enumeratorAtPath: self.basePath];
}

- (void) main
{
    NSAssert(self.basePath != nil, @"No base path provided for file scan operation.");
    if (self.basePath == nil)
        return;
    
    [_matchingPaths removeAllObjects];
    
    NSDirectoryEnumerator *enumerator = self.enumerator;
    
    for (NSString *relativePath in enumerator)
    {
        BOOL keepScanning;
        if (self.isCancelled) break;
        
        @autoreleasepool {
        
        NSString *fileType = enumerator.fileAttributes.fileType;
        if ([fileType isEqualToString: NSFileTypeDirectory])
        {
            if (![self shouldScanSubpath: relativePath])
                [enumerator skipDescendants];
        }
        
        keepScanning = [self matchAgainstPath: relativePath];
        
        }
        
        if (self.isCancelled || !keepScanning) break;
    }
}

@end
