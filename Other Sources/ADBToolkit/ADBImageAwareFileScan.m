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

#import "ADBImageAwareFileScan.h"
#import "NSWorkspace+ADBMountedVolumes.h"
#import "NSWorkspace+ADBFileTypes.h"


@implementation ADBImageAwareFileScan
@synthesize mountedVolumePath = _mountedVolumePath;
@synthesize ejectAfterScanning = _ejectAfterScanning;
@synthesize didMountVolume = _didMountVolume;

- (id) init
{
    if ((self = [super init]))
    {
        self.ejectAfterScanning = ADBFileScanEjectIfSelfMounted;
    }
    return self;
}

- (void) dealloc
{
    self.mountedVolumePath = nil;
    
    [super dealloc];
}

- (NSString *) fullPathFromRelativePath: (NSString *)relativePath
{
    //Return paths relative to the mounted volume instead, if available.
    NSString *filesystemRoot = (self.mountedVolumePath) ? self.mountedVolumePath : self.basePath;
    return [filesystemRoot stringByAppendingPathComponent: relativePath];
}

//If we have a mounted volume path for an image, enumerate that instead of the original base path
- (NSDirectoryEnumerator *) enumerator
{
    if (self.mountedVolumePath)
        return [_manager enumeratorAtPath: self.mountedVolumePath];
    else return [super enumerator];
}

- (void) willPerformOperation
{
    NSString *volumePath = nil;
    _didMountVolume = NO;
    
    //If the target path is on a disk image, then mount the image for scanning
    if ([_workspace file: self.basePath matchesTypes: [NSSet setWithObject: @"public.disk-image"]])
    {
        //First, check if the image is already mounted
        volumePath = [_workspace volumeForSourceImage: self.basePath];
        
        //If it's not mounted yet, mount it ourselves
        if (!volumePath)
        {
            NSError *mountError = nil;
            volumePath = [_workspace mountImageAtPath: self.basePath
                                             readOnly: YES
                                            invisibly: YES
                                                error: &mountError];
            
            //If we couldn't mount the image, give up in failure
            if (!volumePath)
            {
                self.error = mountError;
                return;
            }
            else _didMountVolume = YES;
        }
        
        self.mountedVolumePath = volumePath;
    }    
}

- (void) didPerformOperation
{
    //If we mounted a volume ourselves in order to scan it,
    //or we've been told to always eject, then unmount the volume
    //once we're done
    if (self.mountedVolumePath)
    {
        if ((self.ejectAfterScanning == ADBFileScanAlwaysEject) ||
            (_didMountVolume && self.ejectAfterScanning == ADBFileScanEjectIfSelfMounted))
        {
            [_workspace unmountAndEjectDeviceAtPath: self.mountedVolumePath];
            self.mountedVolumePath = nil;
        }
    }    
}

@end
