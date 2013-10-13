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

/// A base class for 'category-like' classes that copy their own methods onto another class when loaded.
/// This behaves much like a category: except that if the other class already has an implementation
/// of the method being copied, it will not be replaced. (Regular Objective-C categories will collide
/// in that case, issuing a compiler warning and providing undefined behaviour.)
///
/// This system is mostly intended for 'backporting' implementations of methods that have been
/// added in later OS X versions.
@interface ADBFallbackProxyCategory: NSObject

/// Copies the specified instance method from the proxy class onto the target class,
/// if the target class does not already respond to that selector.
/// Typically this is called from the proxy category's @c +load method.
/// @param selector     The selector of the instance method to copy from this class.
/// @param targetClass  The class onto which to add the instance method.
+ (void) addInstanceMethod: (SEL)selector toClass: (Class)targetClass;

@end


@interface NSFileManager (ADBForwardCompatibility)

//Declared in OS X 10.7
- (BOOL) createDirectoryAtURL: (NSURL *)URL
  withIntermediateDirectories: (BOOL)createIntermediates
                   attributes: (NSDictionary *)attributes
                        error: (out NSError **)error;

//Declared in OS X 10.7
- (BOOL) createSymbolicLinkAtURL: (NSURL *)URL
              withDestinationURL: (NSURL *)destURL
                           error: (out NSError **)error;

//Declared in OS X 10.8
- (BOOL) trashItemAtURL: (NSURL *)url
       resultingItemURL: (out NSURL **)outResultingURL
                  error: (out NSError **)error;

@end

@interface NSFileManagerProxyCategory: ADBFallbackProxyCategory
@end


@interface NSURL (ADBForwardCompatibility)

//Declared in OS X 10.9
- (const char *) fileSystemRepresentation;

@end

@interface NSURLProxyCategory: ADBFallbackProxyCategory
@end