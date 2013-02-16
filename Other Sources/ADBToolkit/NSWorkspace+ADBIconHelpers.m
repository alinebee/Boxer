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

#import "NSWorkspace+ADBIconHelpers.h"


@implementation NSWorkspace (ADBIconHelpers)

- (BOOL) fileHasCustomIcon: (NSString *)path
{
    return [self fileHasCustomIcon: [NSURL fileURLWithPath: path]];
}

- (BOOL) URLHasCustomIcon: (NSURL *)URL
{
    FSRef fileRef;
    struct FSCatalogInfo catInfo;
    struct FileInfo *finderInfo = (struct FileInfo *)&catInfo.finderInfo;
	
	//Get an FSRef filesystem reference to the specified path
	BOOL gotFileRef = CFURLGetFSRef((CFURLRef)URL, &fileRef);
	//Bail out if we couldn't resolve an FSRef
	if (!gotFileRef) return NO;
		
	//Retrieve the Finder catalog info for the file
    OSStatus result = FSGetCatalogInfo(	&fileRef,
									   kFSCatInfoFinderInfo,
									   &catInfo,
									   NULL,
									   NULL,
									   NULL);
    if (result != noErr) return NO;
	
	//Return whether the custom icon bit has been set
    return (finderInfo->finderFlags & kHasCustomIcon) == kHasCustomIcon;
}
@end
