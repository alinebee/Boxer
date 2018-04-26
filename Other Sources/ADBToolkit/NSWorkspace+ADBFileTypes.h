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


#import <Cocoa/Cocoa.h>

/// The @c ADBFileTypes category extends NSWorkspace's methods for dealing with Uniform Type Identifiers (UTIs).
@interface NSWorkspace (ADBFileTypes)

/// Returns whether the file at the specified path/URL matches any of the specified UTI filetypes:
/// i.e. whether the file's UTI is equal to *or inherits from* any of those types.
- (BOOL) fileAtURL: (NSURL *)URL matchesTypes: (NSSet<NSString*> *)acceptedTypes;
- (BOOL) file: (NSString *)filePath matchesTypes: (NSSet<NSString*> *)acceptedTypes;

/// Returns the nearest ancestor of the specified path/URL that matches any of the specified UTIs,
/// or nil if no ancestor matched. This may return filePath, if the file itself matches the specified types.
- (NSURL *) nearestAncestorOfURL: (NSURL *)URL matchingTypes: (NSSet<NSString*> *)acceptedTypes;
- (NSString *) parentOfFile: (NSString *)filePath matchingTypes: (NSSet<NSString*> *)acceptedTypes;

@end
