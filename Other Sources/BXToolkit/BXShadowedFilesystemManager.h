//
//  BXShadowedFilesystemManager.h
//  Boxer
//
//  Created by Alun Bestor on 24/07/2012.
//  Copyright (c) 2012 Alun Bestor and contributors. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BXFilesystemManager.h"

//BXShadowedFilesystemManager mediates access to filesystem resources that
//are write-shadowed to another location. Files are initially read from a source
//path, but writes and deletions are applied to a separate shadowed path which
//is then used in future for reads and writes of that file.

//The file extension that will be used for flagging source files as deleted.
extern NSString * const BXShadowedDeletionMarkerExtension;

         
@class BXShadowedDirectoryEnumerator;
@interface BXShadowedFilesystemManager : NSObject <BXFilesystemManager>
{
    NSURL *_sourceURL;
    NSURL *_shadowURL;
    NSFileManager *_manager;
}

#pragma mark -
#pragma mark Properties

//The base source location for this filesystem.
@property (copy, nonatomic) NSURL *sourceURL;

//The location to which shadows will be committed.
//The contents of this location can be mapped directly onto the source location.
@property (copy, nonatomic) NSURL *shadowURL;


#pragma mark -
#pragma mark Initialization and deallocation
//Return a new filesystem manager initialised with the specified source and shadow URLs.
+ (id) managerWithSourceURL: (NSURL *)sourceURL shadowURL: (NSURL *)shadowURL;
- (id) initWithSourceURL: (NSURL *)sourceURL shadowURL: (NSURL *)shadowURL;


#pragma mark -
#pragma mark Resolving URLs

//If the item at the specified URL is shadowed, returns the location of the shadow;
//if not, and the item at the specified URL exists, returns the original URL.
//Returns nil if the URL does not exist or has been marked as deleted.
- (NSURL *) canonicalFilesystemURL: (NSURL *)URL;

//The shadow URL corresponding to the specified URL, which may not exist yet.
//This will return nil if URL is not located within the source URL.
- (NSURL *) shadowedURLForURL: (NSURL *)URL;


#pragma mark -
#pragma mark Enumerating the filesystem

//Returns an enumerator for the specified URL.
- (BXShadowedDirectoryEnumerator *) enumeratorAtURL: (NSURL *)URL
                         includingPropertiesForKeys: (NSArray *)keys
                                            options: (NSDirectoryEnumerationOptions)mask
                                       errorHandler: (BXDirectoryEnumeratorErrorHandler)errorHandler;


#pragma mark -
#pragma mark Creating, deleting and accessing files.

//Returns an open file handle for the resource represented by the specified URL,
//using the specified access mode (in the standard fopen format).
//Returns nil and populates outError if the URL did not exist or has been marked
//as deleted and the accessMode is not one that can create a file if it is missing.
- (FILE *) openFileAtURL: (NSURL *)URL
                  inMode: (const char *)accessMode
                   error: (NSError **)outError;

//Deletes a shadowed version of the specified URL if present, and marks the original
//file as having been deleted.
//Returns YES if the operation was successful, or NO and populates outError if the
//file did not exist or is marked as deleted.
- (BOOL) removeItemAtURL: (NSURL *)URL error: (NSError **)outError;

//Copy/move an item from the specified source URL to the specified destination.
//Returns YES if the operation was successful, or NO and populates outError otherwise.
- (BOOL) copyItemAtURL: (NSURL *)fromURL toURL: (NSURL *)toURL error: (NSError **)outError;
- (BOOL) moveItemAtURL: (NSURL *)fromURL toURL: (NSURL *)toURL error: (NSError **)outError;

//Returns whether the item at the specified URL exists and is not marked as deleted.
//If isDirectory is provided, this will be populated with YES if the URL represents a directory or NO otherwise.
- (BOOL) fileExistsAtURL: (NSURL *)URL isDirectory: (BOOL *)isDirectory;

//Creates a new directory at the specified URL, optionally creating any missing directories in-between.
//Returns YES if the directory or directories were created, or NO if a directory or file already exists
//at that URL; or if one of the intermediate directories was absent and createIntermediates was NO.
- (BOOL) createDirectoryAtURL: (NSURL *)URL
  withIntermediateDirectories: (BOOL)createIntermediates
                        error: (NSError **)outError;

@end


//A directory enumerator returned by BXShadowFileManager's enumeratorAtURL: method.
//Analoguous to NSDirectoryEnumerator, except that it folds together the original and shadowed
//filesystems into a single filesystem. Any files and directories marked as deleted will be skipped.
//Note that this will return shadowed files first followed by untouched original files, rather
//than the straight depth-first traversal performed by NSDirectoryEnumerator.
@interface BXShadowedDirectoryEnumerator : NSEnumerator <BXFilesystemEnumerator>
{
    NSDirectoryEnumerator *_sourceEnumerator;
    NSDirectoryEnumerator *_shadowEnumerator;
    NSDirectoryEnumerator *_currentEnumerator;
    
    NSArray *_propertyKeys;
    NSDirectoryEnumerationOptions _options;
    BXDirectoryEnumeratorErrorHandler _errorHandler;
    BOOL _includeDotEntries;
    
    NSURL *_sourceURL;
    NSURL *_shadowURL;
    
    NSMutableSet *_shadowedURLs;
}

- (id) initWithSourceURL: (NSURL *)sourceURL
               shadowURL: (NSURL *)shadowURL
includingPropertiesForKeys: (NSArray *)keys
                 options: (NSDirectoryEnumerationOptions)mask
            errorHandler: (BXDirectoryEnumeratorErrorHandler)errorHandler;

- (NSDictionary *) directoryAttributes;
- (NSDictionary *) fileAttributes;

- (NSUInteger) level;
- (void) skipDescendants;
- (void) reset;

@end
