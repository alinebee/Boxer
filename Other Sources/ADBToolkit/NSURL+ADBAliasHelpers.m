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

#import "NSURL+ADBAliasHelpers.h"

@implementation NSURL (ADBAliasHelpers)

+ (NSData *) bookmarkDataFromAliasRecord: (NSData *)aliasRecord
                                   error: (out NSError **)outError
{
    CFDataRef bookmarkDataRef = CFURLCreateBookmarkDataFromAliasRecord(kCFAllocatorDefault, (__bridge CFDataRef)aliasRecord);
    if (bookmarkDataRef)
    {
        return (NSData *)CFBridgingRelease(bookmarkDataRef);
    }
    else
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                            code: NSFileReadCorruptFileError
                                        userInfo: nil];
        }
        return nil;
    }
}

+ (id) URLByResolvingAliasRecord: (NSData *)aliasRecord
                         options: (NSURLBookmarkResolutionOptions)options
                   relativeToURL: (NSURL *)relativeURL
             bookmarkDataIsStale: (out BOOL *)isStale
                           error: (out NSError **)outError
{
    NSData *bookmarkData = [self bookmarkDataFromAliasRecord: aliasRecord error: outError];
    if (bookmarkData)
    {
        return [NSURL URLByResolvingBookmarkData: bookmarkData
                                         options: options
                                   relativeToURL: relativeURL
                             bookmarkDataIsStale: isStale
                                           error: outError];
    }
    else return nil;
}

@end
