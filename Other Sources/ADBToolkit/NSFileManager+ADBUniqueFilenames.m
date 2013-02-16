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

#import "NSFileManager+ADBUniqueFilenames.h"
#import "NSError+ADBErrorHelpers.h"

NSString * const ADBDefaultIncrementedFilenameFormat = @"%1$@ (%2$lu).%3$@";

typedef BOOL(^ADBUniqueFilenameOperation)(NSURL *uniqueURL, NSError **outError);


@interface NSFileManager (ADBUniqueFilenamesPrivate)

//Generic utility method used by the below. This takes a particular file operation
//and feeds it either the original target URL or an incremented version of same.
//If the operation returns YES, that URL is returned; if the operation returned
//NO because the target URL already exists, the target will be incremented and it
//tries again; otherwise it will return nil and populate outError with any error
//the operation threw back.
- (NSURL *) _performFileOperation: (ADBUniqueFilenameOperation)operation
                          withURL: (NSURL *)targetURL
        incrementedFilenameFormat: (NSString *)filenameFormat
                            error: (out NSError **)outError;

@end


@implementation NSFileManager (ADBUniqueFilenames)

- (NSURL *) uniqueURLForURL: (NSURL *)URL
             filenameFormat: (NSString *)filenameFormat
{
    ADBUniqueFilenameOperation operation = ^BOOL(NSURL *uniqueURL, NSError **outError) {
        return ![uniqueURL checkResourceIsReachableAndReturnError: NULL];
    };
    
    return [self _performFileOperation: operation
                               withURL: URL
                        filenameFormat: filenameFormat
                                 error: NULL];
}

+ (NSURL *) incrementedURL: (NSURL *)URL
                withFormat: (NSString *)filenameFormat
                 increment: (NSUInteger)increment
{
    NSURL *baseURL = URL.URLByDeletingLastPathComponent;
    NSString *baseName = URL.lastPathComponent.stringByDeletingPathExtension;
    NSString *extension = URL.pathExtension;
    
    NSString *incrementedName = [NSString stringWithFormat: filenameFormat, baseName, extension, increment];
    NSURL *incrementedURL = [baseURL URLByAppendingPathComponent: incrementedName];
    
    return incrementedURL;
}

- (NSURL *) copyItemAtURL: (NSURL *)sourceURL
                    toURL: (NSURL *)destinationURL
           filenameFormat: (NSString *)filenameFormat
                    error: (out NSError **)outError
{
    ADBUniqueFilenameOperation operation = ^BOOL (NSURL *uniqueURL, NSError **outErrorp) {
        return [self copyItemAtURL: sourceURL toURL: uniqueURL error: outError];
    };
    
    return [self _performFileOperation: operation
                               withURL: destinationURL
                        filenameFormat: filenameFormat error: outError];
}

- (NSURL *) moveItemAtURL: (NSURL *)sourceURL
                    toURL: (NSURL *)destinationURL
           filenameFormat: (NSString *)filenameFormat
                    error: (out NSError **)outError
{
    ADBUniqueFilenameOperation operation = ^BOOL (NSURL *uniqueURL, NSError **outErrorp) {
        return [self moveItemAtURL: sourceURL toURL: uniqueURL error: outError];
    };
    
    return [self _performFileOperation: operation
                               withURL: destinationURL
                        filenameFormat: filenameFormat error: outError];
}

- (NSURL *) createDirectoryAtURL: (NSURL *)URL
                  filenameFormat: (NSString *)filenameFormat
                      attributes: (NSDictionary *)attributes
                           error: (out NSError **)outError
{
    ADBUniqueFilenameOperation operation = ^BOOL (NSURL *uniqueURL, NSError **outErrorp) {
        return [self createDirectoryAtURL: URL
              withIntermediateDirectories: NO //Must be no, because otherwise this method will blithely return YES when the destination already exists.
                               attributes: attributes
                                    error: outError];
    };
    
    return [self _performFileOperation: operation
                               withURL: URL
                        filenameFormat: filenameFormat
                                 error: outError];
}


#pragma mark - Private methods

- (NSURL *) _performFileOperation: (ADBUniqueFilenameOperation)operation
                          withURL: (NSURL *)targetURL
                   filenameFormat: (NSString *)filenameFormat
                            error: (out NSError **)outError
{
    NSURL *baseURL = targetURL.URLByDeletingLastPathComponent;
    NSString *baseName = targetURL.lastPathComponent.stringByDeletingPathExtension;
    NSString *extension = targetURL.pathExtension;
    
    NSURL *uniqueURL = targetURL;
    NSUInteger nextIncrement = 2;
    while (YES)
    {
        NSError *operationError = nil;
        BOOL succeeded = operation(uniqueURL, &operationError);
        
        if (succeeded)
        {
            return uniqueURL;
        }
        else if ([uniqueURL checkResourceIsReachableAndReturnError: NULL])
        {
            NSString *incrementedName = [NSString stringWithFormat: filenameFormat, baseName, extension, nextIncrement];
            uniqueURL = [baseURL URLByAppendingPathComponent: incrementedName];
            nextIncrement++;
        }
        else
        {
            if (outError)
                *outError = operationError;
            return nil;
        }
    }
}

@end
