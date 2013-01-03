//
//  NSURL+BXQuicklookHelpers.h
//  Boxer
//
//  Created by Alun Bestor on 02/01/2013.
//  Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSURL (BXQuickLookHelpers)

//Returns a QuickLook thumbnail for the file at this URL, or nil if no thumbnail could be generated.
//pixelSize specifies the maximum pixel dimensions for the preview, without taking into account
//any UI scaling factors. The returned image is guaranteed to be *at most* this size;
//a smaller image may be returned.
//If useIconStyle is true, the thumbnail will be generated with the shadow and page-curl effects
//as seen in Finder.
//USAGE NOTE: this method is synchronous and can take a while to complete, so should be performed on a background thread.
- (NSImage *) quickLookThumbnailWithMaxSize: (NSSize)pixelSize iconStyle: (BOOL)useIconStyle;

@end
