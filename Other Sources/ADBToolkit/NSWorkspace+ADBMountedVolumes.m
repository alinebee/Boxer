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

#import "NSWorkspace+ADBMountedVolumes.h"
#import "NSWorkspace+ADBFileTypes.h"
#import "NSString+ADBPaths.h"
#import "NSURL+ADBFilesystemHelpers.h"
#include <sys/mount.h>


#pragma mark - Class constants

NSString * const ADBDataCDVolumeType	= @"cd9660";
NSString * const ADBAudioCDVolumeType	= @"cddafs";
NSString * const ADBFATVolumeType		= @"msdos";
NSString * const ADBHFSVolumeType		= @"hfs";

//FAT volumes smaller than 2MB will be treated as floppy drives by isFloppyDriveAtPath.
#define ADBFloppySizeCutoff 2 * 1024 * 1024


#pragma mark - Error helper classes

NSString * const ADBMountedVolumesErrorDomain = @"ADBMountedVolumesErrorDomain";


@interface ADBMountedVolumesError : NSError
@end

@interface ADBCouldNotMountImageError : ADBMountedVolumesError
+ (id) errorWithImageURL: (NSURL *)imageURL userInfo: (NSDictionary *)userInfo;

@end


#pragma mark - Implementation

@implementation NSWorkspace (ADBMountedVolumes)

- (NSArray *) mountedVolumeURLsIncludingHidden: (BOOL)hidden
{
    NSVolumeEnumerationOptions options = (hidden) ? 0 : NSVolumeEnumerationSkipHiddenVolumes;
    return [[NSFileManager defaultManager] mountedVolumeURLsIncludingResourceValuesForKeys: nil
                                                                                   options: options];
}

- (NSArray *) mountedVolumeURLsOfType: (NSString *)requiredType includingHidden: (BOOL)hidden
{
    NSAssert(requiredType != nil, @"A volume type must be specified.");
    
	NSArray *volumeURLs		= [self mountedVolumeURLsIncludingHidden: hidden];
	NSMutableArray *matches	= [NSMutableArray arrayWithCapacity: 5];
	
	for (NSURL *volumeURL in volumeURLs)
	{
		NSString *volumeType = [self typeOfVolumeAtURL: volumeURL];
		if ([volumeType isEqualToString: requiredType])
            [matches addObject: volumeURL];
	}
    
	return matches;
}

- (BOOL) isVisibleVolumeAtURL: (NSURL *)URL
{
    NSAssert(URL != nil, @"No URL provided!");
    
    //The NSURLVolumeIsBrowsableKey constant is only supported on 10.7+.
    NSNumber *visibleFlag = nil;
    BOOL checkedVisible = [URL getResourceValue: &visibleFlag forKey: NSURLVolumeIsBrowsableKey error: NULL];
    if (checkedVisible)
        return visibleFlag.boolValue;
    else
        return YES;
}

- (NSString *) typeOfVolumeAtURL: (NSURL *)URL;
{
    NSAssert(URL != nil, @"No URL provided!");
    
    //IMPLEMENTATION NOTE: we stick with the NSWorkspace API for this because as of 10.7, the patchy NSURL API
    //does not provide any way to get for the volume type (just the volume's localized format description).
	NSString *volumeType;
	BOOL retrieved = [self getFileSystemInfoForPath: URL.path
                                        isRemovable: nil
                                         isWritable: nil
                                      isUnmountable: nil
                                        description: nil
                                               type: &volumeType];
	
	return (retrieved) ? volumeType : nil;
}

+ (NSSet *) rawImageTypes
{
    static NSSet *types;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        types = [[NSSet alloc] initWithObjects:
                 @"com.winimage.raw-disk-image",
                 @"com.apple.disk-image-ndif",
                 @"com.microsoft.virtualpc-disk-image",
                 nil];
    });
    return types;
}

