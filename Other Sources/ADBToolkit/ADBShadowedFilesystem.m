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

#import "ADBShadowedFilesystem.h"
#import "NSURL+ADBFilesystemHelpers.h"
#import "NSError+ADBErrorHelpers.h"
#import "ADBForwardCompatibility.h"

#pragma mark -
#pragma mark Private constants

NSString * const ADBShadowedDeletionMarkerExtension = @"deleted";


enum {
    ADBFileOpenForReading   = 1 << 0,
    ADBFileOpenForWriting   = 1 << 1,
    ADBFileCreateIfMissing  = 1 << 2,
    ADBFileTruncate         = 1 << 3,
    ADBFileAppend           = 1 << 4
};

typedef NSUInteger ADBFileOpenOptions;


#pragma mark -
#pragma mark Private method declarations

@interface ADBShadowedFilesystem ()

//Our own file manager for internal use.
@property (retain, nonatomic) NSFileManager *manager;

//Parses an fopen()-format mode string into a set of bitflags.
+ (ADBFileOpenOptions) _optionsFromAccessMode: (const char *)accessMode;

//Internal implementation for moveItemAtURL:toURL:error: and copyItemAtURL:toURL:error:.
- (BOOL) _transferItemAtPath: (NSString *)fromPath
                      toPath: (NSString *)toPath
                     copying: (BOOL)copy
                       error: (NSError **)outError;

//Create a 0-byte deletion marker at the specified shadow URL.
- (void) _createDeletionMarkerAtURL: (NSURL *)markerURL;

//Returns a file pointer for the specified absolute filesystem URL.
//No original->shadow mapping is performed on the specified URL.
- (FILE *) _openFileAtCanonicalFilesystemURL: (NSURL *)URL
                                      inMode: (const char *)accessMode
                                       error: (NSError **)outError;

//Used internally by mergeContentsOfURL:error: to merge each item back into the source.
- (BOOL) _mergeItemAtShadowURL: (NSURL *)shadowedURL
                   toSourceURL: (NSURL *)sourceURL
                         error: (NSError **)outError;
@end


//A directory enumerator returned by ADBShadowedFilesystem's enumeratorAtURL: and enumeratorAtPath: methods.
//Analoguous to NSDirectoryEnumerator, except that it folds together the original and shadowed
//filesystems into a single filesystem. Any files and directories marked as deleted will be skipped.
//Note that this will return shadowed files first followed by untouched original files, rather
//than the straight depth-first traversal performed by NSDirectoryEnumerator.
@interface ADBShadowedDirectoryEnumerator : NSEnumerator <ADBFilesystemPathEnumeration, ADBFilesystemLocalFileURLEnumeration>
{
    BOOL _returnsFileURLs;
    NSDirectoryEnumerator *_localEnumerator;
    NSDirectoryEnumerator *_shadowEnumerator;
    __unsafe_unretained NSDirectoryEnumerator *_currentEnumerator;
    
    NSURL *_currentURL;
    
    NSMutableSet *_shadowedPaths;
    NSMutableSet *_deletedPaths;
    
    ADBShadowedFilesystem *_filesystem;
}

- (id) initWithLocalURL: (NSURL *)localURL
            shadowedURL: (NSURL *)shadowedURL
            inFilesytem: (ADBShadowedFilesystem *)filesystem
includingPropertiesForKeys: (NSArray *)keys
                options: (NSDirectoryEnumerationOptions)mask
             returnURLs: (BOOL)returnURLs
           errorHandler: (ADBFilesystemLocalFileURLErrorHandler)errorHandler;

@end


#pragma mark -
#pragma mark Implementation

@implementation ADBShadowedFilesystem

@synthesize sourceURL = _sourceURL;
@synthesize shadowURL = _shadowURL;
@synthesize manager = _manager;


#pragma mark - Initialization and deallocation

+ (id) filesystemWithSourceURL: (NSURL *)sourceURL shadowURL: (NSURL *)shadowURL
{
    return [[[self alloc] initWithSourceURL: sourceURL shadowURL: shadowURL] autorelease];
}

- (id) initWithSourceURL: (NSURL *)sourceURL shadowURL: (NSURL *)shadowURL
{
    self = [self init];
    if (self)
    {
        self.sourceURL = sourceURL;
        self.shadowURL = shadowURL;
        self.manager = [[[NSFileManager alloc] init] autorelease];
    }
    return self;
}

- (void) dealloc
{
    self.sourceURL = nil;
    self.shadowURL = nil;
    self.manager = nil;
    
    [super dealloc];
}

- (void) setSourceURL: (NSURL *)URL
{
    if (URL != nil)
    {
        //Derive a canonical version of the URL, ensuring it is fully-resolved
        //and marked as a directory.
        URL = [NSURL fileURLWithPath: URL.path.stringByResolvingSymlinksInPath
                         isDirectory: YES];
    }
    
    if (![URL isEqual: self.sourceURL])
    {
        [_sourceURL release];
        _sourceURL = [URL copy];
    }
}

- (void) setShadowURL: (NSURL *)URL
{
    if (URL != nil)
    {
        //Derive a canonical version of the URL, ensuring it is fully-resolved
        //and marked as a directory.
        URL = [NSURL fileURLWithPath: URL.path.stringByResolvingSymlinksInPath
                         isDirectory: YES];
    }
    
    if (![URL isEqual: self.shadowURL])
    {
        [_shadowURL release];
        _shadowURL = [URL copy];
    }
}

