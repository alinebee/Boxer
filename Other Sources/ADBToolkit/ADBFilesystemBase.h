//
//  ADBFilesystemBase.h
//  Boxer
//
//  Created by Alun Bestor on 01/04/2013.
//  Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ADBFilesystem.h"

//Provides baseline implementations of many common filesystem features.
//Must be subclassed to be useful.

@interface ADBFilesystemBase : NSObject <ADBFilesystemLogicalURLAccess>
{
    NSMutableArray *_mutableRepresentedURLs;
    NSURL *_baseURL;
}

//The OS X filesystem location that forms the root of this filesystem.
//All logical paths and URLs will be resolved relative to this location,
//and the filesystem will not provide access to locations outside of this
//root folder.
@property (readonly, copy, nonatomic) NSURL *baseURL;

@end


#pragma mark - Subclass API

//Intended for use by subclasses only.
@interface ADBFilesystemBase ()

//An array of represented URLs sorted by length, used for logical URL resolution.
@property (retain, nonatomic) NSMutableArray *mutableRepresentedURLs;

//Overridden to be read-writable.
@property (copy, nonatomic) NSURL *baseURL;

@end