- (NSArray *) mountImageAtURL: (NSURL *)URL
                      options: (ADBImageMountingOptions)options
                        error: (out NSError **)outError
{
    BOOL isRawImage = (options & ADBMountRaw);
    if (!isRawImage)
    {
        //hdiutil doesn't recognise these image types automatically,
        //but can handle them if we mount them as raw.
        NSString *rawImageType = [URL matchingFileType: [self.class rawImageTypes]];
        isRawImage = (rawImageType != nil);
    }
	
	NSTask *hdiutil		= [[NSTask alloc] init];
	NSPipe *outputPipe	= [NSPipe pipe];
	NSPipe *errorPipe	= [NSPipe pipe];
    
	NSMutableArray *arguments = @[@"attach", URL.path, @"-plist"].mutableCopy;
    
	//Raw images need additional flags so that hdiutil will recognise them
	if (isRawImage)
	{
		[arguments addObject: @"-imagekey"];
		[arguments addObject: @"diskimage-class=CRawDiskImage"];
	}
	if (options & ADBMountInvisible)
	{
		[arguments addObject: @"-nobrowse"];
	}
	if (options & ADBMountReadOnly)
	{
		[arguments addObject: @"-readonly"];
	}
	
    hdiutil.launchPath = @"/usr/bin/hdiutil";
	hdiutil.arguments = arguments;
    hdiutil.standardOutput = outputPipe;
    hdiutil.standardError = errorPipe;
    
	[hdiutil launch];
	
	//Read off all stdout data (this will block until the task terminates)
	//FIXME: there's a potential deadlock here if errorPipe's buffer
	//fills up: errorPipe will block while it waits for its buffer to clear,
	//but readDataToEndOfFile will keep blocking too.
	NSData *output = [outputPipe.fileHandleForReading readDataToEndOfFile];
	
	//Ensure the task really has finished
	[hdiutil waitUntilExit];
	
	int returnValue = hdiutil.terminationStatus;
    
	//If hdiutil couldn't mount the drive, populate an error object with the details
	if (returnValue > 0)
	{
		NSData *errorData		= [errorPipe.fileHandleForReading readDataToEndOfFile];
		NSString *failureReason	= [[NSString alloc] initWithData: errorData
                                                        encoding: NSUTF8StringEncoding];
		
		NSDictionary *userInfo	= @{ NSLocalizedFailureReasonErrorKey: failureReason };
        
        if (outError)
        {
            *outError = [ADBCouldNotMountImageError errorWithImageURL: URL
                                                             userInfo: userInfo];
        }
		return nil;
	}
	else
	{
		NSDictionary *hdiInfo = [NSPropertyListSerialization propertyListWithData: output
                                                                          options: NSPropertyListImmutable
                                                                           format: NULL
                                                                            error: outError];
        if (!hdiInfo)
            return nil;
        
		NSArray *mountPoints = [hdiInfo objectForKey: @"system-entities"];
        NSMutableArray *mountedVolumeURLs = [NSMutableArray arrayWithCapacity: mountPoints.count];
		for (NSDictionary *mountPoint in mountPoints)
		{
			//Return the first mount point that has a valid volume path.
			NSString *destination = [mountPoint objectForKey: @"mount-point"];
			if (destination)
            {
                [mountedVolumeURLs addObject: [NSURL fileURLWithPath: destination isDirectory: YES]];
            }
		}
        return mountedVolumeURLs;
	}
}

//Return the currently-mounted images as reported by hdiutil in plist format.
//Returns nil and populates outError if the data could not be retrieved.
- (NSArray *) mountedImageInfoWithError: (out NSError **)outError
{
	NSTask *hdiutil = [[NSTask alloc] init];
	NSPipe *outputPipe = [NSPipe pipe];
    NSPipe *errorPipe = [NSPipe pipe];
	
    hdiutil.launchPath = @"/usr/bin/hdiutil";
    hdiutil.arguments = @[@"info", @"-plist"];
    hdiutil.standardOutput = outputPipe;
    hdiutil.standardError = errorPipe;
	
	[hdiutil launch];
	
	NSData *output = [outputPipe.fileHandleForReading readDataToEndOfFile];
	
	[hdiutil waitUntilExit];
    
	int returnValue = hdiutil.terminationStatus;
    
    if (returnValue > 0)
    {
        if (outError)
        {
            NSData *errorData		= [errorPipe.fileHandleForReading readDataToEndOfFile];
            NSString *failureReason	= [[NSString alloc] initWithData: errorData
                                                            encoding: NSUTF8StringEncoding];
            
            NSDictionary *userInfo	= @{ NSLocalizedFailureReasonErrorKey: failureReason };
            
            *outError = [ADBMountedVolumesError errorWithDomain: ADBMountedVolumesErrorDomain
                                                           code: ADBMountedVolumesHDIUtilInfoFailed
                                                       userInfo: userInfo];
        }
        return nil;
    }
    else
    {
        NSDictionary *hdiInfo = [NSPropertyListSerialization propertyListWithData: output
                                                                          options: NSPropertyListImmutable
                                                                           format: NULL
                                                                            error: outError];
        
        if (hdiInfo)
            return [hdiInfo objectForKey: @"images"];
        else
            return nil;
    }
}

