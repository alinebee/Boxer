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

typedef BOOL (^ADBDirectoryEnumeratorErrorHandler)(NSURL *url, NSError *error);


@protocol ADBFilesystemEnumerator;
@protocol ADBFilesystem <NSObject>

//Resolves a URL to/from a filesystem representation.
- (const char *) fileSystemRepresentationForURL: (NSURL *)URL;
- (NSURL *) URLFromFileSystemRepresentation: (const char *)representation;

//Returns an enumerator for the specified URL, that will return NSURL objects.
//This enumerator should respect the same parameters as NSFileManager's
//enumeratorAtURL:includingPropertiesForKeys:options:errorHandler: method.
- (id <ADBFilesystemEnumerator>) enumeratorAtURL: (NSURL *)URL
                      includingPropertiesForKeys: (NSArray *)keys
                                         options: (NSDirectoryEnumerationOptions)mask
                                    errorHandler: (ADBDirectoryEnumeratorErrorHandler)errorHandler;


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
@protocol ADBFilesystemEnumerator <NSObject, NSFastEnumeration>

- (void) skipDescendants;
- (NSUInteger) level;

- (NSURL *) nextObject;

@optional

//Returns the filesystem representation of the specified URL, or NULL if this is not applicable.
- (const char *) fileSystemRepresentationForURL: (NSURL *)URL;

//Reset the enumerator back to the first entry.
- (void) reset;

@end