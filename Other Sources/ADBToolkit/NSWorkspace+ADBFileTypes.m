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


#import "NSWorkspace+ADBFileTypes.h"

@implementation NSWorkspace (ADBFileTypes)

- (BOOL) fileAtURL: (NSURL *)URL matchesTypes: (NSSet *)acceptedTypes
{
    return [self file: URL.path matchesTypes: acceptedTypes];
}

- (BOOL) file: (NSString *)filePath matchesTypes: (NSSet *)acceptedTypes
{
	NSString *fileType = [self typeOfFile: filePath error: nil];
    
    //If OS X can determine a UTI for the specified file, then check if that UTI matches one of the specified types
	if (fileType)
	{
		for (NSString *acceptedType in acceptedTypes)
		{
			if ([self type: fileType conformsToType: acceptedType]) return YES;
		}
	}
    
    //If no filetype match was found, check whether the file extension alone matches any of the specified types.
    //(This allows us to judge filetypes based on filename alone, e.g. for nonexistent/inaccessible files;
    //and works around an NSWorkspace typeOfFile: limitation whereby it may return an overly generic UTI
    //for a file or folder instead of a proper specific UTI.
    NSString *fileExtension	= [filePath pathExtension];
    if ([fileExtension length] > 0)
    {
        for (NSString *acceptedType in acceptedTypes)
		{
			if ([self filenameExtension: fileExtension isValidForType: acceptedType]) return YES;
		}
    }
    
	return NO;
}

- (NSURL *) nearestAncestorOfURL: (NSURL *)URL matchingTypes: (NSSet *)acceptedTypes
{
    NSString *path = [self parentOfFile: URL.path matchingTypes: acceptedTypes];
    return [NSURL fileURLWithPath: path];
}

- (NSString *) parentOfFile: (NSString *)filePath matchingTypes: (NSSet *)acceptedTypes
{
	do
	{
		if ([self file: filePath matchesTypes: acceptedTypes])
            return filePath;
        
		filePath = filePath.stringByDeletingLastPathComponent;
	}
	while (filePath.length && ![filePath isEqualToString: @"/"]);
	return nil;
}

@end
