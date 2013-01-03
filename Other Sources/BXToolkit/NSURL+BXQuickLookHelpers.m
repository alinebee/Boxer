//
//  NSURL+BXQuicklookHelpers.m
//  Boxer
//
//  Created by Alun Bestor on 02/01/2013.
//  Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
//

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
                                                    (CFURLRef)self,
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
