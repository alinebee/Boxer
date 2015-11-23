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

#import "NSURL+ADBQuickLookHelpers.h"
#import <QuickLook/QuickLook.h>

@implementation NSURL (ADBQuickLookHelpers)

- (NSImage *) quickLookThumbnailWithMaxSize: (NSSize)pixelSize iconStyle: (BOOL)useIconStyle
{
    //Oh my god I hate CF so much
    CFBooleanRef styleFlag = (useIconStyle) ? kCFBooleanTrue : kCFBooleanFalse;
    CFDictionaryRef options = CFDictionaryCreate(CFAllocatorGetDefault(),
                                                 (const void **)&kQLThumbnailOptionIconModeKey,
                                                 (const void **)&styleFlag,
                                                 1,
                                                 &kCFCopyStringDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    
    CGImageRef cgThumbnail = QLThumbnailImageCreate(CFAllocatorGetDefault(),
                                                    (__bridge CFURLRef)self,
                                                    NSSizeToCGSize(pixelSize),
                                                    options);
    
    CFRelease(options);
    
    if (cgThumbnail)
    {
        NSImage *image = [[NSImage alloc] initWithCGImage: cgThumbnail
                                                     size: NSZeroSize];
        
        CGImageRelease(cgThumbnail);
        
        return image;
    }
    else
    {
        return nil;
    }
}
@end