#pragma mark - Path translation

- (NSString *) logicalPathForLocalFileURL: (NSURL *)URL
{
    if ([URL isBasedInURL: self.sourceURL])
        return [URL pathRelativeToURL: self.sourceURL];
    else if ([URL isBasedInURL: self.shadowURL])
        return [URL pathRelativeToURL: self.shadowURL];
    
    return nil;
}

- (NSURL *) localFileURLForLogicalPath: (NSString *)path
{    
    NSURL *shadowURL = [self.shadowURL URLByAppendingPathComponent: path];
    NSURL *deletionMarkerURL = [shadowURL URLByAppendingPathExtension: ADBShadowedDeletionMarkerExtension];
    
    //File has been marked as deleted and thus cannot be accessed.
    if ([deletionMarkerURL checkResourceIsReachableAndReturnError: NULL])
        return nil;
    
    //File has been shadowed, return the shadow URL.
    if ([shadowURL checkResourceIsReachableAndReturnError: NULL])
        return shadowURL;
    
    //Otherwise, return the original source URL, unless it doesn't exist
    NSURL *sourceURL = [self.sourceURL URLByAppendingPathComponent: path];
    if ([sourceURL checkResourceIsReachableAndReturnError: NULL])
        return sourceURL;
    else
        return nil;
}

- (const char *) localFilesystemRepresentationForLogicalPath: (NSString *)path
{
    NSURL *canonicalURL = [self localFileURLForLogicalPath: path];
    return canonicalURL.fileSystemRepresentation;
}

- (NSString *) logicalPathForLocalFilesystemRepresentation: (const char *)representation
{
    NSURL *URL = [NSURL URLFromFileSystemRepresentation: representation];
    return [self logicalPathForLocalFileURL: URL];
}

- (NSURL *) _shadowedURLForLogicalPath: (NSString *)path
{
    return [self.shadowURL URLByAppendingPathComponent: path];
}

- (NSURL *) _sourceURLForLogicalPath: (NSString *)path
{
    return [self.sourceURL URLByAppendingPathComponent: path];
}

- (NSURL *) _shadowedURLForSourceURL: (NSURL *)URL
{
    //If we don't have a shadow, or the specified URL isn't located within
    //our source URL, there is no shadow URL that would be applicable.
    if (!self.shadowURL || ![URL isBasedInURL: self.sourceURL])
        return nil;
    
    NSString *relativePath = [URL pathRelativeToURL: self.sourceURL];
    
    return [self.shadowURL URLByAppendingPathComponent: relativePath];
}

- (NSURL *) _sourceURLForShadowedURL: (NSURL *)URL
{
    //If we don't have a shadow, or the specified URL isn't located within
    //our shadow URL, there is no source URL that would be applicable.
    if (!self.shadowURL || ![URL isBasedInURL: self.shadowURL])
        return nil;
    
    NSString *relativePath = [URL pathRelativeToURL: self.shadowURL];
    
    //If this is a deletion marker, map it back to the original file
    if ([relativePath.pathExtension isEqualToString: ADBShadowedDeletionMarkerExtension])
        relativePath = relativePath.stringByDeletingPathExtension;
    
    return [self.sourceURL URLByAppendingPathComponent: relativePath];
}


#pragma mark - ADBFilesystemPathAccess methods

- (NSDictionary *) attributesOfFileAtPath: (NSString *)path error: (out NSError **)outError
{
    NSURL *canonicalURL = [self localFileURLForLogicalPath: path];
    if (canonicalURL)
    {
        return [[NSFileManager defaultManager] attributesOfItemAtPath: canonicalURL.path error: outError];
    }
    else
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                            code: NSFileReadNoSuchFileError
                                        userInfo: @{ NSFilePathErrorKey: path }];
        }
        return nil;
    }
}

- (NSData *) contentsOfFileAtPath: (NSString *)path error: (out NSError **)outError
{
    NSURL *canonicalURL = [self localFileURLForLogicalPath: path];
    if (canonicalURL)
    {
        return [NSData dataWithContentsOfURL: canonicalURL options: 0 error: outError];
    }
    else
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                            code: NSFileReadNoSuchFileError
                                        userInfo: @{ NSFilePathErrorKey: path }];
        }
        return nil;
    }
}

- (id <ADBFilesystemPathEnumeration>) enumeratorAtPath: (NSString *)path
                                               options: (NSDirectoryEnumerationOptions)mask
                                          errorHandler: (ADBFilesystemPathErrorHandler)errorHandler
{
    NSURL *sourceURL = [self _sourceURLForLogicalPath: path];
    NSURL *shadowedURL = [self _shadowedURLForLogicalPath: path];
    
    
    ADBFilesystemLocalFileURLErrorHandler wrappedHandler;
    if (errorHandler)
        wrappedHandler = ^BOOL(NSURL *url, NSError *error) { return errorHandler(url.path, error); };
    else
        wrappedHandler = nil;
    
    return [[[ADBShadowedDirectoryEnumerator alloc] initWithLocalURL: sourceURL
                                                         shadowedURL: shadowedURL
                                                         inFilesytem: self
                                          includingPropertiesForKeys: nil
                                                             options: mask
                                                          returnURLs: NO
                                                        errorHandler: wrappedHandler] autorelease];
}

