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
#import "ADBLocalFilesystemPrivate.h"
#import "NSURL+ADBFilesystemHelpers.h"
#import "NSError+ADBErrorHelpers.h"
#import "ADBForwardCompatibility.h"
#import "ADBFileHandle.h"

#pragma mark -
#pragma mark Private constants

NSString * const ADBShadowedDeletionMarkerExtension = @"deleted";


#pragma mark -
#pragma mark Private method declarations

@interface ADBShadowedFilesystem ()

//Overridden to be read-writable.
@property (copy, nonatomic) NSURL *shadowURL;

//Create a 0-byte deletion marker at the specified shadow URL.
- (void) _createDeletionMarkerAtURL: (NSURL *)markerURL;

//Used internally by mergeContentsOfURL:error: to merge each item back into the source.
- (BOOL) _mergeItemAtShadowURL: (NSURL *)shadowedURL
                   toSourceURL: (NSURL *)sourceURL
                         error: (NSError **)outError;

//Internal path conversion methods.
- (NSURL *) _sourceURLForLogicalPath: (NSString *)path;
- (NSURL *) _shadowedURLForLogicalPath: (NSString *)path;
- (NSURL *) _shadowedURLForSourceURL: (NSURL *)URL;
- (NSURL *) _sourceURLForShadowedURL: (NSURL *)URL;
@end


//A directory enumerator returned by ADBShadowedFilesystem's enumeratorAtURL: and enumeratorAtPath: methods.
//Analoguous to NSDirectoryEnumerator, except that it folds together the original and shadowed
//filesystems into a single filesystem. Any files and directories marked as deleted will be skipped.
//Note that this will return shadowed files first followed by untouched original files, rather
//than the straight depth-first traversal performed by NSDirectoryEnumerator.
@interface ADBShadowedDirectoryEnumerator : NSEnumerator <ADBFilesystemPathEnumeration, ADBFilesystemFileURLEnumeration>
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
           errorHandler: (ADBFilesystemFileURLErrorHandler)errorHandler;

@end


#pragma mark -
#pragma mark Implementation

@implementation ADBShadowedFilesystem
@synthesize shadowURL = _shadowURL;

#pragma mark - Initialization and deallocation

+ (id) filesystemWithBaseURL: (NSURL *)sourceURL shadowURL: (NSURL *)shadowURL
{
    return [[self alloc] initWithBaseURL: sourceURL shadowURL: shadowURL];
}

- (id) initWithBaseURL: (NSURL *)sourceURL shadowURL: (NSURL *)shadowURL
{
    self = [self init];
    if (self)
    {
        self.baseURL = sourceURL;
        self.shadowURL = shadowURL;
    }
    return self;
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
    
    if (![URL isEqual: _shadowURL])
    {
        if (_shadowURL)
            [self removeRepresentedURL: _shadowURL];
        
        _shadowURL = [URL copy];
        
        if (_shadowURL)
            [self addRepresentedURL: _shadowURL];
    }
}

#pragma mark - Path translation

- (NSString *) pathForFileURL: (NSURL *)URL
{
    if (self.shadowURL)
    {
        NSString *relativePath = nil;
        
        if ([URL isBasedInURL: self.baseURL])
            relativePath = [URL pathRelativeToURL: self.baseURL];
        
        else if ([URL isBasedInURL: self.shadowURL])
            relativePath = [URL pathRelativeToURL: self.shadowURL];
        
        //Convert paths generated by pathRelativeToURL: to "absolute" paths,
        //consistent with requirements of ADBFilesystem API
        if (relativePath)
        {
            return [@"/" stringByAppendingPathComponent: relativePath];
        }
        else
        {
            return nil;
        }
    }
    else
    {
        return [super pathForFileURL: URL];
    }
}

