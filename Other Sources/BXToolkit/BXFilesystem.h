/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Foundation/Foundation.h>

typedef BOOL (^BXDirectoryEnumeratorErrorHandler)(NSURL *url, NSError *error);


@protocol BXFilesystemEnumerator;
@protocol BXFilesystem <NSObject>

//Resolves a URL to/from a filesystem representation.
- (const char *) fileSystemRepresentationForURL: (NSURL *)URL;
- (NSURL *) URLFromFileSystemRepresentation: (const char *)representation;

//Returns an enumerator for the specified URL, that will return NSURL objects.
//This enumerator should respect the same parameters as NSFileManager's
//enumeratorAtURL:includingPropertiesForKeys:options:errorHandler: method.
- (id <BXFilesystemEnumerator>) enumeratorAtURL: (NSURL *)URL
                     includingPropertiesForKeys: (NSArray *)keys
                                        options: (NSDirectoryEnumerationOptions)mask
                                   errorHandler: (BXDirectoryEnumeratorErrorHandler)errorHandler;


#pragma mark -
#pragma mark Creating, deleting and accessing files.

//Returns an open file handle for the resource represented by the specified URL,
//using the specified access mode (in the standard fopen format).
//Returns nil and populates outError on failure.
- (FILE *) openFileAtURL: (NSURL *)URL
                  inMode: (const char *)accessMode
                   error: (NSError **)outError;

//Deletes the file or directory at the specified URL.
//Returns YES if the operation was successful, or NO and populates outError on failure.
- (BOOL) removeItemAtURL: (NSURL *)URL error: (NSError **)outError;

//Copy/move an item from the specified source URL to the specified destination.
//Returns YES if the operation was successful, or NO and populates outError on failure.
- (BOOL) copyItemAtURL: (NSURL *)fromURL toURL: (NSURL *)toURL error: (NSError **)outError;
- (BOOL) moveItemAtURL: (NSURL *)fromURL toURL: (NSURL *)toURL error: (NSError **)outError;

//Returns whether the item at the specified URL exists.
//If isDirectory is provided, this will be populated with YES if the URL represents a directory
//or NO otherwise.
- (BOOL) fileExistsAtURL: (NSURL *)URL isDirectory: (BOOL *)isDirectory;

//Creates a new directory at the specified URL, optionally creating any missing directories in-between.
//Returns YES if the directory or directories were created, or NO on failure.
- (BOOL) createDirectoryAtURL: (NSURL *)URL
  withIntermediateDirectories: (BOOL)createIntermediates
                        error: (NSError **)outError;

@end


//A protocol for NSDirectoryEnumerator-alike objects. See that class for general behaviour.
@protocol BXFilesystemEnumerator <NSObject, NSFastEnumeration>

- (void) skipDescendants;
- (NSUInteger) level;

- (NSURL *) nextObject;

//Returns the filesystem representation of the specified URL, or NULL if this is not applicable.
- (const char *) fileSystemRepresentationForURL: (NSURL *)URL;

//Reset the enumerator back to the first entry.
- (void) reset;

@end