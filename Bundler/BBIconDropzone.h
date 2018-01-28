//
//  BBIconDropzone.h
//  Boxer Bundler
//
//  Created by Alun Bestor on 15/08/2012.
//  Copyright (c) 2012 Alun Bestor. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/// An image well that captures the original file URL (if any) of any image that is dropped or pasted into it.
@interface BBIconDropzone : NSImageView

/// The URL of the image currently displayed in the image view.
/// NOTE: for consistency reasons, changing this will not change the displayed image.
@property (copy, nonatomic) NSURL *lastDroppedImageURL;

@end
