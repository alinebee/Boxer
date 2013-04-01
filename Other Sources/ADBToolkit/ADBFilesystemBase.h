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


//Provides baseline implementations of many common filesystem features.
//Must be subclassed to be useful.

#import <Foundation/Foundation.h>
#import "ADBFilesystem.h"

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
