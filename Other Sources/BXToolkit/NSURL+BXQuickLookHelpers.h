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
//pixelSize specifies the maximum pixel dimensions for the preview, and does not take into account
//any UI scaling factors.
//If useIconStyle is true, the thumbnail will be generated with the shadow and page-curl effects seen in Finder.
//USAGE NOTE: this method is synchronous and can take a while to complete, so should be performed on a background thread.
- (NSImage *) quickLookThumbnailWithSize: (NSSize)pixelSize iconStyle: (BOOL)useIconStyle;

@end
