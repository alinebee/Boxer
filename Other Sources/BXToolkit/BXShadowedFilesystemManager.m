//
//  BXShadowedFilesystemManager.m
//  Boxer
//
//  Created by Alun Bestor on 24/07/2012.
//  Copyright (c) 2012 Alun Bestor and contributors. All rights reserved.
//

#import "BXShadowedFilesystemManager.h"
#import "NSString+BXPaths.h"

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

@interface BXShadowedFilesystemManager ()

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

@end


#pragma mark -
#pragma mark Implementation

@implementation BXShadowedFilesystemManager
@synthesize sourceURL = _sourceURL;
@synthesize shadowURL = _shadowURL;
@synthesize manager = _manager;


#pragma mark -
#pragma mark Initialization and deallocation

+ (id) managerWithSourceURL:(NSURL *)sourceURL shadowURL:(NSURL *)shadowURL
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


#pragma mark -
#pragma mark Path translation

- (NSURL *) shadowedURLForURL: (NSURL *)URL
{
    //If we don't have a shadow, or the specified URL isn't located within
    //our source URL, there is no shadow URL that would be applicable.
    if (!self.shadowURL || ![URL.path isRootedInPath: self.sourceURL.path])
        return nil;
    
    NSString *relativePath = [URL.path pathRelativeToPath: self.sourceURL.path];
    
    return [NSURL URLWithString: relativePath
                  relativeToURL: self.shadowURL];
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

- (const char *) filesystemRepresentationForURL: (NSURL *)URL
{
    return URL.path.fileSystemRepresentation;
}

- (NSURL *) URLFromFilesystemRepresentation: (const char *)representation
{
    NSString *path = [self.manager stringWithFileSystemRepresentation: representation
                                                               length: strlen(representation)];
    
    return [NSURL fileURLWithPath: path];
}

#pragma mark -
#pragma mark Enumeration

- (BXShadowedDirectoryEnumerator *) enumeratorAtURL: (NSURL *)URL
                         includingPropertiesForKeys: (NSArray *)keys
                                            options: (NSDirectoryEnumerationOptions)mask
                                       errorHandler: (BXDirectoryEnumeratorErrorHandler)errorHandler
{
    NSURL *shadowedURL = [self shadowedURLForURL: URL];
    
    return [[[BXShadowedDirectoryEnumerator alloc] initWithSourceURL: URL
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
        
        BOOL deletionMarkerExists = [deletionMarkerURL checkResourceIsReachableAndReturnError: NULL];
        BOOL shadowExists = [shadowedURL checkResourceIsReachableAndReturnError: NULL];
        
        //If the file has been marked as deleted in the shadow...
        if (deletionMarkerExists)
        {
            //...but we are able to create a new file anyway, then remove both the deletion marker
            //and any leftover shadow, and open a new file handle at the shadowed location.
            if ((accessOptions & BXFileCreateIfMissing))
            {
                [self.manager removeItemAtURL: deletionMarkerURL error: nil];
                if (shadowExists)
                    [self.manager removeItemAtURL: shadowedURL error: nil];
                
                return fopen(shadowedURL.path.fileSystemRepresentation, accessMode);
            }
            //Otherwise, pretend we can't open the file at all.
            else
            {
                //TODO: populate outError
                return NULL;
            }
        }
        
        //If the shadow file exists or we're truncating the file to 0 bytes anyway,
        //open a handle directly at the shadowed location.
        else if (shadowExists || (accessOptions & BXFileTruncate))
        {
            return fopen(shadowedURL.path.fileSystemRepresentation, accessMode);
        }
        
        //If we're opening the file for writing and we don't have a shadowed version of it yet,
        //copy the original file to the shadowed location first (creating any necessary directories
        //along the way) and open the newly-shadowed copy.
        //This will fail if the original file does not exist.
        else if ((accessOptions & BXFileOpenForWriting))
        {
            BOOL originalExists = [URL checkResourceIsReachableAndReturnError: NULL];
            if (originalExists)
            {
                [self.manager createDirectoryAtURL: shadowedURL.URLByDeletingLastPathComponent
                       withIntermediateDirectories: YES
                                        attributes: nil
                                             error: NULL];
                
                [self.manager copyItemAtURL: URL toURL: shadowedURL error: NULL];
                
                return fopen(shadowedURL.path.fileSystemRepresentation, accessMode);
            }
            else
            {
                //TODO: populate outError
                return NULL;
            }
        }
        
        //If we don't have a shadow file but we're opening the file as read-only,
        //it's safe to open a handle from the original location. This will return NULL
        //if the original location doesn't exist.
        else
        {
            return fopen(URL.path.fileSystemRepresentation, accessMode);
        }
    }
    else
    {
        return fopen(URL.path.fileSystemRepresentation, accessMode);
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
            //If the copy succeeded, then remove any shadowed source and flag
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

@end




@interface BXShadowedDirectoryEnumerator ()

@property (copy, nonatomic) NSURL *sourceURL;
@property (copy, nonatomic) NSURL *shadowURL;
@property (retain, nonatomic) NSDirectoryEnumerator *sourceEnumerator;
@property (retain, nonatomic) NSDirectoryEnumerator *shadowEnumerator;
@property (assign, nonatomic) NSDirectoryEnumerator *currentEnumerator;
@property (retain, nonatomic) NSMutableSet *shadowedURLs;

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
@synthesize shadowedURLs = _shadowedURLs;

@synthesize propertyKeys = _propertyKeys;
@synthesize options = _options;
@synthesize errorHandler = _errorHandler;

- (id) initWithSourceURL: (NSURL *)sourceURL
               shadowURL: (NSURL *)shadowURL
includingPropertiesForKeys: (NSArray *)keys
                 options: (NSDirectoryEnumerationOptions)mask
            errorHandler: (BXDirectoryEnumeratorErrorHandler)errorHandler
{
    self = [self init];
    if (self)
    {
        NSAssert(sourceURL != nil, @"Source URL cannot be nil.");
        
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
    self.shadowedURLs = nil;
    
    self.propertyKeys = nil;
    self.errorHandler = nil;
    
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
        self.shadowedURLs = [NSMutableSet setWithCapacity: 10];
    }
    else
    {
        self.shadowEnumerator = nil;
        self.currentEnumerator = self.sourceEnumerator;
        self.shadowedURLs = nil;
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
        //If this path was already enumerated by the shadow or was deleted in the shadow, ignore it.
        if ([self.shadowedURLs containsObject: nextURL.relativePath]) continue;
        
        return nextURL;
    }
    
    return nil;
}

- (NSURL *) _nextURLFromShadow
{
    NSURL *nextURL;
    while ((nextURL = [self.shadowEnumerator nextObject]) != nil)
    {
        //Skip over shadow deletion markers, but mark the filename so that we'll also skip
        //the 'deleted' version when enumerating the original source location.
        if ([nextURL.pathExtension isEqualToString: BXShadowedDeletionMarkerExtension])
        {
            [self.shadowedURLs addObject: nextURL.URLByDeletingPathExtension.relativePath];
            continue;
        }
        
        //Mark shadowed files so that we'll skip them when enumerating the soruce folder.
        [self.shadowedURLs addObject: nextURL.relativePath];
        return nextURL;
    }
    
    return nil;
}

- (const char *) filesystemRepresentationForURL: (NSURL *)URL
{
    return URL.path.fileSystemRepresentation;
}

@end