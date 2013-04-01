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

//Contains protected API that should only be used by ADBLocalFilesystem subclasses.

#import "ADBLocalFilesystem.h"

@interface ADBLocalFilesystem ()

//Our own file manager for internal use.
@property (retain, nonatomic) NSFileManager *manager;

//A base implementation for copyItemAtPath:toPath:error: and moveItemAtPath:toPath:error:,
//which share 95% of their logic.
- (BOOL) _transferItemAtPath: (NSString *)fromPath
                      toPath: (NSString *)toPath
                     copying: (BOOL)copying
                       error: (out NSError **)outError;

@end

//An extremely thin wrapper for an NSDirectoryEnumerator to implement
//the ADBFilesystem enumeration protocols and allow filesystem-relative
//paths to be returned.
@interface ADBLocalDirectoryEnumerator : NSEnumerator <ADBFilesystemPathEnumeration, ADBFilesystemFileURLEnumeration>
{
    BOOL _returnsFileURLs;
    NSDirectoryEnumerator *_enumerator;
    ADBLocalFilesystem *_filesystem;
    NSURL *_currentURL;
}

@property (copy, nonatomic) NSURL *currentURL;
@property (retain, nonatomic) NSDirectoryEnumerator *enumerator;
@property (retain, nonatomic) ADBLocalFilesystem *filesystem;

- (id) initWithURL: (NSURL *)localURL
       inFilesytem: (ADBLocalFilesystem *)filesystem
includingPropertiesForKeys: (NSArray *)keys
           options: (NSDirectoryEnumerationOptions)mask
        returnURLs: (BOOL)returnURLs
      errorHandler: (ADBFilesystemFileURLErrorHandler)errorHandler;

@end