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
@interface ADBShadowedFilesystem : NSObject <ADBFilesystemPathAccess, ADBFilesystemLocalFileURLAccess>
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
#pragma mark Housekeeping

//Cleans up the shadow contents for the specified filesystem-relative path: this removes
//any redundant deletion markers for files that don't exist in the source location,
//and any empty folders that already exist in the source location.
//FIXME: currently this assumes the source is a folder.
- (BOOL) tidyShadowContentsForPath: (NSString *)path error: (out NSError **)outError;

//Removes the shadowed version for the specified path, and its subpaths if it is a directory.
- (BOOL) clearShadowContentsForPath: (NSString *)path error: (out NSError **)outError;

//Merge any shadowed changes for the specified path and its subdirectories
//back into the original source location, and deletes the merged shadow files.
//Returns YES if the merge was successful, or NO and populates outError
//if one or more files or folders could not be merged.
//The merge operation will be halted as soon as an error is encountered,
//leaving behind any unmerged files in the shadow location.
- (BOOL) mergeShadowContentsForPath: (NSString *)path error: (out NSError **)outError;

@end
