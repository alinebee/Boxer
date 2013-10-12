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

//This library contains backported implementations for APIs and constants that are not available
//in earlier versions of Cocoa.

#import <Cocoa/Cocoa.h>

#pragma mark -
#pragma mark Runtime voodoo for applying fallback methods to other classes in a category-like manner.

@interface ADBFallbackProxyCategory: NSObject

//Copies the specified instance method from the proxy class onto the target class,
//if the target class does not already respond to that selector.
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

//Available natively in OS X 10.9; redefined for OS X 10.8 and below
- (const char *) filesystemRepresentation;

@end

@interface NSURLProxyCategory: ADBFallbackProxyCategory
@end