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
#import "ADBEnumerationHelpers.h"

typedef BOOL (^ADBFilesystemPathErrorHandler)(NSString *path, NSError *error);
typedef BOOL (^ADBFilesystemLocalFileURLErrorHandler)(NSURL *url, NSError *error);


#pragma mark Relative path-based filesystem access

//This protocol allows filesystems to handle filesystem-relative paths: that is, paths that are
//relative to the root of the represented logical filesystem, instead of referring to anywhere
//in the actual OS X filesystem.
//IMPLEMENTATION REQUIREMENTS:
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

//Returns a file handle suitable for reading from (and, if supported, writing to) the resource represented
//by the specified path using the specified access options.
- (id) fileHandleAtPath: (NSString *)path
                options: (ADBHandleOptions)options
                  error: (out NSError **)outError;

//Return an open stdlib FILE handle for the resource represented by the specified path,
//using the specified access mode (in the standard fopen format). The calling context is
//responsible for closing the file handle.
//Return NULL and populates outError on failure.
- (FILE *) openFileAtPath: (NSString *)path
                   inMode: (const char *)accessMode
                    error: (out NSError **)outError;

@end



#pragma mark Logical URL filesystem access

//This protocol extends the logical path access protocol to allow to handle 'logical URLs':
//file URLs prefixed by the filesystem's base URL and followed by a logical path within the
//filesystem.
//These URLs do not necessarily exist in the real OS X filesystem and may not be usable by
//standard NSURL introspection methods or AppKit loading methods. They are intended mainly
//for storing filesystem-unique paths and simplifying lookups across multiple filesystems.
@protocol ADBFilesystemLogicalURLAccess <NSObject>

//Return the canonical logical URL for the specified filesystem-relative path.
- (NSURL *) logicalURLForPath: (NSString *)path;

//Return the filesystem-relative path for the specified logical URL.
//Return nil if the specified URL is not resolvable within this filesystem.
- (NSString *) pathForLogicalURL: (NSURL *)URL;


//Return whether the specified logical URL is resolvable within this filesystem.
- (BOOL) exposesLogicalURL: (NSURL *)URL;

//Return whether the specified URL represents the filesystem itself: i.e. it is the source
//of the filesystem or equivalent to it in some other way (e.g. the URL represents
//the mounted filesystem location of a disk image that is the source of the filesystem.)
- (BOOL) representsLogicalURL: (NSURL *)URL;

//Mark the specified URL as representing this filesystem, such that the filesystem will
//resolve logical URLs that are located within that URL.
- (void) addRepresentedURL: (NSURL *)URL;

//Remove a URL previously added by addRepresentedURL:.
- (void) removeRepresentedURL: (NSURL *)URL;

//Return all the unique URLs represented by this filesystem (be they added explicitly
//by addRepresentedURL: or implicitly by other properties of the filesystem.)
- (NSSet *) representedURLs;

@end


#pragma mark Local URL filesystem access

//This protocol allows a filesystem to convert its own logical paths to and from real
//OS X filesystem locations. Unlike the logical URL access protocol above, these locations
//must be actually accessible to standard OS X filesystem tools.
//IMPLEMENTATION REQUIREMENTS:
//- URLs returned by these methods must be accessible under the standard OS X file access APIs
//  (NSFileManager, NSURL getPropertyValue:forKey:error: et. al.), though the files themselves
//  may not yet exist.
//- URLs converted to logical filesystem paths must be absolute, i.e. begin with @"/".

//It is not required that URLs will be identical when 'round-tripped' through these methods.

@protocol ADBFilesystemLocalFileURLEnumeration;
@protocol ADBFilesystemLocalFileURLAccess <NSObject>

//Return the canonical OS X filesystem URL that corresponds
//to the specified logical filesystem path.
- (NSURL *) localFileURLForLogicalPath: (NSString *)path;

//Return the logical filesystem path corresponding to the specified OS X filesystem URL.
//Return nil if the specified URL is not accessible within this filesystem.
- (NSString *) logicalPathForLocalFileURL: (NSURL *)URL;

//Whether the specified file URL is accessible under this filesystem.
- (BOOL) exposesLocalFileURL: (NSURL *)URL;


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
@protocol ADBFilesystemPathEnumeration <NSObject, ADBStepwiseEnumeration>

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

@protocol ADBFilesystemLocalFileURLEnumeration <NSObject, ADBStepwiseEnumeration>

//The parent filesystem represented by this enumerator.
- (id <ADBFilesystemLocalFileURLAccess>) filesystem;

- (void) skipDescendants;
- (NSUInteger) level;

//Returns an absolute OS X filesystem URL.
- (NSURL *) nextObject;


@end