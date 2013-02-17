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

#import <Foundation/Foundation.h>
#import "ADBFilesystem.h"

//ADBShadowedFilesystem mediates access to filesystem resources that are
//write-shadowed to another location. Files are initially read from a source
//path, but writes and deletions are applied to a separate shadowed path
//which is then used in future for reads and writes of that file.

//The file extension that will be used for flagging source files as deleted.
extern NSString * const ADBShadowedDeletionMarkerExtension;

         
@class ADBShadowedDirectoryEnumerator;
@interface ADBShadowedFilesystem : NSObject <ADBFilesystem, ADBFilesystemPOSIXAccess>
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
+ (id) filesystemWithSourceURL: (NSURL *)sourceURL shadowURL: (NSURL *)shadowURL;
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

//The inverse of the above: converts a shadowed URL to the equivalent source URL
//(which also may not exist yet.)
- (NSURL *) sourceURLForURL: (NSURL *)URL;


#pragma mark -
#pragma mark Enumerating the filesystem

//Returns an enumerator for the specified URL.
- (ADBShadowedDirectoryEnumerator *) enumeratorAtURL: (NSURL *)URL
                         includingPropertiesForKeys: (NSArray *)keys
                                            options: (NSDirectoryEnumerationOptions)mask
                                       errorHandler: (ADBFilesystemEnumeratorErrorHandler)errorHandler;


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


#pragma mark -
#pragma mark Housekeeping

//Cleans up the shadow contents for the specified URL: this removes any redundant
//deletion markers for files that don't exist in the source location, and any empty
//folders that already exist in the source location.
//FIXME: currently this assumes the source is a folder.
- (BOOL) tidyShadowContentsForURL: (NSURL *)baseURL error: (NSError **)outError;

//Removes the shadowed version for the specified URL, and its contents
//if it is a directory.
- (BOOL) clearShadowContentsForURL: (NSURL *)baseURL error: (NSError **)outError;

//Merge any shadowed changes for the specified URL and its subdirectories
//back into the original source location, and deletes the merged shadow files.
//Returns YES if the merge was successful, or NO and populates outError
//if one or more files or folders could not be merged. (The merge operation
//will be halted as soon as an error is encountered, leaving behind any
//unmerged files in the shadow location.)
- (BOOL) mergeShadowContentsForURL: (NSURL *)baseURL error: (NSError **)outError;

@end


//A directory enumerator returned by ADBShadowedFilesystem's enumeratorAtURL: method.
//Analoguous to NSDirectoryEnumerator, except that it folds together the original and shadowed
//filesystems into a single filesystem. Any files and directories marked as deleted will be skipped.
//Note that this will return shadowed files first followed by untouched original files, rather
//than the straight depth-first traversal performed by NSDirectoryEnumerator.
@interface ADBShadowedDirectoryEnumerator : NSEnumerator <ADBFilesystemEnumerator>
{
    NSDirectoryEnumerator *_sourceEnumerator;
    NSDirectoryEnumerator *_shadowEnumerator;
    __unsafe_unretained NSDirectoryEnumerator *_currentEnumerator;
    
    NSArray *_propertyKeys;
    NSDirectoryEnumerationOptions _options;
    ADBFilesystemEnumeratorErrorHandler _errorHandler;
    BOOL _includeDotEntries;
    
    NSURL *_sourceURL;
    NSURL *_shadowURL;
    
    NSMutableSet *_shadowedPaths;
    NSMutableSet *_deletedPaths;
    
    ADBShadowedFilesystem *_filesystem;
}

- (id) initWithFilesystem: (ADBShadowedFilesystem *)filesystem
                sourceURL: (NSURL *)sourceURL
                shadowURL: (NSURL *)shadowURL
includingPropertiesForKeys: (NSArray *)keys
                  options: (NSDirectoryEnumerationOptions)mask
             errorHandler: (ADBFilesystemEnumeratorErrorHandler)errorHandler;

- (NSUInteger) level;
- (void) skipDescendants;

//Reset the enumerator back to the first entry.
- (void) reset;

@end