- (NSURL *) sourceImageForVolumeAtURL: (NSURL *)volumeURL
{
    NSURL *resolvedURL = volumeURL.URLByResolvingSymlinksInPath;
    
    //Preflight checks: if the URL doesn't exist or doesn't represent
    //the root of a volume, don't bother checking further.
    //(This is important because scanning for image mounts can be time-consuming and will block.)
    if (![resolvedURL checkResourceIsReachableAndReturnError: NULL])
        return nil;

    NSNumber *isVolumeFlag = nil;
    BOOL checkedVolume = [resolvedURL getResourceValue: &isVolumeFlag
                                                forKey: NSURLIsVolumeKey
                                                 error: NULL];
    if (!checkedVolume || !isVolumeFlag.boolValue)
        return nil;
    
    NSString *resolvedPath = resolvedURL.path;
    NSArray *mountedImages = [self mountedImageInfoWithError: NULL];
    for (NSDictionary *imageInfo in mountedImages)
    {
        for (NSDictionary *mountPointInfo in [imageInfo objectForKey: @"system-entities"])
        {
            NSString *destinationPath = [mountPointInfo objectForKey: @"mount-point"];
            
            if ([resolvedPath isEqualToString: destinationPath])
            {
                NSString *sourcePath = [imageInfo objectForKey: @"image-path"];
                if (sourcePath)
                {
                    return [NSURL fileURLWithPath: sourcePath];
                }
            }
        }
    }
    
    //If we got this far, we couldn't find a match so this isn't an image-based volume.
	return nil;
}

- (NSArray *) mountedVolumeURLsForSourceImageAtURL: (NSURL *)imageURL
{
    NSURL *resolvedURL = imageURL.URLByResolvingSymlinksInPath;
    NSString *resolvedPath = resolvedURL.path;
	NSArray *mountedImages = [self mountedImageInfoWithError: NULL];
	
    NSMutableArray *mountedVolumes = [NSMutableArray arrayWithCapacity: 1];
	for (NSDictionary *imageInfo in mountedImages)
	{
		NSString *sourcePath = [[imageInfo objectForKey: @"image-path"] stringByStandardizingPath];
		if ([resolvedPath isEqualToString: sourcePath])
		{
			//For multi-volume images, only return the first mount-point listed in the set.
            NSArray *entities = [imageInfo objectForKey: @"system-entities"];
            for (NSDictionary *mountPointInfo in entities)
            {
                NSString *destinationPath = [mountPointInfo objectForKey: @"mount-point"];
                if (destinationPath)
                {
                    [mountedVolumes addObject: [NSURL fileURLWithPath: destinationPath]];
                }
            }
            //TODO: break after the first volume we find?
            //Does hdiutil allow an image to be mounted multiple times?
		}
	}
	return mountedVolumes;
}

//Returns the BSD device name (dev/diskXsY) for the specified volume.
//Returns nil if no matching device name could be determined.
- (NSString *) BSDDeviceNameForVolumeAtURL: (NSURL *)volumeURL
{
	NSString *deviceName = nil;
	struct statfs fs;
	
	if (statfs(volumeURL.fileSystemRepresentation, &fs) == ERR_SUCCESS)
	{
		NSFileManager *manager = [NSFileManager defaultManager];
		deviceName = [manager stringWithFileSystemRepresentation: fs.f_mntfromname
                                                          length: strlen(fs.f_mntfromname)];
	}
	return deviceName;
}

//IMPLEMENTATION NOTE: this pair of methods relies on the fact that in OSX, data+audio CDs
//are mounted as BSD devices with a specific structure:
//dev/diskX: audio volume
//dev/diskXs1: ISO data volume
//Thus, we can match up audio volumes with data volumes just by checking if the data
//volume's device name has the audio volume's device name as a prefix.
- (NSURL *) dataVolumeOfAudioCDAtURL: (NSURL *)audioCDURL
{
	NSString *audioDeviceName	= [self BSDDeviceNameForVolumeAtURL: audioCDURL];
	NSArray *dataVolumes		= [self mountedVolumeURLsOfType: ADBDataCDVolumeType includingHidden: YES];
	
	for (NSURL *dataVolumeURL in dataVolumes)
	{
		NSString *dataDeviceName = [self BSDDeviceNameForVolumeAtURL: dataVolumeURL];
		if ([dataDeviceName hasPrefix: audioDeviceName])
            return dataVolumeURL;
	}
	return nil;
}