- (NSURL *) fileURLForPath: (NSString *)path
{
    if (self.shadowURL)
    {
        //Ensure that paths such as "../path/outside/filesystem/" won't work
        path = path.stringByStandardizingPath;
        
        NSURL *shadowURL = [self.shadowURL URLByAppendingPathComponent: path];
        NSURL *deletionMarkerURL = [shadowURL URLByAppendingPathExtension: ADBShadowedDeletionMarkerExtension];
        
        //If the file has been shadowed, and hasn't been flagged as deleted in the shadow,
        //return the shadow URL.
        if ([shadowURL checkResourceIsReachableAndReturnError: NULL] &&
            ![deletionMarkerURL checkResourceIsReachableAndReturnError: NULL])
            return shadowURL.URLByStandardizingPath;
        
        //Otherwise, use the original source URL to resolve the path.
        NSURL *localURL = [self.baseURL URLByAppendingPathComponent: path];
        return localURL.URLByStandardizingPath;
    }
    else
    {
        return [super fileURLForPath: path];
    }
}

- (BOOL) exposesFileURL: (NSURL *)URL
{
    NSAssert(URL != nil, @"No URL provided!");
    return [URL isBasedInURL: self.baseURL] || [URL isBasedInURL: self.shadowURL];
}

- (NSURL *) _shadowedURLForLogicalPath: (NSString *)path
{
    NSAssert(path != nil, @"No path provided!");
    return [self.shadowURL URLByAppendingPathComponent: path.stringByStandardizingPath].URLByStandardizingPath;
}

- (NSURL *) _sourceURLForLogicalPath: (NSString *)path
{
    NSAssert(path != nil, @"No path provided!");
    return [self.baseURL URLByAppendingPathComponent: path.stringByStandardizingPath].URLByStandardizingPath;
}

- (NSURL *) _shadowedURLForSourceURL: (NSURL *)URL
{
    //If we don't have a shadow, or the specified URL isn't located within
    //our source URL, there is no shadow URL that would be applicable.
    if (!self.shadowURL || ![URL isBasedInURL: self.baseURL])
        return nil;
    
    NSString *relativePath = [URL pathRelativeToURL: self.baseURL];
    
    return [self.shadowURL URLByAppendingPathComponent: relativePath].URLByStandardizingPath;
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
    
    return [self.baseURL URLByAppendingPathComponent: relativePath].URLByStandardizingPath;
}


#pragma mark - ADBFilesystemPathAccess methods

- (BOOL) fileExistsAtPath: (NSString *)path isDirectory: (BOOL *)isDirectory
{
    if (self.shadowURL)
    {
        NSURL *originalURL = [self _sourceURLForLogicalPath: path];
        NSURL *shadowedURL = [self _shadowedURLForLogicalPath: path];

        NSURL *deletionMarkerURL = [shadowedURL URLByAppendingPathExtension: ADBShadowedDeletionMarkerExtension];
        
        //If the file is flagged as deleted, pretend it doesn't exist.
        if ([deletionMarkerURL checkResourceIsReachableAndReturnError: NULL])
        {
            if (isDirectory)
                *isDirectory = NO;
            return NO;
        }
        
        //Otherwise, if either the source or a shadow exist, treat the file as existing.
        else if ([self.manager fileExistsAtPath: shadowedURL.path isDirectory: isDirectory])
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
        return [super fileExistsAtPath: path isDirectory: isDirectory];
    }
}

- (id <ADBFilesystemPathEnumeration>) enumeratorAtPath: (NSString *)path
                                               options: (NSDirectoryEnumerationOptions)options
                                          errorHandler: (ADBFilesystemPathErrorHandler)errorHandler
{
    if (self.shadowURL)
    {
        NSURL *sourceURL = [self _sourceURLForLogicalPath: path];
        NSURL *shadowedURL = [self _shadowedURLForLogicalPath: path];
        
        ADBFilesystemFileURLErrorHandler wrappedHandler;
        if (errorHandler)
        {
            wrappedHandler = ^BOOL(NSURL *url, NSError *error) {
                NSString *logicalPath = [self pathForFileURL: url];
                return errorHandler(logicalPath, error);
            };
        }
        else
            wrappedHandler = nil;
        
        return [[ADBShadowedDirectoryEnumerator alloc] initWithLocalURL: sourceURL
                                                            shadowedURL: shadowedURL
                                                            inFilesytem: self
                                             includingPropertiesForKeys: nil
                                                                options: options
                                                             returnURLs: NO
                                                           errorHandler: wrappedHandler];
    }
    else
    {
        return [super enumeratorAtPath: path options: options errorHandler: errorHandler];
    }
}