- (BOOL) moveItemAtPath: (NSString *)fromPath toPath: (NSString *)toPath error: (out NSError **)outError
{
    return [self _transferItemAtPath: fromPath toPath: toPath copying: NO error: outError];
}

- (BOOL) copyItemAtPath: (NSString *)fromPath toPath: (NSString *)toPath error: (out NSError **)outError
{
    return [self _transferItemAtPath: fromPath toPath: toPath copying: YES error: outError];
}

- (BOOL) fileExistsAtPath: (NSString *)path isDirectory: (BOOL *)isDirectory
{
    NSURL *originalURL = [self _sourceURLForLogicalPath: path];
    NSURL *shadowedURL = [self _shadowedURLForLogicalPath: path];
    
    if (shadowedURL)
    {
        NSURL *deletionMarkerURL = [shadowedURL URLByAppendingPathExtension: ADBShadowedDeletionMarkerExtension];
        
        //If the file is flagged as deleted, pretend it doesn't exist.
        if ([deletionMarkerURL checkResourceIsReachableAndReturnError: NULL])
        {
            if (isDirectory)
                *isDirectory = NO;
            return NO;
        }
        
        //Otherwise, if either the source or a shadow exist, treat the file as existing.
        if ([self.manager fileExistsAtPath: shadowedURL.path isDirectory: isDirectory])
        {
            return YES;
        }
        
        else
        {
            return [self.manager fileExistsAtPath: originalURL.path isDirectory: isDirectory];
        }
    }
    else
    {
        return [self.manager fileExistsAtPath: originalURL.path isDirectory: isDirectory];
    }
}

- (BOOL) createDirectoryAtPath: (NSString *)path
   withIntermediateDirectories: (BOOL)createIntermediates
                         error: (out NSError **)outError
{
    NSURL *originalURL = [self _sourceURLForLogicalPath: path];
    NSURL *shadowedURL = [self _shadowedURLForLogicalPath: path];
    
    if (shadowedURL)
    {
        NSURL *deletionMarkerURL = [shadowedURL URLByAppendingPathExtension: ADBShadowedDeletionMarkerExtension];
        
        //If the original already exists...
        if ([originalURL checkResourceIsReachableAndReturnError: NULL])
        {
            //If the original has been marked as deleted, then remove the marker
            //*but mark all the files inside that directory as deleted*,
            //since the 'new' directory should appear empty.
            if ([deletionMarkerURL checkResourceIsReachableAndReturnError: NULL])
            {
                [self.manager removeItemAtURL: deletionMarkerURL error: NULL];
                
                NSDirectoryEnumerator *enumerator = [self.manager enumeratorAtURL: originalURL
                                                       includingPropertiesForKeys: nil
                                                                          options: NSDirectoryEnumerationSkipsSubdirectoryDescendants
                                                                     errorHandler: nil];
                
                for (NSURL *subURL in enumerator)
                {
                    NSURL *shadowedSubURL = [self _shadowedURLForSourceURL: subURL];
                    NSURL *deletionMarkerSubURL = [shadowedSubURL URLByAppendingPathExtension: ADBShadowedDeletionMarkerExtension];
                    
                    [self _createDeletionMarkerAtURL: deletionMarkerSubURL];
                }
                return YES;
            }
            else
            {
                //To be consistent with the behaviour of NSFileManager, the attempt to create a new directory
                //at an existing location should fail if createIntermediates is NO.
                if (!createIntermediates)
                {
                    if (outError)
                    {
                        *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                                        code: NSFileWriteFileExistsError
                                                    userInfo: @{ NSURLErrorKey: originalURL }];
                    }
                    return NO;
                }
                return YES;
            }
        }
        //If the original doesn't exist, create a new shadow directory.
        //NOTE: 
        else
        {
            BOOL createdDirectory = [self.manager createDirectoryAtURL: shadowedURL
                                           withIntermediateDirectories: YES
                                                            attributes: nil
                                                                 error: NULL];
            
            if (createdDirectory)
            {
                //Remove any old deletion marker for this directory
                [self.manager removeItemAtURL: deletionMarkerURL error: NULL];
            }
            return createdDirectory;
        }
    }
    else
    {
        return [self.manager createDirectoryAtURL: originalURL
                      withIntermediateDirectories: createIntermediates
                                       attributes: nil
                                            error: NULL];
    }
}

