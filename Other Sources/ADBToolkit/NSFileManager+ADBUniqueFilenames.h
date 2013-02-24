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

//The ADBUniqueFilenames category adds methods for writing files and folders to unique
//filenames that do not collide with an existing file.

#import <Foundation/Foundation.h>

extern NSString * const ADBDefaultIncrementedFilenameFormat; //Filename (increment).extension

#define ADBLocalizedDefaultIncrementedFilenameFormat NSLocalizedString(ADBDefaultIncrementedFilenameFormat, @"Default filename format for unique auto-incremented filenames. %1$@ is the base name of the filename, %2$@ is the file extension of the filename and %3$lu is the increment.");


@interface NSFileManager (ADBUniqueFilenames)

#pragma mark Helper class methods

//Returns an incremented version of the specified URL using the specified format and increment.
//The format is expected to take the following format specifiers:
//%1$@: the base filename (sans extension)
//%2$@: the file extension
//%3$lu: the increment.
+ (NSURL *) incrementedURL: (NSURL *)URL
                withFormat: (NSString *)filenameFormat
                 increment: (NSUInteger)increment;

#pragma mark File operation methods

//Returns a uniquified version of the specified URL that does not exist at the time the method
//is called. If the original URL does not exist, then it will be returned unchanged;
//otherwise an incremented version of the URL will be returned, using the specified format and
//incremented starting from 2.
//Note that this can introduce race conditions since a file with that URL may be created between
//requesting the URL and actually using the URL.
- (NSURL *) uniqueURLForURL: (NSURL *)URL filenameFormat: (NSString *)filenameFormat;

//Creates a directory with the specified attributes at the specified URL (if no resource already
//exists at that URL) or at a version of that URL incremented with the specified format (if a
//resource already exists at that URL). Returns the URL that was actually created, or nil and
//populates outError if directory creation failed.
- (NSURL *) createDirectoryAtURL: (NSURL *)URL
                  filenameFormat: (NSString *)filenameFormat
                      attributes: (NSDictionary *)attributes
                           error: (out NSError **)outError;

//Copy/move the file at the specified source URL to the specified destination URL (if no resource
//already exists at that URL) or to a version of the destination URL incremented with the specified
//format (if a resource does already exist at that URL). Returns the final destination URL to which
//the source was copied/moved, or nil and populates outError if the copy failed.
- (NSURL *) copyItemAtURL: (NSURL *)sourceURL
                    toURL: (NSURL *)destinationURL
           filenameFormat: (NSString *)filenameFormat
                    error: (out NSError **)outError;

- (NSURL *) moveItemAtURL: (NSURL *)sourceURL
                    toURL: (NSURL *)destinationURL
           filenameFormat: (NSString *)filenameFormat
                    error: (out NSError **)outError;

@end
