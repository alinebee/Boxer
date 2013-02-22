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

#import "ADBBinCueImage.h"
#import "ADBISOImagePrivate.h"
#import "NSURL+ADBFilesystemHelpers.h"
#import "RegexKitLite.h"


//Matches the following lines with optional leading and trailing whitespace:
//FILE MAX.gog BINARY
//FILE "MAX.gog" BINARY
//FILE "Armin van Buuren - A State of Trance 179 (16-12-2004) Part2.wav" WAV
//FILE 01_armin_van_buuren_-_in_the_mix_(asot179)-cable-12-16-2004-hsalive.mp3 MP3
NSString * const ADBCueFileDescriptorSyntax = @"FILE\\s+(?:\"(.+)\"|(\\S+))\\s+[A-Z]+";

//The maximum size in bytes that a cue file is expected to be, before we consider it not a cue file.
//This is used as a sanity check by +isCueAtPath: to avoid scanning large files unnecessarily.
#define ADBCueMaxFileSize 10240


@implementation ADBBinCueImage


#pragma mark -
#pragma mark Helper class methods

+ (NSArray *) rawPathsInCueContents: (NSString *)cueContents
{
	NSMutableArray *paths = [NSMutableArray arrayWithCapacity: 1];
	
	NSRange usefulComponents = NSMakeRange(1, 2);
	NSArray *matches = [cueContents arrayOfCaptureComponentsMatchedByRegex: ADBCueFileDescriptorSyntax];
	
	for (NSArray *components in matches)
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		for (NSString *fileName in [components subarrayWithRange: usefulComponents])
		{
			if (fileName.length)
			{
                //Normalize escaped quotes
                NSString *normalizedName = [fileName stringByReplacingOccurrencesOfString: @"\\\"" withString: @"\""];
				[paths addObject: normalizedName];
				break;
			}
		}
		[pool release];
	}
	
	return paths;
}

+ (NSArray *) rawPathsInCueAtPath: (NSString *)cuePath error: (out NSError **)outError
{
    NSString *cueContents = [[NSString alloc] initWithContentsOfFile: cuePath
                                                        usedEncoding: NULL
                                                               error: outError];
	
    if (!cueContents) return nil;
    
    NSArray *paths = [self rawPathsInCueContents: cueContents];
    [cueContents release];
    
    return paths;
}

+ (NSArray *) resourcePathsInCueAtPath: (NSString *)cuePath error: (out NSError **)outError
{
    NSArray *rawPaths = [self rawPathsInCueAtPath: cuePath error: outError];
    if (!rawPaths) return nil;
    
    //The path relative to which we will resolve the paths in the CUE
    NSString *basePath = [cuePath stringByDeletingLastPathComponent];
    
    NSMutableArray *resolvedPaths = [NSMutableArray arrayWithCapacity: [rawPaths count]];
    for (NSString *rawPath in rawPaths)
    {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
        //Rewrite Windows-style paths
        NSString *normalizedPath = [rawPath stringByReplacingOccurrencesOfString: @"\\" withString: @"/"];
        
        //Form an absolute path with all symlinks and ../ components fully resolved.
        NSString *resolvedPath	= [[basePath stringByAppendingPathComponent: normalizedPath] stringByStandardizingPath];
        
        [resolvedPaths addObject: resolvedPath];
        
        [pool drain];
    }
    return resolvedPaths;
}

+ (NSString *) binPathInCueAtPath: (NSString *)cuePath error: (out NSError **)outError
{
    NSArray *resolvedPaths = [self resourcePathsInCueAtPath: cuePath error: outError];
    if (![resolvedPaths count]) return nil;
    
    //Assume the first entry in the CUE file is always the binary image.
    //(This is not always true, and we should do more in-depth scanning.)
    return [resolvedPaths objectAtIndex: 0];
}

+ (BOOL) isCueAtPath: (NSString *)cuePath error: (out NSError **)outError
{
    NSFileManager *manager = [NSFileManager defaultManager];
    
    BOOL isDir, exists = [manager fileExistsAtPath: cuePath isDirectory: &isDir];
    //TODO: populate outError
    if (!exists || isDir) return NO;
    
    unsigned long long fileSize = [[manager attributesOfItemAtPath: cuePath error: outError] fileSize];
    
    //If the file is too large, assume it can't be a file and bail out
    if (!fileSize ||  fileSize > ADBCueMaxFileSize) return NO;
    
    //Otherwise, load it in and see if it appears to contain any usable paths
    NSString *cueContents = [[NSString alloc] initWithContentsOfFile: cuePath
                                                        usedEncoding: NULL
                                                               error: outError];
    
    if (!cueContents) return NO;
    
    BOOL isCue = [cueContents isMatchedByRegex: ADBCueFileDescriptorSyntax];
    [cueContents release];
    return isCue;
}

- (id) init
{
    if ((self = [super init]))
    {
        _rawSectorSize = ADBBINCUERawSectorSize;
        _leadInSize = ADBBINCUELeadInSize;
    }
    return self;
}

- (BOOL) _loadImageAtURL: (NSURL *)URL
                   error: (out NSError **)outError
{
    //Load the BIN part of the cuesheet
    if ([self.class isCueAtPath: URL.path error: outError])
    {
        NSString *binPath = [self.class binPathInCueAtPath: URL.path error: outError];
        if (binPath)
        {
            URL = [NSURL fileURLWithPath: binPath];
        }
        else
        {
            return nil;
        }
    }
    
    return [super _loadImageAtURL: URL error: outError];
}

@end