- (FILE *) openFileAtPath: (NSString *)path
                   inMode: (const char *)accessMode
                    error: (out NSError **)outError
{
    NSURL *originalURL = [self _sourceURLForLogicalPath: path];
    NSURL *shadowedURL = [self _shadowedURLForLogicalPath: path];
    
    if (shadowedURL)
    {
        NSURL *deletionMarkerURL = [shadowedURL URLByAppendingPathExtension: ADBShadowedDeletionMarkerExtension];
        
        ADBFileOpenOptions accessOptions = [self.class _optionsFromAccessMode: accessMode];
        BOOL createIfMissing = (accessOptions & ADBFileCreateIfMissing) == ADBFileCreateIfMissing;
        
        BOOL deletionMarkerExists = [deletionMarkerURL checkResourceIsReachableAndReturnError: NULL];
        BOOL shadowExists = [shadowedURL checkResourceIsReachableAndReturnError: NULL];
        
        //If the file has been marked as deleted in the shadow...
        if (deletionMarkerExists)
        {
            //...but we are able to create a new file, then remove both the deletion marker
            //and any leftover shadow, and open a new file handle at the shadowed location.
            if (createIfMissing)
            {   
                //TODO: it should be a failure state if we cannot remove the deletion marker.
                [self.manager removeItemAtURL: deletionMarkerURL error: NULL];
                [self.manager removeItemAtURL: shadowedURL error: NULL];
                
                return [self _openFileAtCanonicalFilesystemURL: shadowedURL
                                                        inMode: accessMode
                                                         error: outError];
            }
            //Otherwise, pretend we can't open the file at all.
            else
            {
                if (outError)
                {
                    *outError = [NSError errorWithDomain: NSPOSIXErrorDomain
                                                    code: ENOENT //No such file or directory
                                                userInfo: @{ NSURLErrorKey: originalURL }];
                }
                return NULL;
            }
        }
        
        //If the shadow file already exists, open the shadow with whatever access mode was requested.
        //IMPLEMENTATION NOTE: conventional wisdom dictates we should just try to open it
        //and see if that worked without checking for file existence first, then use fallbacks
        //if it does fail; however this is undesirable in the case where we want to modify
        //the file's existing contents *or* create the file if it doesn't exist.
        else if (shadowExists)
        {
            return [self _openFileAtCanonicalFilesystemURL: shadowedURL
                                                    inMode: accessMode
                                                     error: outError];
        }
        
        //If we're opening the file for writing and we don't have a shadowed version of it,
        //copy any original version to the shadowed location first (creating any necessary
        //directories along the way) and then open the newly-shadowed copy.
        else if ((accessOptions & ADBFileOpenForWriting))
        {
            //Ensure the necessary path exists for the shadow file to be stored in.
            //IMPLEMENTATION NOTE: this ignores failure because the directories may already
            //exist. If there was another reason for failure then we'll fail later anyway
            //when trying to open the file handle.
            [self.manager createDirectoryAtURL: shadowedURL.URLByDeletingLastPathComponent
                   withIntermediateDirectories: YES
                                    attributes: nil
                                         error: NULL];
            
            //If we'll be truncating the file anyway, don't bother copying the original.
            BOOL truncateExistingFile = (accessOptions & ADBFileTruncate) == ADBFileTruncate;
            if (!truncateExistingFile)
            {
                NSError *copyError = nil;
                //Ensure we're copying the actual file and not a symlink.
                NSURL *resolvedURL = originalURL.URLByResolvingSymlinksInPath;
                BOOL copied = [self.manager copyItemAtURL: resolvedURL toURL: shadowedURL error: &copyError];
                
                //IMPLEMENTATION NOTE: if we couldn't copy the original (e.g. because
                //it didn't exist) but we're allowed to create the file if it's missing,
                //then don't treat this as a failure.
                //Only fail if we do require the original file to exist.
                if (!copied && !createIfMissing)
                {
                    if (outError)
                        *outError = copyError;
                    return NULL;
                }
            }
            
            return [self _openFileAtCanonicalFilesystemURL: shadowedURL
                                                    inMode: accessMode
                                                     error: outError];
        }
        
        //If we don't have a shadow file, but we're opening the file as read-only,
        //it's safe to try and open a handle from the original location.
        //This will fail if the original location doesn't exist.
        else
        {
            return [self _openFileAtCanonicalFilesystemURL: originalURL
                                                    inMode: accessMode
                                                     error: outError];
        }
    }
    else
    {
        return [self _openFileAtCanonicalFilesystemURL: originalURL
                                                inMode: accessMode
                                                 error: outError];
    }
}

- (BOOL) removeItemAtPath: (NSString *)path error: (out NSError **)outError
{
    NSURL *shadowedURL = [self _shadowedURLForLogicalPath: path];
    NSURL *sourceURL = [self _sourceURLForLogicalPath: path];
    
    if (shadowedURL)
    {
        NSURL *deletionMarkerURL = [shadowedURL URLByAppendingPathExtension: ADBShadowedDeletionMarkerExtension];
        
        BOOL originalExists = [sourceURL checkResourceIsReachableAndReturnError: NULL];
        
        //If a file exists at the original location, create a marker in the shadow location
        //indicating that the file has been deleted. We also clean up any shadowed
        //version of the file.
        if (originalExists)
        {
            [self _createDeletionMarkerAtURL: deletionMarkerURL];
            
            [self.manager removeItemAtURL: shadowedURL error: NULL];
            
            //Pretend that the deletion operation actually happened.
            return YES;
        }
        
        //If no file exists at the original path, then just clean up the shadow
        //(and any leftover deletion marker there).
        else
        {
            [self.manager removeItemAtURL: deletionMarkerURL error: NULL];
            return [self.manager removeItemAtURL: shadowedURL error: outError];
        }
    }
    else
    {
        return [self.manager removeItemAtURL: sourceURL error: outError];
    }
}



