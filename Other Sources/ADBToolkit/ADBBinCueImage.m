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

#pragma mark - Helper class methods

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

+ (NSArray *) resourceURLsInCueAtURL: (NSURL *)cueURL error: (out NSError **)outError
{
    NSString *cueContents = [[NSString alloc] initWithContentsOfURL: cueURL
                                                       usedEncoding: NULL
                                                              error: outError];
	
    if (!cueContents)
        return nil;
    
    NSArray *rawPaths = [self rawPathsInCueContents: cueContents];
    [cueContents release];
    
    //The URL relative to which we will resolve the paths in the CUE
    NSURL *baseURL = cueURL.URLByDeletingLastPathComponent;
    
    NSMutableArray *resolvedURLs = [NSMutableArray arrayWithCapacity: rawPaths.count];
    for (NSString *rawPath in rawPaths)
    {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
        //Rewrite Windows-style paths
        NSString *normalizedPath = [rawPath stringByReplacingOccurrencesOfString: @"\\" withString: @"/"];
        
        //Form an absolute path with all ../ components resolved.
        NSURL *resourceURL = [baseURL URLByAppendingPathComponent: normalizedPath].URLByStandardizingPath;
        
        [resolvedURLs addObject: resourceURL];
        
        [pool drain];
    }
    return resolvedURLs;
}

+ (NSURL *) dataImageURLInCueAtURL: (NSURL *)cueURL error: (out NSError **)outError
{
    NSArray *resolvedURLs = [self resourceURLsInCueAtURL: cueURL error: outError];
    if (!resolvedURLs.count) return nil;
    
    //Assume the first entry in the CUE file is always the binary image.
    //(This is not always true, and we should do more in-depth scanning.)
    return [resolvedURLs objectAtIndex: 0];
}

+ (BOOL) isCueAtURL: (NSURL *)cueURL error: (out NSError **)outError
{
    if (![cueURL checkResourceIsReachableAndReturnError: outError])
        return NO;
    
    NSNumber *fileSizeValue;
    BOOL checkedSize = [cueURL getResourceValue: &fileSizeValue forKey: NSURLFileSizeKey error: outError];
    if (!checkedSize)
        return NO;
    
    //If the specified file appears to be too large, assume it can't be a CUE file and bail out
    unsigned long long fileSize = fileSizeValue.unsignedLongLongValue;
    if (fileSize == 0 || fileSize > ADBCueMaxFileSize)
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                            code: NSFileReadTooLargeError
                                        userInfo: @{ NSURLErrorKey: cueURL }];
        }
        return NO;
    }
    
    //Otherwise, load it in and see if it contains any track definitions.
    NSString *cueContents = [[NSString alloc] initWithContentsOfURL: cueURL
                                                       usedEncoding: NULL
                                                              error: outError];
    
    if (!cueContents)
        return NO;
    
    BOOL isCue = [cueContents isMatchedByRegex: ADBCueFileDescriptorSyntax];
    [cueContents release];
    
    return isCue;
}

- (BOOL) _loadImageAtURL: (NSURL *)URL
                   error: (out NSError **)outError
{
    //Load the BIN part of the cuesheet
    if ([self.class isCueAtURL: URL error: outError])
    {
        //TODO: check the mode from the cue-sheet and populate the sector size and lead-in appropriately
        NSURL *dataURL = [self.class dataImageURLInCueAtURL: URL error: outError];
        if (dataURL)
        {
            URL = dataURL;
        }
        else
        {
            return NO;
        }
    }
    
    return [super _loadImageAtURL: URL error: outError];
}

@end