- (BOOL) createDirectoryAtPath: (NSString *)path
   withIntermediateDirectories: (BOOL)createIntermediates
                         error: (out NSError **)outError
{
    if (self.shadowURL)
    {
        NSURL *originalURL = [self _sourceURLForLogicalPath: path];
        NSURL *shadowedURL = [self _shadowedURLForLogicalPath: path];
        
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
        return [super createDirectoryAtPath: path withIntermediateDirectories: createIntermediates error: outError];
    }
}

- (id <ADBFileHandleAccess, ADBReadable, ADBWritable, ADBSeekable>) fileHandleAtPath: (NSString *)path
                                                                             options: (ADBHandleOptions)options
                                                                               error: (out NSError **)outError
{
    NSAssert((options & ADBCreateAlways) == 0, @"ADBCreateAlways is not currently supported.");
    
    if (self.shadowURL)
    {
        NSURL *originalURL = [self _sourceURLForLogicalPath: path];
        NSURL *shadowedURL = [self _shadowedURLForLogicalPath: path];
        
        NSURL *deletionMarkerURL = [shadowedURL URLByAppendingPathExtension: ADBShadowedDeletionMarkerExtension];
        
        BOOL createIfMissing = (options & ADBCreateIfMissing) == ADBCreateIfMissing;
        
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
                
                return [ADBFileHandle handleForURL: shadowedURL options: options error: outError];
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
        
        //If the shadow file already exists, open the shadow with whatever mode was requested.
        //IMPLEMENTATION NOTE: conventional wisdom dictates we should just try to open it
        //and see if that worked without checking for file existence first, then use fallbacks
        //if it does fail; however this is undesirable in the case where we want to modify
        //the file's existing contents *or* create the file if it doesn't exist.
        else if (shadowExists)
        {
            return [ADBFileHandle handleForURL: shadowedURL options: options error: outError];
        }
        
        //If we're opening the file for writing and we don't have a shadowed version of it,
        //copy any original version to the shadowed location first (creating any necessary
        //directories along the way) and then open the newly-shadowed copy.
        else if ((options & ADBOpenForWriting) != 0)
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
            BOOL truncateExistingFile = (options & ADBTruncate) == ADBTruncate;
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
            
            return [ADBFileHandle handleForURL: shadowedURL options: options error: outError];
        }
        
        //If we don't have a shadow file, but we're opening the file as read-only,
        //it's safe to try and open a handle from the original location.
        //This will fail if the original location doesn't exist.
        else
        {
            return [ADBFileHandle handleForURL: originalURL options: options error: outError];
        }
    }
    else
    {
        return [super fileHandleAtPath: path options: options error: outError];
    }
}

- (FILE *) openFileAtPath: (NSString *)path
                   inMode: (const char *)accessMode
                    error: (out NSError **)outError
{
    ADBHandleOptions options = [ADBFileHandle optionsForPOSIXAccessMode: accessMode];
    return [[self fileHandleAtPath: path options: options error: outError] fileHandleAdoptingOwnership: YES];
}


- (BOOL) removeItemAtPath: (NSString *)path error: (out NSError **)outError
{
    if (self.shadowURL)
    {
        NSURL *shadowedURL = [self _shadowedURLForLogicalPath: path];
        NSURL *sourceURL = [self _sourceURLForLogicalPath: path];
        
        NSURL *deletionMarkerURL = [shadowedURL URLByAppendingPathExtension: ADBShadowedDeletionMarkerExtension];
        
        BOOL originalExists = [sourceURL checkResourceIsReachableAndReturnError: NULL];
        BOOL deletionMarkerExists = [deletionMarkerURL checkResourceIsReachableAndReturnError: NULL];
        
        //If this file has already been marked as deleted, pretend to fail
        //since we cannot delete an already-deleted file.
        if (deletionMarkerExists)
        {
            if (outError)
            {
                *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                                code: NSFileNoSuchFileError
                                            userInfo: @{ NSFilePathErrorKey: path }];
            }
            return NO;
        }
        
        //If a file exists at the original location, create a marker in the shadow location
        //indicating that the file has been deleted. We also clean up any shadowed
        //version of the file.
        else if (originalExists)
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
        return [super removeItemAtPath: path error: outError];
    }
}



