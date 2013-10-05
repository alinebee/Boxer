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

#import "ADBForwardCompatibility.h"
#import <objc/runtime.h>

NSString * const NSWindowDidChangeBackingPropertiesNotification = @"NSWindowDidChangeBackingPropertiesNotification";
NSString * const NSWindowWillEnterFullScreenNotification = @"NSWindowWillEnterFullScreenNotification";
NSString * const NSWindowDidEnterFullScreenNotification = @"NSWindowDidEnterFullScreenNotification";
NSString * const NSWindowWillExitFullScreenNotification = @"NSWindowWillExitFullScreenNotification";
NSString * const NSWindowDidExitFullScreenNotification = @"NSWindowDidExitFullScreenNotification";


@implementation ADBFallbackProxyCategory

+ (void) addInstanceMethod: (SEL)selector toClass: (Class)targetClass
{
    //Don't bother if the class already implements this selector.
    if ([targetClass instancesRespondToSelector: selector])
        return;
    
    NSAssert2([self instancesRespondToSelector: selector], @"Selector not implemented on %@: %@", self, NSStringFromSelector(selector));
    
    Method method = class_getInstanceMethod(self, selector);
    IMP implementation = method_getImplementation(method);
    const char *types = method_getTypeEncoding(method);
    
    class_addMethod(targetClass, selector, implementation, types);
}

@end

@implementation NSFileManagerProxyCategory

+ (void) load
{
    Class proxiedClass = [NSFileManager class];
    
    //Implementation for createDirectoryAtURL:withIntermediateDirectories:attributes:error:
    SEL createDir = @selector(createDirectoryAtURL:withIntermediateDirectories:attributes:error:);
    [self addInstanceMethod: createDir toClass: proxiedClass];
    
    SEL createSymlink = @selector(createSymbolicLinkAtURL:withDestinationURL:error:);
    [self addInstanceMethod: createSymlink toClass: proxiedClass];
    
    SEL trashItem = @selector(trashItemAtURL:resultingItemURL:error:);
    [self addInstanceMethod: trashItem toClass: proxiedClass];
}

- (BOOL) createDirectoryAtURL: (NSURL *)URL
  withIntermediateDirectories: (BOOL)createIntermediates
                   attributes: (NSDictionary *)attributes
                        error: (out NSError **)error
{
    return [(NSFileManager *)self createDirectoryAtPath: URL.path
                            withIntermediateDirectories: createIntermediates
                                             attributes: attributes
                                                  error: error];
}

- (BOOL) createSymbolicLinkAtURL: (NSURL *)URL
              withDestinationURL: (NSURL *)destURL
                           error: (out NSError **)error
{
    return [(NSFileManager *)self createSymbolicLinkAtPath: URL.path
                                       withDestinationPath: destURL.path
                                                     error: error];
    
}

- (BOOL) trashItemAtURL: (NSURL *)url resultingItemURL: (out NSURL **)outResultingURL error: (out NSError **)outError
{
    const char *originalPath = [(NSFileManager *)self fileSystemRepresentationWithPath: url.path];
    char *trashedPath = NULL;
    
    OSStatus result = FSPathMoveObjectToTrashSync(originalPath, (outResultingURL ? &trashedPath : NULL), kFSFileOperationDefaultOptions);
    if (result == noErr)
    {
        if (outResultingURL && trashedPath)
        {
            NSString *path = [(NSFileManager *)self stringWithFileSystemRepresentation: trashedPath length: strlen(trashedPath)];
            *outResultingURL = [NSURL fileURLWithPath: path];
            free(trashedPath);
        }
        return YES;
    }
    else
    {
        if (outError)
            *outError = [NSError errorWithDomain: NSOSStatusErrorDomain code: result userInfo: @{ NSURLErrorKey: url }];
        
        return NO;
    }
}
@end


@implementation NSURLProxyCategory

+ (void) load
{
    Class proxiedClass = [NSURL class];
    
    SEL filesystemRepresentation = @selector(fileSystemRepresentation);
    [self addInstanceMethod: filesystemRepresentation toClass: proxiedClass];
}


- (const char *) fileSystemRepresentation
{
    NSURL *url = (NSURL *)self;
    return url.path.fileSystemRepresentation;
}

@end