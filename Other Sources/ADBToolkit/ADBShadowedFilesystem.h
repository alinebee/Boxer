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
#import "ADBLocalFilesystem.h"

NS_ASSUME_NONNULL_BEGIN

//ADBShadowedFilesystem mediates access to filesystem resources that are
//write-shadowed to another location. Files are initially read from a source
//path, but writes and deletions are applied to a separate shadowed path
//which is then used in future for reads and writes of that file.

/// The file extension that will be used for flagging source files as deleted.
extern NSString * const ADBShadowedDeletionMarkerExtension;

         
@class ADBShadowedDirectoryEnumerator;
@interface ADBShadowedFilesystem : ADBLocalFilesystem
{
    NSURL *_shadowURL;
}

#pragma mark -
#pragma mark Properties

/// The location to which shadows will be committed.
/// The contents of this location can be mapped directly onto the source location.
@property (readonly, copy, nonatomic) NSURL *shadowURL;


#pragma mark - Constructors

/// Return a new filesystem manager rooted in the specified base URL but using
/// the specified shadow URL to store shadowed files and deletion markers.
+ (instancetype) filesystemWithBaseURL: (NSURL *)baseURL shadowURL: (NSURL *)shadowURL;
- (instancetype) initWithBaseURL: (NSURL *)baseURL shadowURL: (NSURL *)shadowURL;


#pragma mark - Housekeeping

/// Cleans up the shadow contents for the specified filesystem-relative path: this removes
/// any redundant deletion markers for files that don't exist in the source location,
/// and any empty folders that already exist in the source location.
/// FIXME: currently this assumes the source is a folder.
- (BOOL) tidyShadowContentsForPath: (NSString *)path error: (out NSError **)outError;

/// Removes the shadowed version for the specified path, and its subpaths if it is a directory.
- (BOOL) clearShadowContentsForPath: (NSString *)path error: (out NSError **)outError;

/// Merge any shadowed changes for the specified path and its subdirectories
/// back into the original source location, and deletes the merged shadow files.
/// Returns \c YES if the merge was successful, or \c NO and populates \c outError
/// if one or more files or folders could not be merged.<br>
/// The merge operation will be halted as soon as an error is encountered,
/// leaving behind any unmerged files in the shadow location.
- (BOOL) mergeShadowContentsForPath: (NSString *)path error: (out NSError **)outError;

@end

NS_ASSUME_NONNULL_END
