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

//ADBMountableFilesystem is a local filesystem variant whose baseURL represents an image
//that can be mounted as a volume by hdiutil. It mounts the volume whenever file access
//is needed, and can unmount the volume automatically once it has finished.

#import "ADBLocalFilesystem.h"


#pragma mark - Error constants
extern NSString * const ADBMountableImageErrorDomain;

enum {
    //Returned by if the specified image is not 
    ADBMountableImageUnsupportedImageType = 1,
    
    //Returned by volumeURLMountingIfNeeded:error: when the image is not mounted
    //and the filesystem has not been given permission to mount it.
    ADBMountableImageVolumeUnavailable = 2,
};


@interface ADBMountableImage : ADBLocalFilesystem
{
    NSURL *_mountedVolumeURL;
    BOOL _unmountWhenDone;
}

//Returns a list of all image types mountable by this class.
+ (NSSet *) supportedImageTypes;

//Whether to unmount the volume when this instance goes out of scope.
//This will be automatically set to YES whenever the filesystem mounts
//the image itself, and reset to NO if the filesystem is unmounted.
@property (assign, nonatomic) BOOL unmountWhenDone;


#pragma mark - Constructors

//Returns a new instance using the image at the specified URL.
//Returns nil and populates outError if the URL was not a supported image.
+ (id) imageWithContentsOfURL: (NSURL *)baseURL error: (out NSError **)outError;
- (id) initWithContentsOfURL: (NSURL *)baseURL error: (out NSError **)outError;


#pragma mark - Internal methods

//Called whenever NSWorkspace notifies that a volume has been unmounted or renamed.
//If the volume corresponds to our own, this will clear/update our cached records.
- (void) volumeDidUnmount: (NSNotification *)notification;
- (void) volumeDidRename: (NSNotification *)notification;

//Returns the filesystem URL of the mounted volume representing the image's contents.
//If mountIfNeeded is YES, the filesystem will attempt to mount the backing image
//if it's not already, returning nil and populating outError if the image could
//not be mounted. If mountIfNeeded is NO and the image is not already mounted,
//it will return nil and populate outError.
- (NSURL *) volumeURLMountingIfNeeded: (BOOL)mountIfNeeded
                                error: (out NSError **)outError;

//Unmount the backing volume for the image if it is mounted. Returns YES on success
//and NO and populates outError upon failure.
//Called automatically when the filesystem is deallocated, if unmountIsDone is YES.
- (BOOL) unmountVolumeWithError: (out NSError **)outError;

@end