#pragma mark - ADBFilesystemLocalFileURLAccess methods

- (ADBShadowedDirectoryEnumerator *) enumeratorAtLocalFileURL: (NSURL *)URL
                                   includingPropertiesForKeys: (NSArray *)keys
                                                      options: (NSDirectoryEnumerationOptions)mask
                                                 errorHandler: (ADBFilesystemLocalFileURLErrorHandler)errorHandler
{
    NSString *path = [self logicalPathForLocalFileURL: URL];
    if (path)
    {
        NSURL *sourceURL = [self _sourceURLForLogicalPath: path];
        NSURL *shadowedURL = [self _shadowedURLForLogicalPath: path];
        
        return [[[ADBShadowedDirectoryEnumerator alloc] initWithLocalURL: sourceURL
                                                             shadowedURL: shadowedURL
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



#pragma mark - Internal file access methods

+ (ADBFileOpenOptions) _optionsFromAccessMode: (const char *)accessMode
{
    ADBFileOpenOptions options = 0;
    
    NSUInteger modeLength = strlen(accessMode);
    BOOL hasPlus = (modeLength >= 2 && accessMode[1] == '+') || (modeLength >= 3 && accessMode[2] == '+');
    
    switch (accessMode[0])
    {
        case 'r':
            options = ADBFileOpenForReading;
            if (hasPlus)
                options |= ADBFileOpenForWriting;
            break;
        case 'w':
            options = ADBFileOpenForWriting | ADBFileCreateIfMissing | ADBFileTruncate;
            if (hasPlus)
                options |= ADBFileOpenForReading;
            break;
        case 'a':
            options = ADBFileOpenForWriting | ADBFileCreateIfMissing | ADBFileAppend;
            if (hasPlus)
                options |= ADBFileOpenForReading;
            break;
    }
    
    return options;
}

- (FILE *) _openFileAtCanonicalFilesystemURL: (NSURL *)URL
                                      inMode: (const char *)accessMode
                                       error: (NSError **)outError
{
    const char *rep = URL.fileSystemRepresentation;
    FILE *handle = fopen(rep, accessMode);
    
    if (handle)
    {
        return handle;
    }
    else
    {
        if (outError)
        {
            NSInteger posixError = errno;
            *outError = [NSError errorWithDomain: NSPOSIXErrorDomain
                                            code: posixError
                                        userInfo: @{ NSURLErrorKey: URL }];
        }
        return NULL;
    }
}

- (void) _createDeletionMarkerAtURL: (NSURL *)markerURL
{
    //Ensure the filesystem structure leading up to this URL also exists
    [self.manager createDirectoryAtURL: markerURL.URLByDeletingLastPathComponent
           withIntermediateDirectories: YES
                            attributes: nil
                                 error: NULL];
    
    [self.manager createFileAtPath: markerURL.path
                          contents: [NSData data]
                        attributes: nil];
}

- (BOOL) _transferItemAtPath: (NSString *)fromPath
                      toPath: (NSString *)toPath
                     copying: (BOOL)copy
                       error: (NSError **)outError
{
    NSURL *shadowedToURL = [self _shadowedURLForLogicalPath: toPath];
    
    if (shadowedToURL)
    {
        NSURL *originalFromURL = [self _sourceURLForLogicalPath: fromPath];
        NSURL *shadowedFromURL = [self _shadowedURLForLogicalPath: fromPath];
        NSURL *fromDeletionMarkerURL = [shadowedFromURL URLByAppendingPathExtension: ADBShadowedDeletionMarkerExtension];
        NSURL *toDeletionMarkerURL = [shadowedToURL URLByAppendingPathExtension: ADBShadowedDeletionMarkerExtension];
        
        //If the source path has been marked as deleted, then the operation should fail.
        if ([fromDeletionMarkerURL checkResourceIsReachableAndReturnError: NULL])
        {
            if (outError)
            {
                NSURL *URL = [self.sourceURL URLByAppendingPathComponent: fromPath];
                *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                                code: NSFileReadNoSuchFileError
                                            userInfo: @{ NSURLErrorKey: URL }];
            }
            return NO;
        }
        
        //Ensure the destination folder is a directory or doesn't yet exist.
        NSString *destinationParent = toPath.stringByDeletingLastPathComponent;
        BOOL destinationParentIsDir, destinationParentExists = [self fileExistsAtPath: destinationParent
                                                                          isDirectory: &destinationParentIsDir];

        if (destinationParentExists && !destinationParentIsDir)
        {
            if (outError)
            {
                NSURL *URL = [self.sourceURL URLByAppendingPathComponent: toPath];
                *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                                code: NSFileWriteInvalidFileNameError
                                            userInfo: @{ NSURLErrorKey: URL }];
            }
            return NO;
        }
        
        //Ensure that a suitable folder structure exists in the shadow volume
        //to accommodate the destination.
        [self.manager createDirectoryAtURL: shadowedToURL.URLByDeletingLastPathComponent
               withIntermediateDirectories: YES
                                attributes: nil
                                     error: NULL];
        
        //TODO: rewrite this to use NSFileManager's file replacement API.
        
        //Remove any shadow of the destination before we begin, since we want to overwrite it.
        [self.manager removeItemAtURL: shadowedToURL error: NULL];
        
        //If the source file has a shadow, try using that as the source initially,
        //falling back on the original source if that fails.
        BOOL succeeded = [self.manager copyItemAtURL: shadowedFromURL
                                               toURL: shadowedToURL
                                               error: NULL];
        
        
        if (!succeeded)
        {
            succeeded = [self.manager copyItemAtURL: originalFromURL
                                              toURL: shadowedToURL
                                              error: outError];
        }
        
        if (succeeded)
        {
            //If the initial copy succeeded, then remove any shadowed source and flag
            //the original source as deleted (since it has ostensibly been moved.)
            if (!copy)
            {
                [self.manager removeItemAtURL: shadowedFromURL error: NULL];
                
                BOOL originalExists = [originalFromURL checkResourceIsReachableAndReturnError: NULL];
                if (originalExists)
                {
                    [self _createDeletionMarkerAtURL: fromDeletionMarkerURL];
                }
            }
            
            //Remove any leftover deletion marker for the destination.
            [self.manager removeItemAtURL: toDeletionMarkerURL error: NULL];
            
            return YES;
        }
        
        //If the copy failed, delete any partially-copied files.
        else
        {
            [self.manager removeItemAtURL: shadowedToURL error: NULL];
            
            return NO;
        }
    }
    else
    {
        NSURL *fromURL = [self.sourceURL URLByAppendingPathComponent: fromPath];
        NSURL *toURL = [self.sourceURL URLByAppendingPathComponent: toPath];
        return [self.manager moveItemAtURL: fromURL toURL: toURL error: outError];
    }
}


#pragma mark - Housekeeping

- (BOOL) tidyShadowContentsForPath: (NSString *)path
                             error: (out NSError **)outError
{
    NSURL *baseShadowURL = [self _shadowedURLForLogicalPath: path];
    if (baseShadowURL)
    {
        NSMutableSet *emptyDirectories = [NSMutableSet setWithCapacity: 10];
        
        NSArray *properties = [NSArray arrayWithObjects:
                               NSURLIsDirectoryKey,
                               NSURLParentDirectoryURLKey,
                               nil];
        
        NSDirectoryEnumerator *shadowEnumerator = [self.manager enumeratorAtURL: baseShadowURL
                                                     includingPropertiesForKeys: properties
                                                                        options: 0
                                                                   errorHandler: nil];

        for (NSURL *shadowedURL in shadowEnumerator)
        {
            //Clean up deletion markers that don't have a corresponding source URL.
            if ([shadowedURL.pathExtension isEqualToString: ADBShadowedDeletionMarkerExtension])
            {
                NSURL *sourceURL = [self _sourceURLForShadowedURL: shadowedURL];
                if (![sourceURL checkResourceIsReachableAndReturnError: NULL])
                {
                    BOOL cleanedUpDeletionMarker = [self.manager removeItemAtURL: shadowedURL error: outError];
                    if (!cleanedUpDeletionMarker)
                        return NO;
                }
            }
            else
            {
                //Put together a list of directories...
                NSNumber *isDirFlag = nil;
                [shadowedURL getResourceValue: &isDirFlag
                                       forKey: NSURLIsDirectoryKey
                                        error: NULL];
                
                if (isDirFlag.boolValue)
                {
                    [emptyDirectories addObject: shadowedURL];
                }
                
                //...but remove directories from the list that have contents of their own. 
                NSURL *parentURL = nil;
                [shadowedURL getResourceValue: &parentURL
                                       forKey: NSURLParentDirectoryURLKey
                                        error: NULL];
                
                [emptyDirectories removeObject: parentURL];
            }
        }
        
        //What's left is a list of empty directories. Check each one to see if it exists
        //in the original location: if it does, the shadow is redundant and we remove it.
        for (NSURL *shadowDirectoryURL in emptyDirectories)
        {
            NSURL *sourceDirectoryURL = [self _sourceURLForShadowedURL: shadowDirectoryURL];
            
            BOOL sourceIsDirectory;
            BOOL sourceExists = [self.manager fileExistsAtPath: sourceDirectoryURL.path
                                                   isDirectory: &sourceIsDirectory];
            
            //NOTE: we make sure also that the original is also a directory: if the shadowed
            //filesystem has replaced a file with a directory, then we should keep the
            //shadowed directory around.
            if (sourceExists && sourceIsDirectory)
            {
                BOOL cleanedUpDirectory = [self.manager removeItemAtURL: shadowDirectoryURL error: outError];
                if (!cleanedUpDirectory)
                    return NO;
            }
        }
    }
    
    //If we got this far, either we don't have any shadow or our cleanup was a rousing success.
    return YES;
}

- (BOOL) clearShadowContentsForPath: (NSString *)basePath error: (NSError **)outError
{
    NSURL *baseShadowURL = [self _shadowedURLForLogicalPath: basePath];
    if (baseShadowURL)
    {
        //Simply delete the shadow URL altogether. That was easy!
        NSError *removalError;
        BOOL removedShadow = [self.manager removeItemAtURL: baseShadowURL error: &removalError];
        
        //Ignore failure if the shadow simply didn't exist.
        if (!removedShadow)
        {
            if ([removalError matchesDomain: NSCocoaErrorDomain code: NSFileNoSuchFileError])
            {
                removedShadow = YES;
            }
            else
            {
                if (outError)
                    *outError = removalError;
            }
        }
        return removedShadow;
    }
    //If we aren't shadowed anyway, there's nothing for us to do.
    else
    {
        return YES;
    }
}

- (BOOL) _mergeItemAtShadowURL: (NSURL *)shadowedURL
                   toSourceURL: (NSURL *)sourceURL
                         error: (NSError **)outError
{   
    //Delete the source if it has been marked as deleted in the shadow.
    if ([shadowedURL.pathExtension isEqualToString: ADBShadowedDeletionMarkerExtension])
    {
        NSError *deletionError;
        
        BOOL deleted = [self.manager removeItemAtURL: sourceURL error: &deletionError];
        
        //Work out why the deletion of the original failed: if it was just that
        //the original didn't exist then treat this as successful, otherwise fail.
        if (!deleted)
        {
            if ([deletionError matchesDomain: NSCocoaErrorDomain code: NSFileNoSuchFileError])
            {
                deleted = YES;
            }
            else
            {
                if (outError)
                    *outError = deletionError;
            }
        }
        
        return deleted;
    }
    else
    {
        NSNumber *isDirectory = nil;
        [shadowedURL getResourceValue: &isDirectory
                               forKey: NSURLIsDirectoryKey
                                error: NULL];
        
        //If the shadow is a directory, simply ensure that the directory structure exists in the source.
        //Our calling context, mergeShadowContentsForURL:error:, will merge its contents later.
        if (isDirectory.boolValue)
        {
            BOOL createdDir = [self.manager createDirectoryAtURL: sourceURL
                                     withIntermediateDirectories: YES
                                                      attributes: nil
                                                           error: outError];
            
            //If we couldn't recreate the directory in the source location,
            //fail out.
            if (!createdDir)
            {
                return NO;
            }
        }
        //If the shadow is a regular file, then remove the original
        //and replace it with the shadowed version.
        //FIXME: this suffers from race conditions and should be rephrased
        //to use the atomic replaceItemAtURL:withItemAtURL: method or similar.
        else
        {   
            NSError *replacementError;
            BOOL movedToSource = [self.manager moveItemAtURL: shadowedURL
                                                       toURL: sourceURL
                                                       error: &replacementError];
            
            if (!movedToSource)
            {
                //If the move failed because the source already existed,
                //then try deleting the source and reattempt the move.
                //If that fails, give up entirely.
                if ([replacementError matchesDomain: NSCocoaErrorDomain
                                               code: NSFileWriteFileExistsError])
                {
                    BOOL removedSource = [self.manager removeItemAtURL: sourceURL
                                                                 error: outError];
                    
                    if (!removedSource)
                        return NO;
                    
                    BOOL replacedSource = [self.manager moveItemAtURL: shadowedURL
                                                                toURL: sourceURL
                                                                error: outError];
                    
                    if (!replacedSource)
                        return NO;
                }
                //If the move failed for some other reason, bail out altogether.
                else
                {
                    if (outError)
                        *outError = replacementError;
                    return NO;
                }
                
            }
        }
        
        return YES;
    }
}

- (BOOL) mergeShadowContentsForPath: (NSString *)basePath error: (NSError **)outError
{
    NSURL *baseSourceURL = [self _sourceURLForLogicalPath: basePath];
    NSURL *baseShadowedURL = [self _shadowedURLForLogicalPath: basePath];
    if (baseShadowedURL)
    {
        //If the shadow doesn't actually exist, treat the merge as successful
        //(we just have nothing that needs merging.)
        BOOL baseExists = [baseShadowedURL checkResourceIsReachableAndReturnError: NULL];
        if (!baseExists)
            return YES;
        
        NSNumber *isDirectory = nil;
        [baseShadowedURL getResourceValue: &isDirectory
                                   forKey: NSURLIsDirectoryKey
                                    error: NULL];
        
        //If the base URL is a directory, merge its contents.
        if (isDirectory.boolValue)
        {   
            NSArray *properties = [NSArray arrayWithObjects:
                                   NSURLIsDirectoryKey,
                                   nil];
            
            NSDirectoryEnumerator *shadowEnumerator = [self.manager enumeratorAtURL: baseShadowedURL
                                                         includingPropertiesForKeys: properties
                                                                            options: 0
                                                                       errorHandler: nil];
            
            for (NSURL *shadowedURL in shadowEnumerator)
            {
                NSURL *sourceURL = [self _sourceURLForShadowedURL: shadowedURL];
                BOOL merged = [self _mergeItemAtShadowURL: shadowedURL toSourceURL: sourceURL error: outError];
                
                if (!merged)
                    return NO;
            }
        }
        //Otherwise, merge the base URL as a single file.
        else
        {
            BOOL merged = [self _mergeItemAtShadowURL: baseShadowedURL toSourceURL: baseSourceURL error: outError];
            if (!merged)
                return NO;
        }
        
        //If we got this far, then the shadow contents were merged successfully.
        //Remove the base shadow URL altogether.
        [self.manager removeItemAtURL: baseShadowedURL error: NULL];
        
        return YES;
    }
    else
    {
        return YES;
    }
}

@end




@interface ADBShadowedDirectoryEnumerator ()

@property (copy, nonatomic) NSURL *currentURL;

@property (retain, nonatomic) NSDirectoryEnumerator *localEnumerator;
@property (retain, nonatomic) NSDirectoryEnumerator *shadowEnumerator;
@property (assign, nonatomic) NSDirectoryEnumerator *currentEnumerator;

@property (retain, nonatomic) NSMutableSet *shadowedPaths;
@property (retain, nonatomic) NSMutableSet *deletedPaths;

@property (retain, nonatomic) ADBShadowedFilesystem *filesystem;

- (NSURL *) _nextURLFromLocal;
- (NSURL *) _nextURLFromShadow;

@end

@implementation ADBShadowedDirectoryEnumerator

@synthesize localEnumerator = _localEnumerator;
@synthesize shadowEnumerator = _shadowEnumerator;
@synthesize currentEnumerator = _currentEnumerator;
@synthesize shadowedPaths = _shadowedPaths;
@synthesize deletedPaths = _deletedPaths;
@synthesize filesystem = _filesystem;

@synthesize currentURL = _currentURL;


- (id) initWithLocalURL: (NSURL *)localURL
            shadowedURL: (NSURL *)shadowedURL
            inFilesytem: (ADBShadowedFilesystem *)filesystem
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
        
        NSFileManager *manager = [NSFileManager defaultManager];
        
        self.localEnumerator = [manager enumeratorAtURL: localURL
                             includingPropertiesForKeys: keys
                                                options: mask
                                           errorHandler: errorHandler];
        
        if (shadowedURL)
        {
            self.shadowEnumerator = [manager enumeratorAtURL: shadowedURL
                                  includingPropertiesForKeys: keys
                                                     options: mask
                                                errorHandler: errorHandler];
            
            self.currentEnumerator = self.shadowEnumerator;
            self.shadowedPaths = [NSMutableSet set];
            self.deletedPaths = [NSMutableSet set];
        }
        else
        {
            self.currentEnumerator = self.localEnumerator;
        }
    }
    return self;
}