- (NSURL *) audioVolumeOfDataCDAtURL: (NSURL *)dataCDURL;
{
	NSString *dataDeviceName	= [self BSDDeviceNameForVolumeAtURL: dataCDURL];
	NSArray *audioVolumes		= [self mountedVolumeURLsOfType: ADBAudioCDVolumeType includingHidden: YES];
	
	for (NSURL *audioVolumeURL in audioVolumes)
	{
		NSString *audioDeviceName = [self BSDDeviceNameForVolumeAtURL: audioVolumeURL];
		if ([dataDeviceName hasPrefix: audioDeviceName])
            return audioVolumeURL;
	}
	return nil;
}

- (BOOL) isHybridCDAtURL: (NSURL *)volumeURL
{
    return ([self BSDDeviceNameForISOVolumeOfHybridCDAtURL: volumeURL] != nil);
}

- (NSString *) BSDDeviceNameForISOVolumeOfHybridCDAtURL: (NSURL *)volumeURL
{
    BOOL isRemovable, isWriteable;
    NSString *fsType;
    
    if (![self getFileSystemInfoForPath: volumeURL.path
                            isRemovable: &isRemovable
                             isWritable: &isWriteable
                          isUnmountable: NULL
                            description: NULL
                                   type: &fsType])
        return nil;
    
    //The Mac part of the hybrid CD is expected to be removable,
    //read-only, and have an HFS filesystem. If not, it's probably
    //not a hybrid CD.
    if (!(isRemovable && !isWriteable && [fsType isEqualToString: ADBHFSVolumeType]))
        return nil;
    
    //If the CDROM has a corresponding ISO9660 volume,
    //then it should have a very particular device-name layout:
    //diskXs1: ISO volume
    //diskXs1s1 apple partition map
    //diskXs1s2 HFS volume (the one we're looking at)
    NSString *BSDName = [self BSDDeviceNameForVolumeAtURL: volumeURL];
    NSString *isoSuffix = @"s1";
    NSString *hfsSuffix = @"s1s2";
    
    if (![BSDName hasSuffix: hfsSuffix])
        return nil;
    
    NSString *baseName = [BSDName substringToIndex: BSDName.length - hfsSuffix.length];
    return [baseName stringByAppendingString: isoSuffix];
}


- (BOOL) isFloppyVolumeAtURL: (NSURL *)volumeURL
{
    NSString *volumeType = [self typeOfVolumeAtURL: volumeURL];
    if (![volumeType isEqualToString: ADBFATVolumeType])
        return NO;
    
    NSNumber *filesystemSize = nil;
    BOOL gotSize = [volumeURL getResourceValue: &filesystemSize
                                        forKey: NSURLVolumeTotalCapacityKey
                                         error: NULL];
    
    if (!gotSize || !filesystemSize)
        return NO;
    
    return (filesystemSize.unsignedLongLongValue <= ADBFloppySizeCutoff);
}

@end



@implementation NSWorkspace (ADBMountedVolumesLegacyPathAPI)

- (NSArray *) mountedVolumesOfType: (NSString *)requiredType includingHidden: (BOOL)hidden
{
    NSArray *matchingVolumeURLs = [self mountedVolumeURLsOfType: requiredType includingHidden: hidden];
    return [matchingVolumeURLs valueForKey: @"path"];
}

- (NSArray *) mountedLocalVolumePathsIncludingHidden: (BOOL)hidden
{
    NSArray *volumeURLs = [self mountedVolumeURLsIncludingHidden: hidden];
    return [volumeURLs valueForKey: @"path"];
}

- (BOOL) volumeIsVisibleAtPath: (NSString *)path
{
    return [self isVisibleVolumeAtURL: [NSURL fileURLWithPath: path]];
}

- (NSString *) volumeTypeForPath: (NSString *)path
{
    return [self typeOfVolumeAtURL: [NSURL fileURLWithPath: path]];
}

