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
#import "ADBFileHandle.h"

typedef BOOL (^ADBFilesystemPathErrorHandler)(NSString *path, NSError *error);
typedef BOOL (^ADBFilesystemLocalFileURLErrorHandler)(NSURL *url, NSError *error);


#pragma mark Relative path-based filesystem access

//These methods are expected take absolute but filesystem-relative paths: that is, paths
//relative to the root of the represented logical filesystem, instead of referring to anywhere
//in the actual OS X filesystem.
//REQUIREMENTS:
//- the path @"/" should be treated as the root of the filesystem.
//- relative paths like @"path/to/file.txt" should be resolved relative to the root of the filesystem.

@protocol ADBFilesystemPathEnumeration;
@protocol ADBFilesystemPathAccess <NSObject>

- (id <ADBFilesystemPathEnumeration>) enumeratorAtPath: (NSString *)path
                                               options: (NSDirectoryEnumerationOptions)mask
                                          errorHandler: (ADBFilesystemPathErrorHandler)errorHandler;

//Returns whether the item at the specified URL exists.
//If isDirectory is provided, this will be populated with YES if the URL represents a directory
//or NO otherwise.
- (BOOL) fileExistsAtPath: (NSString *)path isDirectory: (BOOL *)isDirectory;

//Return the UTI of the file at the specified path, or nil if this could not be determined.
- (NSString *) typeOfFileAtPath: (NSString *)path;

//Given a set of UTIs to test, returns the first one of those types to which the file conforms.
- (NSString *) typeOfFileAtPath: (NSString *)path matchingTypes: (NSSet *)UTIs;

//Return whether the file at the specified path conforms to the specified type.
- (BOOL) fileAtPath: (NSString *)path conformsToType: (NSString *)UTI;

//Returns an NSFileManager-like dictionary of the filesystem attributes of the file
//at the specified path. Returns nil and populates outError if the file cannot be accessed.
- (NSDictionary *) attributesOfFileAtPath: (NSString *)path
                                    error: (out NSError **)outError;

//Returns the raw byte data of the file at the specified path.
//Returns nil and populates outError if the file's contents could not be read.
- (NSData *) contentsOfFileAtPath: (NSString *)path
                            error: (out NSError **)outError;


#pragma mark - Modifying files and folders

//Deletes the file or directory at the specified path.
//Returns YES if the operation was successful, or NO and populates outError on failure.
- (BOOL) removeItemAtPath: (NSString *)path error: (out NSError **)outError;

//Copy/move an item from the specified source path to the specified destination.
//Returns YES if the operation was successful, or NO and populates outError on failure.
- (BOOL) copyItemAtPath: (NSString *)fromPath toPath: (NSString *)toPath error: (out NSError **)outError;
- (BOOL) moveItemAtPath: (NSString *)fromPath toPath: (NSString *)toPath error: (out NSError **)outError;

//Creates a new directory at the specified URL, optionally creating any missing directories in-between.
//Returns YES if the directory or directories were created, or NO on failure.
- (BOOL) createDirectoryAtPath: (NSString *)path
   withIntermediateDirectories: (BOOL)createIntermediates
                         error: (out NSError **)outError;

//Returns a file handle suitable for reading from the resource represented by the specified path,
//using the specified access options.
- (id <ADBFileHandleAccess>) fileHandleAtPath: (NSString *)path
                                      options: (ADBHandleOptions)options
                                        error: (out NSError **)outError;

//Returns an open stdlib FILE handle for the resource represented by the specified path,
//using the specified access mode (in the standard fopen format). The calling context is
//responsible for closing the file handle.
//Returns NULL and populates outError on failure.
- (FILE *) openFileAtPath: (NSString *)path
                   inMode: (const char *)accessMode
                    error: (out NSError **)outError;

@end



#pragma mark Local URL filesystem access

//These methods are expected to take absolute OS X filesystem URLs,
//for filesystems that have some correspondence to real filesystem locations.
//REQUIREMENTS:
//- URLs returned by these methods must be accessible under the standard
//  OS X file access APIs (NSFileManager, NSURL getPropertyValue:forKey:error: et. al.)
//- URLs converted to logical filesystem paths must be absolute, i.e. begin with @"/".

//It is not required that URLs will be identical when 'round-tripped' through these methods.

@protocol ADBFilesystemLocalFileURLEnumeration;
@protocol ADBFilesystemLocalFileURLAccess <ADBFilesystemPathAccess>

//Return the canonical OS X filesystem URL/path that corresponds
//to the specified logical filesystem path.
- (NSURL *) localFileURLForLogicalPath: (NSString *)path;

//Return the logical filesystem path corresponding to the specified OS X filesystem URL/path.
- (NSString *) logicalPathForLocalFileURL: (NSURL *)URL;


//Returns an enumerator for the specified local filesystem URL, which will return NSURL objects
//pointing to resources on the local filesystem.
//This enumerator should respect the same parameters as NSFileManager's
//enumeratorAtURL:includingPropertiesForKeys:options:errorHandler: method.
- (id <ADBFilesystemLocalFileURLEnumeration>) enumeratorAtLocalFileURL: (NSURL *)URL
                                            includingPropertiesForKeys: (NSArray *)keys
                                                               options: (NSDirectoryEnumerationOptions)mask
                                                          errorHandler: (ADBFilesystemLocalFileURLErrorHandler)errorHandler;

@end


//A protocol for NSDirectoryEnumerator-alike objects. See that class for general behaviour.
@protocol ADBFilesystemPathEnumeration <NSObject, NSFastEnumeration>

//The filesystem represented by this enumerator.
- (id <ADBFilesystemPathAccess>) filesystem;

- (NSDictionary *) fileAttributes;

- (void) skipDescendants;
- (NSUInteger) level;

//Returns a filesystem-relative logical path.
//Note that unlike NSDirectoryEnumerator, which returns paths relative to the path being enumerated,
//this should return paths relative *to the root of the logical filesystem*: i.e. paths that can be
//fed straight back into ADBFilesystemPathAccess methods.
- (NSString *) nextObject;

@end

@protocol ADBFilesystemLocalFileURLEnumeration <NSObject, NSFastEnumeration>

//The parent filesystem represented by this enumerator.
- (id <ADBFilesystemLocalFileURLAccess>) filesystem;

- (void) skipDescendants;
- (NSUInteger) level;

//Returns an absolute OS X filesystem URL.
- (NSURL *) nextObject;


@end