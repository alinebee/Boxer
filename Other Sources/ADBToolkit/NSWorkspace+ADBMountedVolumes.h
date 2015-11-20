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

//The ADBMountedVolumes category adds methods to NSWorkspace to retrieve all volumes of a certain type,
//and to determine the source image for a mounted volume using HDIUtil.

//Note that many of these methods may block for a long time if a mounted network volume is unavailable:
//NSWorkspace and/or HDIUtil have to wait for network volume connections to time out.

#import <Cocoa/Cocoa.h>


#pragma mark - Volume-type constants

//Filesystem types, for use with mountedVolumesOfType:
extern NSString * const ADBDataCDVolumeType;
extern NSString * const ADBAudioCDVolumeType;
extern NSString * const ADBFATVolumeType;
extern NSString * const ADBHFSVolumeType;


#pragma mark - Error constants


//Error domains and userInfo keys
extern NSString * const ADBMountedVolumesErrorDomain;

//Mount-related error codes
enum
{
	//Produced when hdiutil cannot mount the image passed to mountImageAtURL:options:error:
	ADBMountedVolumesHDIUtilAttachFailed,
    
    //Produced when hdiutil failed to return volume data. Returned by mountedImageInfoWithError:.
    ADBMountedVolumesHDIUtilInfoFailed,
};

typedef NS_OPTIONS(NSUInteger, ADBImageMountingOptions) {
    ADBMountReadOnly = 1 << 0,  //Mount the image as a read-only volume
    ADBMountInvisible = 1 << 1, //Hide the mounted volume from Finder
    ADBMountRaw = 1 << 2,       //Force the image to be mounted as raw
};



#pragma mark - Interface

@interface NSWorkspace (ADBMountedVolumes)

//The UTIs of disk image formats that mountImageAtURL:options:error:
//will automatically treat as raw images.
+ (NSSet *) rawImageTypes;

#pragma mark - Introspecting mounted volumes

//Returns an array of the URLs of all locally-mounted volumes, i.e. excluding network volumes.
//If hidden is YES, this will include invisible volumes.
//Note that this will block and can take a significant time to return if a volume has been
//disconnected unexpectedly or is not responding.
- (NSArray<NSURL*> *) mountedVolumeURLsIncludingHidden: (BOOL)hidden;

//Returns the URLs all mounted filesystems of the specified filesystem type.
- (NSArray *) mountedVolumeURLsOfType: (NSString *)volumeType
                      includingHidden: (BOOL)hidden;

//Returns whether the volume at the specified file path is visible in Finder.
//If this is NO, it means the volume has been mounted hidden.
- (BOOL) isVisibleVolumeAtURL: (NSURL *)URL;

//Returns the underlying filesystem type of the specified URL.
- (NSString *) typeOfVolumeAtURL: (NSURL *)URL;


#pragma mark - Dealing with mounted images

//Tells hdiutil to mount the specified disk image with the specified volume options.
//On success, returns an array of one or more URLs representing volumes mounted from
//the image.
//On failure, returns nil and populates outError.
- (NSArray *) mountImageAtURL: (NSURL *)URL
                      options: (ADBImageMountingOptions)options
                        error: (out NSError **)outError;

//Returns structured plist info from hdiutil about mounted images and their volumes.
//Returns nil and populates outError if the information could not be retrieved.
- (NSArray *) mountedImageInfoWithError: (out NSError **)outError;

//Returns the URL of the source disk image from which the specified volume path was mounted.
//Returns nil if the source image could not be determined (e.g. if the volume is not mounted
//from a disk image.)
- (NSURL *) sourceImageForVolumeAtURL: (NSURL *)volumeURL;

//Returns all volume URLs mounted from the specified source disk image.
//Returns an empty array if the source image is not currently mounted.
- (NSArray *) mountedVolumeURLsForSourceImageAtURL: (NSURL *)volumeURL;


#pragma mark - Dealing with mounted CD-ROMs

