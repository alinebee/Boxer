/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXShadowedFilesystem.h"
#import "NSURL+BXFilePaths.h"
#import "NSError+BXErrorHelpers.h"
#import "BXPostLeopardAPIs.h"

#pragma mark -
#pragma mark Private constants

NSString * const BXShadowedDeletionMarkerExtension = @"deleted";


enum {
    BXFileOpenForReading,
    BXFileOpenForWriting,
    BXFileCreateIfMissing,
    BXFileTruncate,
    BXFileAppend
};

typedef NSUInteger BXFileOpenOptions;

#pragma mark -
#pragma mark Private method declarations

@interface BXShadowedFilesystem ()

//Our own file manager for internal use.
@property (retain, nonatomic) NSFileManager *manager;

//Parses an fopen()-format mode string into a set of bitflags.
+ (BXFileOpenOptions) optionsFromAccessMode: (const char *)accessMode;

//Internal implementation for moveItemAtURL:toURL:error: and copyItemAtURL:toURL:error:.
- (BOOL) _transferItemAtURL: (NSURL *)fromURL
                      toURL: (NSURL *)toURL
                    copying: (BOOL)copy
                      error: (NSError **)outError;

//Create a 0-byte deletion marker at the specified URL.
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


#pragma mark -
#pragma mark Implementation

@implementation BXShadowedFilesystem
@synthesize sourceURL = _sourceURL;
@synthesize shadowURL = _shadowURL;
@synthesize manager = _manager;


#pragma mark -
#pragma mark Initialization and deallocation

+ (id) filesystemWithSourceURL:(NSURL *)sourceURL shadowURL:(NSURL *)shadowURL
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

#pragma mark -
#pragma mark Path translation

- (NSURL *) shadowedURLForURL: (NSURL *)URL
{
    //If we don't have a shadow, or the specified URL isn't located within
    //our source URL, there is no shadow URL that would be applicable.
    if (!self.shadowURL || ![URL isBasedInURL: self.sourceURL])
        return nil;
    
    NSString *relativePath = [URL pathRelativeToURL: self.sourceURL];
    
    return [self.shadowURL URLByAppendingPathComponent: relativePath];
}

- (NSURL *) sourceURLForURL: (NSURL *)URL
{
    //If we don't have a shadow, or the specified URL isn't located within
    //our shadow URL, there is no source URL that would be applicable.
    if (!self.shadowURL || ![URL isBasedInURL: self.shadowURL])
        return nil;
    
    NSString *relativePath = [URL pathRelativeToURL: self.shadowURL];
    
    //If this is a deletion marker, map it back to the original file
    if ([relativePath.pathExtension isEqualToString: BXShadowedDeletionMarkerExtension])
        relativePath = relativePath.stringByDeletingPathExtension;
    
    return [self.sourceURL URLByAppendingPathComponent: relativePath];
}

- (NSURL *) canonicalFilesystemURL: (NSURL *)URL
{
    NSURL *shadowURL = [self shadowedURLForURL: URL];
    NSURL *deletionMarkerURL = [shadowURL URLByAppendingPathExtension: BXShadowedDeletionMarkerExtension];
    
    //File has been marked as deleted and thus cannot be accessed.
    if ([deletionMarkerURL checkResourceIsReachableAndReturnError: NULL])
        return nil;
    
    //File has been shadowed, return the shadow URL.
    if ([shadowURL checkResourceIsReachableAndReturnError: NULL])
        return shadowURL;
    
    //Otherwise, return the original source URL...
    if ([URL checkResourceIsReachableAndReturnError: NULL])
        return URL;
    
    //...Unless the file didn't exist.
    else return nil;
}

- (const char *) fileSystemRepresentationForURL: (NSURL *)URL
{
    NSURL *canonicalURL = [self canonicalFilesystemURL: URL];
    return canonicalURL.fileSystemRepresentation;
}

- (NSURL *) URLFromFileSystemRepresentation: (const char *)representation
{
    NSURL *originalURL = [NSURL URLFromFileSystemRepresentation: representation];
    
    NSURL *sourceURL = [self sourceURLForURL: originalURL];
    //If the URL was located within the shadow, return the equivalent URL within the source.
    if (sourceURL)
        return sourceURL;
    //Otherwise, return the URL as-is.
    else
        return originalURL;
}

#pragma mark -
#pragma mark Enumeration

