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
@synthesize manager = _manager;

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
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    self.mutableRepresentedURLs = nil;
    self.baseURL = nil;
    self.manager = nil;
    
    [super dealloc];
#pragma clang diagnostic pop
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
    
    [super setBaseURL: URL];
}



#pragma mark - ADBFilesystemFileURLAccess implementation

- (NSString *) pathForFileURL: (NSURL *)URL
{
    NSString *relativePath = nil;
    if ([self exposesFileURL: URL])
    {
        relativePath = [URL pathRelativeToURL: self.baseURL];
        return [@"/" stringByAppendingPathComponent: relativePath];
    }
    else
    {
        return nil;
    }
}

- (BOOL) exposesFileURL: (NSURL *)URL
{
    return [URL isBasedInURL: self.baseURL];
}

- (NSURL *) fileURLForPath: (NSString *)path
{
    //Ensure that paths such as "../path/outside/filesystem/" won't work
    path = path.stringByStandardizingPath;
    return [self.baseURL URLByAppendingPathComponent: path].URLByStandardizingPath;
}

- (ADBLocalDirectoryEnumerator *) enumeratorAtFileURL: (NSURL *)URL
                                includingPropertiesForKeys: (NSArray *)keys
                                                   options: (NSDirectoryEnumerationOptions)mask
                                              errorHandler: (ADBFilesystemFileURLErrorHandler)errorHandler
{
    //Refuse to enumerate URLs that aren't located within this filesystem.
    if ([self exposesFileURL: URL])
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
    NSURL *localURL = [self fileURLForPath: path];
    return [self.manager fileExistsAtPath: localURL.path isDirectory: isDirectory];
}

- (NSString *) typeOfFileAtPath: (NSString *)path
{
    NSURL *localURL = [self fileURLForPath: path];
    return localURL.typeIdentifier;
}

- (BOOL) fileAtPath: (NSString *)path conformsToType: (NSString *)UTI
{
    NSURL *localURL = [self fileURLForPath: path];
    return [localURL conformsToFileType: UTI];
}

- (NSString *) typeOfFileAtPath: (NSString *)path matchingTypes: (NSSet *)UTIs
{
    NSURL *localURL = [self fileURLForPath: path];
    return [localURL matchingFileType: UTIs];
}

- (NSDictionary *) attributesOfFileAtPath: (NSString *)path error: (out NSError **)outError
{
    NSURL *localURL = [self fileURLForPath: path];
    return [[NSFileManager defaultManager] attributesOfItemAtPath: localURL.path
                                                            error: outError];
}

- (NSData *) contentsOfFileAtPath: (NSString *)path error: (out NSError **)outError
{
    NSURL *localURL = [self fileURLForPath: path];
    return [NSData dataWithContentsOfURL: localURL options: 0 error: outError];
}


- (BOOL) removeItemAtPath: (NSString *)path error: (out NSError **)outError
{
    NSURL *localURL = [self fileURLForPath: path];
    return [self.manager removeItemAtURL: localURL error: outError];
}

- (BOOL) _transferItemAtPath: (NSString *)fromPath
                      toPath: (NSString *)toPath
                     copying: (BOOL)copying
                       error: (out NSError **)outError
{
    NSURL *fromURL  = [self fileURLForPath: fromPath];
    NSURL *toURL    = [self fileURLForPath: toPath];
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
    NSURL *localURL = [self fileURLForPath: path];
    return [self.manager createDirectoryAtURL: localURL
                  withIntermediateDirectories: createIntermediates
                                   attributes: nil
                                        error: outError];
}

- (ADBFileHandle *) fileHandleAtPath: (NSString *)path
                             options: (ADBHandleOptions)options
                               error: (out NSError **)outError
{
    NSURL *localURL = [self fileURLForPath: path];
    return [ADBFileHandle handleForURL: localURL options: options error: outError];
}

- (FILE *) openFileAtPath: (NSString *)path
                   inMode: (const char *)accessMode
                    error: (out NSError **)outError
{
    NSURL *localURL = [self fileURLForPath: path];
    return [[ADBFileHandle handleForURL: localURL mode: accessMode error: outError] fileHandleAdoptingOwnership: YES];
}

- (id <ADBFilesystemPathEnumeration>) enumeratorAtPath: (NSString *)path
                                               options: (NSDirectoryEnumerationOptions)mask
                                          errorHandler: (ADBFilesystemPathErrorHandler)errorHandler
{
    NSURL *localURL = [self fileURLForPath: path];
    ADBFilesystemFileURLErrorHandler wrappedHandler;
    if (errorHandler)
    {
        wrappedHandler = ^BOOL(NSURL *url, NSError *error) {
            NSString *logicalPath = [self pathForFileURL: url];
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
      errorHandler: (ADBFilesystemFileURLErrorHandler)errorHandler
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
        return [self.filesystem pathForFileURL: self.currentURL];
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