- (void) dealloc
{
    self.localEnumerator = nil;
    self.shadowEnumerator = nil;
    self.currentEnumerator = nil;
    self.shadowedPaths = nil;
    self.deletedPaths = nil;
    self.filesystem = nil;
    self.currentURL = nil;
    
    [super dealloc];
}

- (void) skipDescendants
{
    [self.currentEnumerator skipDescendants];
}

- (NSUInteger) level
{
    return self.currentEnumerator.level;
}

- (id) nextObject
{
    BOOL isEnumeratingShadow = (self.currentEnumerator == self.shadowEnumerator);
    
    NSURL *nextURL;
    
    //We start off enumerating the shadow folder if one is available, as its state will
    //override the state of the source folder. Along the way we mark which files have been
    //shadowed or deleted, so that we can skip those when enumerating the source folder.
    if (isEnumeratingShadow)
    {
        nextURL = [self _nextURLFromShadow];
        if (!nextURL)
        {
            self.currentEnumerator = self.localEnumerator;
            nextURL = [self _nextURLFromLocal];
        }
    }
    else
    {
        nextURL = [self _nextURLFromLocal];
    }
    
    self.currentURL = nextURL;
    
    if (nextURL == nil)
        return nil;
    else if (_returnsFileURLs)
        return nextURL;
    else
        return [self.filesystem logicalPathForLocalFileURL: nextURL];
}