- (BXShadowedDirectoryEnumerator *) enumeratorAtURL: (NSURL *)URL
                         includingPropertiesForKeys: (NSArray *)keys
                                            options: (NSDirectoryEnumerationOptions)mask
                                       errorHandler: (BXDirectoryEnumeratorErrorHandler)errorHandler
{
    NSURL *shadowedURL = [self shadowedURLForURL: URL];
    
    return [[[BXShadowedDirectoryEnumerator alloc] initWithFilesystem: self
                                                            sourceURL: URL
                                                            shadowURL: shadowedURL
                                           includingPropertiesForKeys: keys
                                                              options: mask
                                                         errorHandler: errorHandler] autorelease];
}


#pragma mark -
#pragma mark File operations

+ (BXFileOpenOptions) optionsFromAccessMode: (const char *)accessMode
{
    BXFileOpenOptions options = 0;
    
    NSUInteger modeLength = strlen(accessMode);
    BOOL hasPlus = (modeLength >= 2 && accessMode[1] == '+') || (modeLength >= 3 && accessMode[2] == '+');
    
    switch (accessMode[0])
    {
        case 'r':
            options = BXFileOpenForReading;
            if (hasPlus)
                options |= BXFileOpenForWriting;
            break;
        case 'w':
            options = BXFileOpenForWriting | BXFileCreateIfMissing | BXFileTruncate;
            if (hasPlus)
                options |= BXFileOpenForReading;
            break;
        case 'a':
            options = BXFileOpenForWriting | BXFileCreateIfMissing | BXFileAppend;
            if (hasPlus)
                options |= BXFileOpenForReading;
            break;
    }
    
    return options;
}

- (FILE *) openFileAtURL: (NSURL *)URL
                  inMode: (const char *)accessMode
                   error: (NSError **)outError
{
    NSURL *shadowedURL = [self shadowedURLForURL: URL];
    if (shadowedURL)
    {
        NSURL *deletionMarkerURL = [shadowedURL URLByAppendingPathExtension: BXShadowedDeletionMarkerExtension];
        
        BXFileOpenOptions accessOptions = [self.class optionsFromAccessMode: accessMode];
        BOOL createIfMissing = (accessOptions & BXFileCreateIfMissing) == BXFileCreateIfMissing;
        
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
                    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                              URL, NSURLErrorKey,
                                              nil];
                    
                    *outError = [NSError errorWithDomain: NSPOSIXErrorDomain
                                                    code: ENOENT //No such file or directory
                                                userInfo: userInfo];
                }
                return NULL;
            }
        }
        
        //If the shadow file already exists, open the shadow with whatever
        //access mode was requested.
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
        else if ((accessOptions & BXFileOpenForWriting))
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
            BOOL truncateExistingFile = (accessOptions & BXFileTruncate) == BXFileTruncate;
            if (!truncateExistingFile)
            {
                NSError *copyError = nil;
                //Ensure we're copying the actual file and not a symlink.
                NSURL *resolvedURL = [URL URLByResolvingSymlinksInPath];
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
            return [self _openFileAtCanonicalFilesystemURL: URL
                                                    inMode: accessMode
                                                     error: outError];
        }
    }
    else
    {
        return [self _openFileAtCanonicalFilesystemURL: URL
                                                inMode: accessMode
                                                 error: outError];
    }
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
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      URL, NSURLErrorKey,
                                      nil];
            
            *outError = [NSError errorWithDomain: NSPOSIXErrorDomain
                                            code: posixError
                                        userInfo: userInfo];
        }
        return NULL;
    }
}

- (BOOL) removeItemAtURL: (NSURL *)URL error: (NSError **)outError
{
    NSURL *shadowedURL = [self shadowedURLForURL: URL];
    
    if (shadowedURL)
    {
        NSURL *deletionMarkerURL = [shadowedURL URLByAppendingPathExtension: BXShadowedDeletionMarkerExtension];
        
        BOOL originalExists = [URL checkResourceIsReachableAndReturnError: NULL];
        
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
        return [self.manager removeItemAtURL: URL error: outError];
    }
}

