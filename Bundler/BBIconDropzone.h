//
//  BBIconDropzone.h
//  Boxer Bundler
//
//  Created by Alun Bestor on 15/08/2012.
//  Copyright (c) 2012 Alun Bestor. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface BBIconDropzone : NSImageView

//Returns the URL of the image currently displayed in the image view.
@property (copy, nonatomic) NSURL *imageURL;

@end
