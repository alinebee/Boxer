/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "NSURL+BXQuickLookHelpers.h"
#import <QuickLook/QuickLook.h>

@implementation NSURL (BXQuickLookHelpers)

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
        
        return [image autorelease];
    }
    else
    {
        return nil;
    }
}
@end
