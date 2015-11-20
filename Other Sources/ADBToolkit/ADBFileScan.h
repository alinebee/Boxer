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


//ADBFileScan is an ADBOperation subclass for performing asynchronous filesystem
//scans for files matching certain criteria, populating the operation's matchingPaths
//property with them.

#import "ADBOperation.h"
#import <AppKit/AppKit.h>

#pragma mark -
#pragma mark Constants

//Included in in-progress notification dictionary to mark the last matching path found.
extern NSString * const ADBFileScanLastMatchKey;


#pragma mark -
#pragma mark Interface declaration

@interface ADBFileScan : ADBOperation
{
	NSString *_basePath;
    
    NSMutableArray *_matchingPaths;
    NSUInteger _maxMatches;
    
    BOOL _skipHiddenFiles;
	BOOL _skipSubdirectories;
	BOOL _skipPackageContents;
	NSSet *_fileTypes;
    NSPredicate *_predicate;
    
	NSFileManager *_manager;
	NSWorkspace *_workspace;
}

#pragma mark -
#pragma mark Properties

//The base filesystem path whose files and subfolders Boxer will scan.
//Should not be modified while the scan is in progress.
@property (copy, nonatomic) NSString *basePath;

//The array of matched files, which will be gradually populated throughout the scan.
//File paths are relative to basePath; a set of absolute paths can be retrieved by
//performing [[scan basePath] stringsByAppendingPaths: [scan matchingPaths]].
@property (readonly, nonatomic) NSArray<NSString*> *matchingPaths;

//Optional: the maximum number of matches to return. Defaults to 0, which means no limit.
@property (assign, nonatomic) NSUInteger maxMatches;

//The last path that was matched by the scan.
@property (readonly, nonatomic) NSString *lastMatch;


//Optional: only files whose paths (relative to basePath) match the specified predicate will be returned.
@property (copy, nonatomic) NSPredicate *predicate;

//Optional: only files which match the specified UTI filetypes will be returned.
@property (copy, nonatomic) NSSet *fileTypes;

//Whether the scan should ignore hidden files. Is YES by default.
@property (assign, nonatomic) BOOL skipHiddenFiles;

//Whether the scan should only enumerate the base path, skipping all subdirectories.
//Is NO by default.
@property (assign, nonatomic) BOOL skipSubdirectories;

//Whether the scan should skip over files located in packages.
//The packages themselves will still be returned, if they match the search criteria.
//Is NO by default.
@property (assign, nonatomic) BOOL skipPackageContents;


#pragma mark -
#pragma mark Methods

//Returns an autoreleased file scan operation with the specified base path.
+ (id) scanWithBasePath: (NSString *)basePath;

//Returns a new autoreleased instance of the enumerator to scan with.
//By default this returns an NSDirectoryEnumerator instance configured
//to scan basePath, but can be overridden by subclasses to scan a different
//path than the base.
//TODO: reimplement to use the ADBFilesystemEnumerator protocol.
- (NSDirectoryEnumerator *) enumerator;


//Returns whether the contents of the specified subpath (relative to basePath)
//should be scanned.
//Returns NO if skipSubdirectories is enabled, or if skipPackageContents is enabled
//and the path represents a file package. Can be overridden by subclasses to perform
//custom subfolder filtering.
- (BOOL) shouldScanSubpath: (NSString *)relativePath;

//Called for every file found during the scan. By default, this checks the file with
//isMatchingPath:. If the file matches, it calls addMatchingPath: and posts an
//in-progress notification with the match as the ADBFileScanLastMatchKey entry.

//Returns whether the scan should continue after this match. The default implementation
//will return NO if maxMatches is set and enough matches have been found, YES otherwise.

//This is intended as a customisation point for subclasses to implement more advanced
//match handling that can't be handled by isMatchingPath: and addMatchingPath:.
- (BOOL) matchAgainstPath: (NSString *)relativePath;


//Returns whether the specified file path (relative to basePath) matches
//our search criteria.
//Returns YES if filePath matches fileTypes and predicate, NO otherwise.
//Can be overridden by subclasses to implement custom filtering.
- (BOOL) isMatchingPath: (NSString *)relativePath;

//Adds the specified path (relative to basePath) into the set of matched paths.
//Called whenever a match is found. Can be overridden by subclasses to perform
//custom logic, such as rewriting the path or adding it to additional collections.
- (void) addMatchingPath: (NSString *)relativePath;

//Returns the full filesystem path for the specified relative path.
//Intended as a convenience function for internal checks: all file paths returned
//by the scan should still be expressed as relative to the base path.
//The default implementation resolves the path relative to basePath,
//but this can be overridden by subclasses if needed.
- (NSString *) fullPathFromRelativePath: (NSString *)relativePath;

@end