- (NSString *) volumeForPath: (NSString *)path
{
    NSURL *URL = [NSURL fileURLWithPath: path];
    NSURL *volumeURL = nil;
    BOOL gotVolume = [URL getResourceValue: &volumeURL forKey: NSURLVolumeURLKey error: NULL];
    
    if (gotVolume)
        return volumeURL.path;
    else
        return nil;
}

- (NSString *) mountImageAtPath: (NSString *)path
					   readOnly: (BOOL)readOnly
					  invisibly: (BOOL)invisible
						  error: (NSError **)outError
{
    ADBImageMountingOptions options = 0;
    if (readOnly)   options |= ADBMountReadOnly;
    if (invisible)  options |= ADBMountInvisible;
    
    NSArray *mountedURLs = [self mountImageAtURL: [NSURL fileURLWithPath: path]
                                         options: options
                                           error: outError];

    if (mountedURLs.count)
        return [(NSURL *)[mountedURLs objectAtIndex: 0] path];
    else
        return nil;
}

- (NSString *) sourceImageForVolume: (NSString *)volumePath
{
    NSURL *volumeURL = [NSURL fileURLWithPath: volumePath];
    NSURL *imageURL = [self sourceImageForVolumeAtURL: volumeURL];
    return imageURL.path;
}

- (NSString *) volumeForSourceImage: (NSString *)imagePath
{
    NSURL *imageURL = [NSURL fileURLWithPath: imagePath];
    NSArray *volumes = [self mountedVolumeURLsForSourceImageAtURL: imageURL];
    if (volumes.count)
        return [(NSURL *)[volumes objectAtIndex: 0] path];
    else
        return nil;
}

- (NSString *) dataVolumeOfAudioCD: (NSString *)audioVolumePath
{
    NSURL *audioVolumeURL = [NSURL fileURLWithPath: audioVolumePath];
    NSURL *dataVolumeURL = [self dataVolumeOfAudioCDAtURL: audioVolumeURL];
    return dataVolumeURL.path;
}

- (NSString *) audioVolumeOfDataCD: (NSString *)dataVolumePath
{
    NSURL *dataVolumeURL = [NSURL fileURLWithPath: dataVolumePath];
    NSURL *audioVolumeURL = [self audioVolumeOfDataCDAtURL: dataVolumeURL];
    return audioVolumeURL.path;
}

- (BOOL) isFloppyVolumeAtPath: (NSString *)path
{
    return [self isFloppyVolumeAtURL: [NSURL fileURLWithPath: path]];
}

- (BOOL) isFloppySizedVolumeAtPath: (NSString *)path
{
	NSFileManager *manager = [NSFileManager defaultManager];
	NSDictionary *fsAttrs = [manager attributesOfFileSystemForPath: path error: nil];
	unsigned long long volumeSize = [[fsAttrs valueForKey: NSFileSystemSize] unsignedLongLongValue];
	return volumeSize <= ADBFloppySizeCutoff;
}

@end


@implementation ADBMountedVolumesError
@end


@implementation ADBCouldNotMountImageError

+ (id) errorWithImageURL: (NSURL *)imageURL
                userInfo: (NSDictionary *)userInfo
{
	NSString *descriptionFormat = NSLocalizedString(@"The disk image “%@” could not be opened.",
                                                    @"Error message shown after failing to mount an image. %@ is the display name of the disk image."
                                                    );
	
	NSString *explanation = NSLocalizedString(@"The disk image file may be corrupted or incomplete.",
                                              @"Explanatory text for error message shown after failing to mount an image."
                                              );
	
	NSString *displayName = nil;
    BOOL gotDisplayName = [imageURL getResourceValue: &displayName forKey: NSURLLocalizedNameKey error: NULL];
    if (!gotDisplayName)
        displayName = imageURL.lastPathComponent;
	
	NSString *description = [NSString stringWithFormat: descriptionFormat, displayName];
	
	NSMutableDictionary *defaultInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										description,	NSLocalizedDescriptionKey,
										explanation,	NSLocalizedRecoverySuggestionErrorKey,
										imageURL,		NSURLErrorKey,
                                        imageURL.path,  NSFilePathErrorKey, //For legacy code
										nil];
	
	if (userInfo) [defaultInfo addEntriesFromDictionary: userInfo];
	
	return [self errorWithDomain: ADBMountedVolumesErrorDomain
							code: ADBMountedVolumesHDIUtilAttachFailed
						userInfo: defaultInfo];
}

@end