- (NSURL *) _nextURLFromLocal
{
    NSURL *nextURL;
    while ((nextURL = [self.localEnumerator nextObject]) != nil)
    {
        NSString *filesystemPath = [self.filesystem logicalPathForLocalFileURL: nextURL];
        
        //If this path was marked as deleted in the shadow, ignore it
        //and skip any descendants if it was a directory.
        if ([self.deletedPaths containsObject: filesystemPath])
        {
            [self skipDescendants];
            continue;
        }
        
        //If this path was already enumerated by the shadow, ignore it.
        if ([self.shadowedPaths containsObject: filesystemPath]) continue;
        
        return nextURL;
    }
    
    return nil;
}

- (NSURL *) _nextURLFromShadow
{
    NSURL *nextURL;
    while ((nextURL = [self.shadowEnumerator nextObject]) != nil)
    {
        NSString *filesystemPath = [self.filesystem logicalPathForLocalFileURL: nextURL];
        
        //Skip over shadow deletion markers, but mark the filename so that we'll also skip
        //the 'deleted' version when enumerating the original source location.
        if ([filesystemPath.pathExtension isEqualToString: ADBShadowedDeletionMarkerExtension])
        {
            [self.deletedPaths addObject: filesystemPath.stringByDeletingPathExtension];
            continue;
        }
        
        //Mark shadowed files so that we'll skip them when enumerating the source folder.
        [self.shadowedPaths addObject: filesystemPath];
        
        return nextURL;
    }
    
    return nil;
}

- (NSDictionary *) fileAttributes
{
    //IMPLEMENTATION NOTE: our own NSDirectoryEnumerators are URL-based, so we can't use
    //their own fileAttributes method (which always returns nil for URL-based enumerators).
    return [[NSFileManager defaultManager] attributesOfItemAtPath: self.currentURL.path error: NULL];
}

@end