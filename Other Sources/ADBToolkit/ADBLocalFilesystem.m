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

#import "ADBLocalFilesystemPrivate.h"
#import "NSURL+ADBFilesystemHelpers.h"

@implementation ADBLocalFilesystem
@synthesize baseURL = _baseURL;
@synthesize manager = _manager;
@synthesize mutableRepresentedURLs = _mutableRepresentedURLs;

+ (id) filesystemWithBaseURL: (NSURL *)baseURL
{
    return [[[self alloc] initWithBaseURL: baseURL] autorelease];
}

- (id) initWithBaseURL: (NSURL *)baseURL
{
    self = [self init];
    if (self)
    {
        self.baseURL = baseURL;
    }
    return self;
}

- (id) init
{
    self = [super init];
    if (self)
    {
        self.manager = [[[NSFileManager alloc] init] autorelease];
        self.manager.delegate = self;
        
        self.mutableRepresentedURLs = [NSMutableArray arrayWithCapacity: 1];
    }
    return self;
}

- (void) dealloc
{
    self.mutableRepresentedURLs = nil;
    self.baseURL = nil;
    self.manager = nil;
    
    [super dealloc];
}

- (void) setBaseURL: (NSURL *)URL
{
    if (URL != nil)
    {
        //Derive a canonical version of the URL, ensuring it is fully-resolved
        //and marked as a directory.
        URL = [NSURL fileURLWithPath: URL.path.stringByResolvingSymlinksInPath
                         isDirectory: YES];
    }
    
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



#pragma mark - ADBFilesystemLocalFileURLAccess implementation

- (NSString *) logicalPathForLocalFileURL: (NSURL *)URL
{
    NSString *relativePath = nil;
    if ([self exposesLocalFileURL: URL])
    {
        relativePath = [URL pathRelativeToURL: self.baseURL];
        return [@"/" stringByAppendingPathComponent: relativePath];
    }
    else
    {
        return nil;
    }
}

- (BOOL) exposesLocalFileURL: (NSURL *)URL
{
    return [URL isBasedInURL: self.baseURL];
}

- (NSURL *) localFileURLForLogicalPath: (NSString *)path
{
    //Ensure that paths such as "../path/outside/filesystem/" won't work
    path = path.stringByStandardizingPath;
    return [self.baseURL URLByAppendingPathComponent: path];
}

- (ADBLocalDirectoryEnumerator *) enumeratorAtLocalFileURL: (NSURL *)URL
                                includingPropertiesForKeys: (NSArray *)keys
                                                   options: (NSDirectoryEnumerationOptions)mask
                                              errorHandler: (ADBFilesystemLocalFileURLErrorHandler)errorHandler
{
    //Refuse to enumerate URLs that aren't located within this filesystem.
    if ([self exposesLocalFileURL: URL])
    {
        return [[[ADBLocalDirectoryEnumerator alloc] initWithURL: URL
                                                     inFilesytem: self
                                      includingPropertiesForKeys: keys
                                                         options: mask
                                                      returnURLs: YES
                                                    errorHandler: errorHandler] autorelease];
    }
    else
    {
        if (errorHandler)
        {
            NSError *error = [NSError errorWithDomain: NSCocoaErrorDomain
                                                 code: NSFileReadNoSuchFileError
                                             userInfo: @{ NSURLErrorKey: URL }];
            
            errorHandler(URL, error);
        }
        return nil;
    }
}

#pragma mark - ADBFilesystemPathAccess implementation

- (BOOL) fileExistsAtPath: (NSString *)path isDirectory: (BOOL *)isDirectory
{
    NSURL *localURL = [self localFileURLForLogicalPath: path];
    return [self.manager fileExistsAtPath: localURL.path isDirectory: isDirectory];
}

- (NSString *) typeOfFileAtPath: (NSString *)path
{
    NSURL *localURL = [self localFileURLForLogicalPath: path];
    return localURL.typeIdentifier;
}

- (BOOL) fileAtPath: (NSString *)path conformsToType: (NSString *)UTI
{
    NSURL *localURL = [self localFileURLForLogicalPath: path];
    return [localURL conformsToFileType: UTI];
}

- (NSString *) typeOfFileAtPath: (NSString *)path matchingTypes: (NSSet *)UTIs
{
    NSURL *localURL = [self localFileURLForLogicalPath: path];
    return [localURL matchingFileType: UTIs];
}

- (NSDictionary *) attributesOfFileAtPath: (NSString *)path error: (out NSError **)outError
{
    NSURL *localURL = [self localFileURLForLogicalPath: path];
    return [[NSFileManager defaultManager] attributesOfItemAtPath: localURL.path
                                                            error: outError];
}

- (NSData *) contentsOfFileAtPath: (NSString *)path error: (out NSError **)outError
{
    NSURL *localURL = [self localFileURLForLogicalPath: path];
    return [NSData dataWithContentsOfURL: localURL options: 0 error: outError];
}


- (BOOL) removeItemAtPath: (NSString *)path error: (out NSError **)outError
{
    NSURL *localURL = [self localFileURLForLogicalPath: path];
    return [self.manager removeItemAtURL: localURL error: outError];
}

- (BOOL) _transferItemAtPath: (NSString *)fromPath
                      toPath: (NSString *)toPath
                     copying: (BOOL)copying
                       error: (out NSError **)outError
{
    NSURL *fromURL  = [self localFileURLForLogicalPath: fromPath];
    NSURL *toURL    = [self localFileURLForLogicalPath: toPath];
    if (copying)
        return [self.manager copyItemAtURL: fromURL toURL: toURL error: outError];
    else
        return [self.manager moveItemAtURL: fromURL toURL: toURL error: outError];
}

- (BOOL) copyItemAtPath: (NSString *)fromPath toPath: (NSString *)toPath error: (out NSError **)outError
{
    return [self _transferItemAtPath: fromPath toPath: toPath copying: YES error: outError];
}

- (BOOL) moveItemAtPath: (NSString *)fromPath toPath: (NSString *)toPath error: (out NSError **)outError
{
    return [self _transferItemAtPath: fromPath toPath: toPath copying: NO error: outError];
}

- (BOOL) createDirectoryAtPath: (NSString *)path
   withIntermediateDirectories: (BOOL)createIntermediates
                         error: (out NSError **)outError
{
    NSURL *localURL = [self localFileURLForLogicalPath: path];
    return [self.manager createDirectoryAtURL: localURL
                  withIntermediateDirectories: createIntermediates
                                   attributes: nil
                                        error: outError];
}

- (ADBFileHandle *) fileHandleAtPath: (NSString *)path
                             options: (ADBHandleOptions)options
                               error: (out NSError **)outError
{
    NSURL *localURL = [self localFileURLForLogicalPath: path];
    return [ADBFileHandle handleForURL: localURL options: options error: outError];
}

- (FILE *) openFileAtPath: (NSString *)path
                   inMode: (const char *)accessMode
                    error: (out NSError **)outError
{
    NSURL *localURL = [self localFileURLForLogicalPath: path];
    return [[ADBFileHandle handleForURL: localURL mode: accessMode error: outError] fileHandleAdoptingOwnership: YES];
}

- (id <ADBFilesystemPathEnumeration>) enumeratorAtPath: (NSString *)path
                                               options: (NSDirectoryEnumerationOptions)mask
                                          errorHandler: (ADBFilesystemPathErrorHandler)errorHandler
{
    NSURL *localURL = [self localFileURLForLogicalPath: path];
    ADBFilesystemLocalFileURLErrorHandler wrappedHandler;
    if (errorHandler)
    {
        wrappedHandler = ^BOOL(NSURL *url, NSError *error) {
            NSString *logicalPath = [self logicalPathForLocalFileURL: url];
            return errorHandler(logicalPath, error);
        };
    }
    else
    {
        wrappedHandler = nil;
    }
    
    return [[[ADBLocalDirectoryEnumerator alloc] initWithURL: localURL
                                                 inFilesytem: self
                                  includingPropertiesForKeys: nil
                                                     options: mask
                                                  returnURLs: NO
                                                errorHandler: wrappedHandler] autorelease];
}


#pragma mark - ADBFileysstemLogicalURLAccess implementations

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




@implementation ADBLocalDirectoryEnumerator
@synthesize enumerator = _enumerator;
@synthesize filesystem = _filesystem;
@synthesize currentURL = _currentURL;

- (id) initWithURL: (NSURL *)URL
       inFilesytem: (ADBLocalFilesystem *)filesystem
includingPropertiesForKeys: (NSArray *)keys
           options: (NSDirectoryEnumerationOptions)mask
        returnURLs: (BOOL)returnURLs
      errorHandler: (ADBFilesystemLocalFileURLErrorHandler)errorHandler
{
    self = [self init];
    if (self)
    {
        _returnsFileURLs = returnURLs;
        self.filesystem = filesystem;
        self.enumerator = [self.filesystem.manager enumeratorAtURL: URL
                                        includingPropertiesForKeys: keys
                                                           options: mask
                                                      errorHandler: errorHandler];
    }
    return self;
}

- (void) dealloc
{
    self.enumerator = nil;
    self.filesystem = nil;
    self.currentURL = nil;
    
    [super dealloc];
}

- (id) nextObject
{
    self.currentURL = self.enumerator.nextObject;
    
    if (self.currentURL == nil)
        return nil;
    else if (_returnsFileURLs)
        return self.currentURL;
    else
        return [self.filesystem logicalPathForLocalFileURL: self.currentURL];
}

- (void) skipDescendants
{
    [self.enumerator skipDescendants];
}

- (NSUInteger) level
{
    return self.enumerator.level;
}

- (NSDictionary *) fileAttributes
{
    return [[NSFileManager defaultManager] attributesOfItemAtPath: self.currentURL.path error: NULL];
}

@end