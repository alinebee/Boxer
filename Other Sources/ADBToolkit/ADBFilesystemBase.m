//
//  ADBFilesystemBase.m
//  Boxer
//
//  Created by Alun Bestor on 01/04/2013.
//  Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
//

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
            return [URL pathRelativeToURL: representedURL];
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
