/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "NSWorkspace+BXFileTypes.h"

@implementation NSWorkspace (BXFileTypes)

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
