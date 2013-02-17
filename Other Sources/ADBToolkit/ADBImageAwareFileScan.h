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


//ADBImageAwareFileScan is a ADBFileScan subclass that can also scan the
//contents of any disk image supported by OS X's hdiutil. File matches
//will be returned as a relative path appended to the original image path.

#import "ADBFileScan.h"


typedef enum {
    ADBFileScanEjectIfSelfMounted,
    ADBFileScanNeverEject,
    ADBFileScanAlwaysEject
} ADBFileScanEjectionBehaviour;

    
@interface ADBImageAwareFileScan : ADBFileScan
{
    NSString *_mountedVolumePath;
    ADBFileScanEjectionBehaviour _ejectAfterScanning;
    BOOL _didMountVolume;
}

//The volume path at which the original source disk image is mounted.
//Only valid while scanning a disk image.
@property (copy) NSString *mountedVolumePath;

//Whether the file scan operation mounted an image volume itself while scanning.
//This will be NO if scanning a regular folder or if the scanned image was
//already mounted by the time we came to scan it.
@property (readonly) BOOL didMountVolume;

//Whether to automatically unmount any mounted path after the scan is complete.
//By default this will only unmount if the scan itself was responsible for
//mounting the path.
@property (assign) ADBFileScanEjectionBehaviour ejectAfterScanning;

//The scan's performOperation implementation is split up into 3 stages for easy
//customisation in subclasses:

//Called before scanning to mount the base path if it is an image.
- (void) mountVolumesForScan;

//Performs the actual scan, which calls BXFileScan's original performOperation.
- (void) performScan;

//Called after scanning to unmount if desired.
- (void) unmountVolumesForScan;

@end