//Returns the URL of the data volume associated with the specified CD volume.
//Returns nil if the CD volume has no corresponding data volume.
- (NSURL *) dataVolumeOfAudioCDAtURL: (NSURL *)audioCDURL;

//Returns the URL of the audio CD volume associated with the specified data CD volume.
//Returns nil if the CD volume has no corresponding audio volume.
- (NSURL *) audioVolumeOfDataCDAtURL: (NSURL *)dataCDURL;

//Returns YES if the specified path points to the HFS volume of a hybrid Mac+PC CD,
//NO otherwise.
- (BOOL) isHybridCDAtURL: (NSURL *)volumeURL;

//When given a path to the HFS volume of a hybrid Mac+PC CD, returns the BSD device name
//of the corresponding ISO volume. Returns nil if the path was not a hybrid CD or if no
//matching device name could be determined.
- (NSString *) BSDDeviceNameForISOVolumeOfHybridCDAtURL: (NSURL *)volumeURL;


#pragma mark - Dealing with mounted floppy disks

//Returns whether the specified volume appears to be a FAT-formatted floppy disk.
- (BOOL) isFloppyVolumeAtURL: (NSURL *)volumeURL;


#pragma mark - Low-level methods

//Returns the BSD device name (dev/diskXsY) for the specified volume.
//Returns nil if no matching device name could be determined.
- (NSString *) BSDDeviceNameForVolumeAtURL: (NSURL *)volumeURL;

@end


#pragma mark - Creaky old NSString path API

@interface NSWorkspace (ADBMountedVolumesLegacyPathAPI)

//Returns an array of visible locally mounted volumes.
//If hidden is YES, or on 10.5, this will also include invisible volumes.
- (NSArray *) mountedLocalVolumePathsIncludingHidden: (BOOL)hidden __deprecated;

//Returns whether the volume at the specified file path is visible in Finder.
//If this is NO, it means the volume has been mounted hidden (and should probably be ignored.)
- (BOOL) volumeIsVisibleAtPath: (NSString *)path __deprecated;

//Returns all mounted filesystems of the specified filesystem type.
//If hidden is YES, or on 10.5, this will also include invisible volumes.
- (NSArray *) mountedVolumesOfType: (NSString *)volumeType includingHidden: (BOOL)hidden __deprecated;

//Returns the underlying filesystem type of the specified path.
- (NSString *) volumeTypeForPath: (NSString *)path __deprecated;

//Return the base volume path upon which the specified path resides.
- (NSString *) volumeForPath: (NSString *)path __deprecated;

//Returns the path to the source disk image from which the specified volume path was created.
//Returns nil if the source image could not be determined (e.g. if the volume is not mounted from a disk image)
- (NSString *) sourceImageForVolume: (NSString *)volumePath __deprecated;

//Returns the first path at which the specified source disk image is mounted.
//Returns nil if the source image is not currently mounted.
- (NSString *) volumeForSourceImage: (NSString *)imagePath __deprecated;

//Mounts the disk image at the specified path, and returns the path to the newly-mounted volume if successful.
//Returns nil and populates error if mounting failed.
//If invisible is true, the mounted volume will not appear in Finder.
- (NSString *) mountImageAtPath: (NSString *)path
					   readOnly: (BOOL)readOnly
					  invisibly: (BOOL)invisible
						  error: (NSError **)error __deprecated;

//Returns the path of the data volume associated with the specified CD volume path.
//Returns nil if the CD volume has no corresponding data volume.
- (NSString *) dataVolumeOfAudioCD: (NSString *)volumePath __deprecated;

//Returns the path of the audio CD volume associated with the specified data CD volume path.
//Returns nil if the CD volume has no corresponding audio volume.
- (NSString *) audioVolumeOfDataCD: (NSString *)volumePath __deprecated;

//Returns whether the specified volume is actually a DOS floppy disk.
- (BOOL) isFloppyVolumeAtPath: (NSString *)volumePath __deprecated;

//Returns whether the specified volume is the size of a DOS floppy disk.
- (BOOL) isFloppySizedVolumeAtPath: (NSString *)volumePath __deprecated;

@end