- (BOOL) _transferItemAtURL: (NSURL *)fromURL
                      toURL: (NSURL *)toURL
                    copying: (BOOL)copy
                      error: (NSError **)outError
{
    NSURL *shadowedToURL = [self shadowedURLForURL: toURL];
    
    if (shadowedToURL)
    {
        NSURL *shadowedFromURL = [self shadowedURLForURL: fromURL];
        NSURL *fromDeletionMarkerURL = [shadowedFromURL URLByAppendingPathExtension: BXShadowedDeletionMarkerExtension];
        NSURL *toDeletionMarkerURL = [shadowedToURL URLByAppendingPathExtension: BXShadowedDeletionMarkerExtension];
        
        //If the source path has been marked as deleted, then the operation should fail.
        if ([fromDeletionMarkerURL checkResourceIsReachableAndReturnError: NULL])
        {
            //TODO: populate outError
            return NO;
        }
        
        //Ensure the destination folder exists.
        BOOL destinationIsDir;
        if (!([self fileExistsAtURL: toURL.URLByDeletingLastPathComponent
                        isDirectory: &destinationIsDir] && destinationIsDir))
        {
            //TODO: populate outError
            return NO;
        }
        
        //Ensure that a suitable folder structure exists in the shadow volume
        //to accommodate the destination.
        [self.manager createDirectoryAtURL: shadowedToURL.URLByDeletingLastPathComponent
               withIntermediateDirectories: YES
                                attributes: nil
                                     error: NULL];
        
        //Remove any shadow of the destination before we begin, since we want to overwrite it.
        [self.manager removeItemAtURL: shadowedToURL error: NULL];
        
        
        //If the source file has a shadow, try using that as the source initially,
        //falling back on the original source if that fails.
        BOOL succeeded = [self.manager copyItemAtURL: shadowedFromURL
                                               toURL: shadowedToURL
                                               error: NULL];
        
        if (!succeeded)
        {
            succeeded = [self.manager copyItemAtURL: fromURL
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
                
                BOOL originalExists = [fromURL checkResourceIsReachableAndReturnError: NULL];
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
        //FIXME: should we really do this? Wouldn't it be more 'authentic'
        //to leave a partially-copied file?
        else
        {
            [self.manager removeItemAtURL: shadowedToURL error: NULL];
            
            return NO;
        }
    }
    else
    {
        return [self.manager moveItemAtURL: fromURL toURL: toURL error: NULL];
    }
}

- (BOOL) moveItemAtURL: (NSURL *)fromURL toURL: (NSURL *)toURL error: (NSError **)outError
{
    return [self _transferItemAtURL: fromURL toURL: toURL copying: NO error: outError];
}

- (BOOL) copyItemAtURL: (NSURL *)fromURL toURL: (NSURL *)toURL error: (NSError **)outError
{
    return [self _transferItemAtURL: fromURL toURL: toURL copying: YES error: outError];
}

- (BOOL) fileExistsAtURL: (NSURL *)URL isDirectory: (BOOL *)isDirectory
{
    NSURL *shadowedURL = [self shadowedURLForURL: URL];
    
    if (shadowedURL)
    {
        NSURL *deletionMarkerURL = [shadowedURL URLByAppendingPathExtension: BXShadowedDeletionMarkerExtension];
        
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
            return [self.manager fileExistsAtPath: URL.path isDirectory: isDirectory];
        }
    }
    else
    {
        return [self.manager fileExistsAtPath: URL.path isDirectory: isDirectory];
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

- (BOOL) createDirectoryAtURL: (NSURL *)URL
  withIntermediateDirectories: (BOOL)createIntermediates
                        error: (NSError **)outError
{
    NSURL *shadowedURL = [self shadowedURLForURL: URL];
    
    if (shadowedURL)
    {
        NSURL *deletionMarkerURL = [shadowedURL URLByAppendingPathExtension: BXShadowedDeletionMarkerExtension];
        
        BOOL originalExists = [URL checkResourceIsReachableAndReturnError: NULL];
        
        //If the original already exists...
        if (originalExists)
        {
            //If the original has been marked as deleted, then remove the marker
            //*but mark all the files inside that directory as deleted*,
            //since the 'new' directory should appear empty.
            if ([deletionMarkerURL checkResourceIsReachableAndReturnError: NULL])
            {
                [self.manager removeItemAtURL: deletionMarkerURL error: NULL];
                
                NSDirectoryEnumerator *enumerator = [self.manager enumeratorAtURL: URL
                                                       includingPropertiesForKeys: [NSArray array]
                                                                          options: NSDirectoryEnumerationSkipsSubdirectoryDescendants
                                                                     errorHandler: nil];
                
                for (NSURL *subURL in enumerator)
                {
                    NSURL *shadowedSubURL = [self shadowedURLForURL: subURL];
                    NSURL *deletionMarkerSubURL = [shadowedSubURL URLByAppendingPathExtension: BXShadowedDeletionMarkerExtension];
                    
                    [self _createDeletionMarkerAtURL: deletionMarkerSubURL];
                }
                return YES;
            }
            //Otherwise, the original still exists in the DOS filesystem and the attempt
            //to create a new directory at the same location should fail.
            else
            {
                //TODO: populate outError.
                return NO;
            }
        }
        //Otherwise, create a new shadow directory.
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
        return [self.manager createDirectoryAtURL: URL
                      withIntermediateDirectories: NO
                                       attributes: nil
                                            error: NULL];
    }
}


#pragma mark -
#pragma mark Housekeeping

- (BOOL) tidyShadowContentsForURL: (NSURL *)baseURL error: (NSError **)outError
{
    NSURL *baseShadowURL = [self shadowedURLForURL: baseURL];
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
            if ([shadowedURL.pathExtension isEqualToString: BXShadowedDeletionMarkerExtension])
            {
                NSURL *sourceURL = [self sourceURLForURL: shadowedURL];
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
            NSURL *sourceDirectoryURL = [self sourceURLForURL: shadowDirectoryURL];
            
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

- (BOOL) clearShadowContentsForURL: (NSURL *)baseURL error: (NSError **)outError
{
    NSURL *baseShadowURL = [self shadowedURLForURL: baseURL];
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
    if ([shadowedURL.pathExtension isEqualToString: BXShadowedDeletionMarkerExtension])
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

- (BOOL) mergeShadowContentsForURL: (NSURL *)baseURL error: (NSError **)outError
{
    NSURL *baseShadowedURL = [self shadowedURLForURL: baseURL];
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
                NSURL *sourceURL = [self sourceURLForURL: shadowedURL];
                BOOL merged = [self _mergeItemAtShadowURL: shadowedURL toSourceURL: sourceURL error: outError];
                
                if (!merged)
                    return NO;
            }
        }
        //Otherwise, merge the base URL as a single file.
        else
        {
            BOOL merged = [self _mergeItemAtShadowURL: baseShadowedURL toSourceURL: baseURL error: outError];
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




@interface BXShadowedDirectoryEnumerator ()

@property (copy, nonatomic) NSURL *sourceURL;
@property (copy, nonatomic) NSURL *shadowURL;
@property (retain, nonatomic) NSDirectoryEnumerator *sourceEnumerator;
@property (retain, nonatomic) NSDirectoryEnumerator *shadowEnumerator;
@property (assign, nonatomic) NSDirectoryEnumerator *currentEnumerator;
@property (retain, nonatomic) NSMutableSet *shadowedPaths;
@property (retain, nonatomic) NSMutableSet *deletedPaths;


@property (retain, nonatomic) BXShadowedFilesystem *filesystem;
@property (retain, nonatomic) NSArray *propertyKeys;
@property (assign, nonatomic) NSDirectoryEnumerationOptions options;
@property (copy, nonatomic) BXDirectoryEnumeratorErrorHandler errorHandler;

- (NSURL *) _nextURLFromSource;
- (NSURL *) _nextURLFromShadow;

@end

@implementation BXShadowedDirectoryEnumerator
@synthesize sourceURL = _sourceURL;
@synthesize shadowURL = _shadowURL;
@synthesize sourceEnumerator = _sourceEnumerator;
@synthesize shadowEnumerator = _shadowEnumerator;
@synthesize currentEnumerator = _currentEnumerator;
@synthesize shadowedPaths = _shadowedPaths;
@synthesize deletedPaths = _deletedPaths;
@synthesize filesystem = _filesystem;

@synthesize propertyKeys = _propertyKeys;
@synthesize options = _options;
@synthesize errorHandler = _errorHandler;

- (id) initWithFilesystem: (BXShadowedFilesystem *)filesystem
                sourceURL: (NSURL *)sourceURL
                shadowURL: (NSURL *)shadowURL
includingPropertiesForKeys: (NSArray *)keys
                  options: (NSDirectoryEnumerationOptions)mask
             errorHandler: (BXDirectoryEnumeratorErrorHandler)errorHandler
{
    self = [self init];
    if (self)
    {
        NSAssert(sourceURL != nil, @"Source URL cannot be nil.");
        
        self.filesystem = filesystem;
        self.sourceURL = sourceURL;
        self.shadowURL = shadowURL;
        self.propertyKeys = keys;
        self.options = mask;
        self.errorHandler = errorHandler;
        
        [self reset];
    }
    return self;
}

- (void) dealloc
{
    self.sourceURL = nil;
    self.shadowURL = nil;
    self.sourceEnumerator = nil;
    self.shadowEnumerator = nil;
    self.currentEnumerator = nil;
    self.shadowedPaths = nil;
    self.deletedPaths = nil;
    
    self.propertyKeys = nil;
    self.errorHandler = nil;
    self.filesystem = nil;
    
    [super dealloc];
}

- (void) skipDescendants
{
    [self.currentEnumerator skipDescendants];
}

- (NSDictionary *) fileAttributes
{
    return self.currentEnumerator.fileAttributes;
}

- (NSUInteger) level
{
    return self.currentEnumerator.level;
}

- (NSDictionary *) directoryAttributes
{
    if (self.shadowEnumerator)
        return self.shadowEnumerator.directoryAttributes;
    else
        return self.sourceEnumerator.directoryAttributes;
}


- (void) reset
{
    NSFileManager *manager = [NSFileManager defaultManager];
    self.sourceEnumerator = [manager enumeratorAtURL: self.sourceURL
                          includingPropertiesForKeys: self.propertyKeys
                                             options: self.options
                                        errorHandler: self.errorHandler];
    
    if (self.shadowURL)
    {
        self.shadowEnumerator = [manager enumeratorAtURL: self.shadowURL
                              includingPropertiesForKeys: self.propertyKeys
                                                 options: self.options
                                            errorHandler: self.errorHandler];
        
        self.currentEnumerator = self.shadowEnumerator;
        self.shadowedPaths = [NSMutableSet set];
        self.deletedPaths = [NSMutableSet set];
    }
    else
    {
        self.shadowEnumerator = nil;
        self.currentEnumerator = self.sourceEnumerator;
        self.shadowedPaths = nil;
        self.deletedPaths = nil;
    }
}

- (NSURL *) nextObject
{
    BOOL isEnumeratingShadow = (self.currentEnumerator == self.shadowEnumerator);
    
    //We start off enumerating the shadow folder if one is available, as its state will
    //override the state of the source folder. Along the way we mark which files have been
    //shadowed or deleted, so that we can skip those when enumerating the source folder.
    if (isEnumeratingShadow)
    {
        NSURL *nextURL = [self _nextURLFromShadow];
        if (!nextURL)
        {
            self.currentEnumerator = self.sourceEnumerator;
            return [self _nextURLFromSource];
        }
        else
        {
            return nextURL;
        }
    }
    else
    {
        return [self _nextURLFromSource];
    }
}

- (NSURL *) _nextURLFromSource
{
    NSURL *nextURL;
    while ((nextURL = [self.sourceEnumerator nextObject]) != nil)
    {
        NSString *relativePath = [nextURL pathRelativeToURL: self.sourceURL];
        
        //If this path was marked as deleted in the shadow, ignore it
        //and skip any descendants if it was a directory.
        if ([self.deletedPaths containsObject: relativePath])
        {
            [self skipDescendants];
            continue;
        }
        
        //If this path was already enumerated by the shadow, ignore it.
        if ([self.shadowedPaths containsObject: relativePath]) continue;
        
        return nextURL;
    }
    
    return nil;
}

- (NSURL *) _nextURLFromShadow
{
    NSURL *nextURL;
    while ((nextURL = [self.shadowEnumerator nextObject]) != nil)
    {
        NSString *relativePath = [nextURL pathRelativeToURL: self.shadowURL];
        
        //Skip over shadow deletion markers, but mark the filename so that we'll also skip
        //the 'deleted' version when enumerating the original source location.
        if ([relativePath.pathExtension isEqualToString: BXShadowedDeletionMarkerExtension])
        {
            [self.deletedPaths addObject: relativePath.stringByDeletingPathExtension];
            continue;
        }
        
        //Mark shadowed files so that we'll skip them when enumerating the soruce folder.
        [self.shadowedPaths addObject: relativePath];
        
        return nextURL;
    }
    
    return nil;
}

- (const char *) fileSystemRepresentationForURL: (NSURL *)URL
{
    return [self.filesystem fileSystemRepresentationForURL: URL];
}

@end