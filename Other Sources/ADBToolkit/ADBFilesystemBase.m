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

#import "ADBFilesystemBase.h"
#import "NSURL+ADBFilesystemHelpers.h"


@implementation ADBFilesystemBase
@synthesize mutableRepresentedURLs = _mutableRepresentedURLs;
@synthesize baseURL = _baseURL;

- (id) init
{
    self = [super init];
    if (self)
    {
        self.mutableRepresentedURLs = [NSMutableArray arrayWithCapacity: 1];
    }
    return self;
}

- (void) dealloc
{
    self.baseURL = nil;
    self.mutableRepresentedURLs = nil;
    
    [super dealloc];
}

//Include the base URL as one of our represented URLs.
- (void) setBaseURL: (NSURL *)URL
{
    if (![URL isEqual: self.baseURL])
    {
        if (_baseURL)
            [self removeRepresentedURL: _baseURL];
        
        [_baseURL release];
        _baseURL = [URL copy];
        
        if (_baseURL)
            [self addRepresentedURL: _baseURL];
    }
}


#pragma mark - ADBFilesystemLogicalURLAccess implementations

- (NSSet *) representedURLs
{
    return [NSSet setWithArray: self.mutableRepresentedURLs];
}

- (NSURL *) logicalURLForPath: (NSString *)path
{
    NSAssert(path != nil, @"No path provided!");
    
    //Ensure that paths such as "../path/outside/filesystem/" won't work
    path = path.stringByStandardizingPath;
    return [self.baseURL URLByAppendingPathComponent: path];
}

- (NSString *) pathForLogicalURL: (NSURL *)URL
{
    if (!URL)
        return nil;
    
    for (NSURL *representedURL in self.mutableRepresentedURLs)
    {
        if ([URL isBasedInURL: representedURL])
        {
            NSString *relativePath = [URL pathRelativeToURL: representedURL];
            return [@"/" stringByAppendingPathComponent: relativePath];
        }
    }
    
    return nil;
}

- (BOOL) exposesLogicalURL: (NSURL *)URL
{
    NSAssert(URL != nil, @"No URL provided!");
    
    for (NSURL *representedURL in self.mutableRepresentedURLs)
    {
        if ([URL isBasedInURL: representedURL])
            return YES;
    }
    
    return NO;
}

- (BOOL) representsLogicalURL: (NSURL *)URL
{
    NSAssert(URL != nil, @"No URL provided!");
    
    return [self.mutableRepresentedURLs containsObject: URL.URLByStandardizingPath];
}

- (void) addRepresentedURL: (NSURL *)URL
{
    NSAssert(URL != nil, @"No URL provided!");
    
    URL = URL.URLByStandardizingPath;
    NSString *path = URL.path;
    NSUInteger pathLength = path.length;
    
    //Store the URLs in descending order of length. This is so that we can correctly
    //handle nested URLs for URL->path lookups: if a logical URL has more than one
    //represented URL as its base, we will resolve it to the 'deeper' of the two URLs.
    NSUInteger i, numURLs = self.mutableRepresentedURLs.count;
    for (i=0; i<numURLs; i++)
    {
        NSURL *existingURL = [self.mutableRepresentedURLs objectAtIndex: i];
        NSString *existingPath = existingURL.path;
        
        //If this URL is shorter, insert the new URL in front of it.
        if (existingPath.length < pathLength)
        {
            [self.mutableRepresentedURLs insertObject: URL atIndex: i];
            return;
        }
        
        //If the URL was already present in our array, bail out without adding another copy.
        else if ([existingPath isEqualToString: path])
        {
            return;
        }
    }
    
    //If we got this far, we couldn't find a suitable place to insert the URL:
    //just tack it on the end instead.
    [self.mutableRepresentedURLs addObject: URL];
}

- (void) removeRepresentedURL: (NSURL *)URL
{
    NSAssert(URL != nil, @"No URL provided!");
    [self.mutableRepresentedURLs removeObject: URL.URLByStandardizingPath];
}

@end
