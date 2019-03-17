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
#import "NSURL+ADBFilesystemHelpers.h"


@implementation NSWorkspace (ADBIconHelpers)

- (BOOL) fileHasCustomIcon: (NSString *)path
{
    return [self URLHasCustomIcon: [NSURL fileURLWithPath: path]];
}

- (BOOL) URLHasCustomIcon: (NSURL *)URL
{
    // IMPLEMENTATION NOTE:
    //
    // FSCatalogInfo.finderInfo.finderFlags & kHasCustomIcon still works in 10.13.4,
    // but has been deprecated for years and cannot be long for this world.
    //
    // It has two replacement APIs, neither of which actually work:
    // MDItemCopyAttribute(itemFromURL, kMDItemFSHasCustomIcon) always returns NULL.
    // [URL resourceValueForKey:NSURLCustomIconKey] always returns nil.
    //
    // Custom icons on folders and bundles are stored in a file called `Icon\r` in the root of that folder,
    // and are marked with a special metadata attribute which tells Finder to bother looking for that icon.
    // If the file is present, but the attribute isn't, then no custom icon will be displayed.
    // (The attribute can sometimes be stripped by Dropbox and other file-syncing services.)
    //
    // We can no longer reliably check for the presence of that attribute,
    // but we can at least check if the icon is there and hope that the attribute is still intact.
    NSURL *iconURL = [URL URLByAppendingPathComponent: @"Icon\r"];
    return [iconURL checkResourceIsReachableAndReturnError: NULL];
}
@end