#pragma mark - ADBFilesystemFileURLAccess methods

- (id <ADBFilesystemFileURLEnumeration>) enumeratorAtFileURL: (NSURL *)URL
                                            includingPropertiesForKeys: (NSArray *)keys
                                                               options: (NSDirectoryEnumerationOptions)options
                                                          errorHandler: (ADBFilesystemFileURLErrorHandler)errorHandler
{
    if (self.shadowURL)
    {
        if ([self exposesFileURL: URL])
        {
            NSString *path = [self pathForFileURL: URL];
            NSURL *sourceURL = [self _sourceURLForLogicalPath: path];
            NSURL *shadowedURL = [self _shadowedURLForLogicalPath: path];
            
            return [[ADBShadowedDirectoryEnumerator alloc] initWithLocalURL: sourceURL
                                                                shadowedURL: shadowedURL
                                                                inFilesytem: self
                                                 includingPropertiesForKeys: keys
                                                                    options: options
                                                                 returnURLs: YES
                                                               errorHandler: errorHandler];
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
    else
    {
        return [super enumeratorAtFileURL: URL
                    includingPropertiesForKeys: keys
                                       options: options
                                  errorHandler: errorHandler];
    }
}



#pragma mark - Internal file access methods

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
    if (self.shadowURL)
    {
        NSURL *originalFromURL  = [self _sourceURLForLogicalPath: fromPath];
        NSURL *shadowedFromURL  = [self _shadowedURLForLogicalPath: fromPath];
        NSURL *shadowedToURL    = [self _shadowedURLForLogicalPath: toPath];
        
        NSURL *fromDeletionMarkerURL = [shadowedFromURL URLByAppendingPathExtension: ADBShadowedDeletionMarkerExtension];
        NSURL *toDeletionMarkerURL = [shadowedToURL URLByAppendingPathExtension: ADBShadowedDeletionMarkerExtension];
        
        //If the source path has been marked as deleted, then the operation should fail.
        if ([fromDeletionMarkerURL checkResourceIsReachableAndReturnError: NULL])
        {
            if (outError)
            {
                NSURL *URL = [self.baseURL URLByAppendingPathComponent: fromPath];
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
                NSURL *URL = [self.baseURL URLByAppendingPathComponent: toPath];
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
        return [super _transferItemAtPath: fromPath toPath: toPath copying: copy error: outError];
    }
}


#pragma mark - Housekeeping

- (BOOL) tidyShadowContentsForPath: (NSString *)path
                             error: (out NSError **)outError
{
    if (self.shadowURL)
    {
        NSURL *baseShadowURL = [self _shadowedURLForLogicalPath: path];
    
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
    if (self.shadowURL)
    {
        NSURL *baseShadowURL = [self _shadowedURLForLogicalPath: basePath];
        
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
    if (self.shadowURL)
    {
        NSURL *baseSourceURL = [self _sourceURLForLogicalPath: basePath];
        NSURL *baseShadowedURL = [self _shadowedURLForLogicalPath: basePath];
    
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
           errorHandler: (ADBFilesystemFileURLErrorHandler)errorHandler
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
        return [self.filesystem pathForFileURL: nextURL];
}

- (NSURL *) _nextURLFromLocal
{
    NSURL *nextURL;
    while ((nextURL = [self.localEnumerator nextObject]) != nil)
    {
        NSString *filesystemPath = [self.filesystem pathForFileURL: nextURL];
        
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
        NSString *filesystemPath = [self.filesystem pathForFileURL: nextURL];
        
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