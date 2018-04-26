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

/// The ADBAliasHelpers category extends NSURL with methods to simplify working with legacy
/// alias records from OS X 10.5 and below and converting them to modern 10.6 bookmarks.
@interface NSURL (ADBAliasHelpers)

/// Returns 10.6 bookmark data converted from the specified Finder alias record.
/// Returns @c nil and populates @c outError if conversion failed.
+ (NSData *) bookmarkDataFromAliasRecord: (NSData *)aliasRecord
                                   error: (out NSError **)outError;

/// Returns a URL resolved from the specified Finder alias record.
/// Directly equivalent to <code>URLByResolvingBookmarkData:options:relativeToURL:bookmarkDataIsStale:error:</code>.
+ (instancetype)URLByResolvingAliasRecord: (NSData *)aliasRecord
                                  options: (NSURLBookmarkResolutionOptions)options
                            relativeToURL: (NSURL *)relativeURL
                      bookmarkDataIsStale: (out BOOL *)isStale
                                    error: (out NSError **)outError;

@end
