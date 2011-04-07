/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "NSWorkspace+BXMountedVolumes.h"
#import "NSWorkspace+BXFileTypes.h"
#import "NSString+BXPaths.h"
#import "BXMountedVolumesError.h"
#include <sys/mount.h>

#pragma mark -
#pragma mark Class constants

NSString * const dataCDVolumeType	= @"cd9660";
NSString * const audioCDVolumeType	= @"cddafs";
NSString * const FATVolumeType		= @"msdos";
NSString * const HFSVolumeType		= @"hfs";


//FAT volumes smaller than 2MB will be treated as floppy drives by isFloppyDriveAtPath.
#define BXFloppySizeCutoff 2 * 1024 * 1024;


@implementation NSWorkspace (BXMountedVolumes)

- (NSArray *) mountedVolumesOfType: (NSString *)requiredType
{
	NSArray *volumes		= [self mountedLocalVolumePaths];
	NSMutableArray *matches	= [NSMutableArray arrayWithCapacity: 5];
	
	NSString *volumePath, *volumeType;
	
	for (volumePath in volumes)
	{
		volumeType = [self volumeTypeForPath: volumePath];
		if ([volumeType isEqualToString: requiredType]) { [matches addObject: volumePath]; }
	}
	return matches;
}

- (NSString *) volumeTypeForPath: (NSString *)path
{
	NSString *volumeType = nil;
	[self getFileSystemInfoForPath: path
					   isRemovable: nil
						isWritable: nil
					 isUnmountable: nil
					   description: nil
							  type: &volumeType];
	
	return volumeType;
}

- (NSString *) volumeForPath: (NSString *)path
{
	NSString *resolvedPath	= [path stringByStandardizingPath];
	NSArray *volumes		= [self mountedLocalVolumePaths];
	
	//Sort the volumes by length from longest to shortest, to make sure we get the right volume (and not a parent volume)
	NSArray *sortedVolumes	= [volumes sortedArrayUsingSelector: @selector(pathDepthCompare:)];
	
	for (NSString *volumePath in [sortedVolumes reverseObjectEnumerator])
	{
		if ([resolvedPath hasPrefix: volumePath]) return volumePath;
	}
	return nil;
}

- (NSString *) mountImageAtPath: (NSString *)path
					   readOnly: (BOOL)readOnly
					  invisibly: (BOOL)invisible
						  error: (NSError **)error
{
	path = [path stringByStandardizingPath];
	BOOL isRawImage = [self file: path matchesTypes: [NSSet setWithObject: @"com.winimage.raw-disk-image"]];
	
	NSTask *hdiutil		= [[NSTask alloc] init];
	NSPipe *outputPipe	= [NSPipe pipe];
	NSPipe *errorPipe	= [NSPipe pipe];
	NSData *output;
	NSDictionary *hdiInfo;
	
	NSMutableArray *arguments = [NSMutableArray arrayWithObjects: @"attach", path, @"-plist", nil];
	//Raw images need additional flags so that hdiutil will recognise them
	if (isRawImage)
	{
		[arguments addObject: @"-imagekey"];
		[arguments addObject: @"diskimage-class=CRawDiskImage"];
	}
	if (invisible)
	{
		[arguments addObject: @"-nobrowse"];
	}
	if (readOnly)
	{
		[arguments addObject: @"-readonly"];
	}
	
	[hdiutil setLaunchPath:		@"/usr/bin/hdiutil"];
	[hdiutil setArguments:		arguments];
	[hdiutil setStandardOutput: outputPipe];
	[hdiutil setStandardError: errorPipe];
	
	[hdiutil launch];
	[hdiutil waitUntilExit];
	
	int returnValue = [hdiutil terminationStatus];
	
	[hdiutil release];
	
	//If hdiutil couldn't mount the drive, populate an error object with the details
	if (returnValue > 0)
	{
		NSData *errorData		= [[errorPipe fileHandleForReading] availableData];
		NSString *failureReason	= [[NSString alloc] initWithData: errorData encoding: NSUTF8StringEncoding];
		
		NSDictionary *userInfo	= [NSDictionary dictionaryWithObject: failureReason forKey: NSLocalizedFailureReasonErrorKey];
		[failureReason release];
		
		*error = [BXCouldNotMountImageError errorWithImagePath: path userInfo: userInfo];
		
		return nil;
	}
	
	output	= [[outputPipe fileHandleForReading] availableData];
	hdiInfo	= [NSPropertyListSerialization propertyListFromData: output
											   mutabilityOption: NSPropertyListImmutable
														 format: nil
											   errorDescription: nil];
	
	NSArray *mountPoints = [hdiInfo objectForKey: @"system-entities"];
	for (NSDictionary *mountPoint in mountPoints)
	{
		//Return the first mount point that has a valid volume path
		NSString *destination = [[mountPoint objectForKey: @"mount-point"] stringByStandardizingPath];
		if (destination) return destination;
	}
	//TODO: if no mount points were found, populate an error to that effect
	return nil;
}

- (NSString *) sourceImageForVolume: (NSString *)volumePath
{
	NSString *resolvedPath	= [volumePath stringByStandardizingPath];
	
	//Optimisation: if the path is not in mountedRemovableMedia,
	//assume it doesn't have a source image and don't check further
	NSArray *removableMedia = [self mountedRemovableMedia];
	if ([removableMedia containsObject: resolvedPath])
	{
		NSArray *mountedImages = [self mountedImages];	
		
		NSDictionary *imageInfo, *mountPoint;
		NSArray *mountPoints;
		NSString *source, *destination;
		
		for (imageInfo in mountedImages)
		{
			source		= [imageInfo objectForKey: @"image-path"];
			mountPoints	= [imageInfo objectForKey: @"system-entities"];
			for (mountPoint in mountPoints)
			{
				destination = [[mountPoint objectForKey: @"mount-point"] stringByStandardizingPath];
				if ([resolvedPath isEqualToString: destination]) return source;
			}
		}
	}
	return nil;
}


//Return the currently-mounted images reported by hdiutil
//Todo: cache this data for n seconds, to avoid slow calls to hdiutil
- (NSArray *) mountedImages
{
	NSTask *hdiutil		= [[NSTask alloc] init];
	NSPipe *outputPipe	= [NSPipe pipe];
	NSData *output;
	NSDictionary *hdiInfo;
	
	[hdiutil setLaunchPath:		@"/usr/bin/hdiutil"];
	[hdiutil setArguments:		[NSArray arrayWithObjects: @"info", @"-plist", nil]];
	[hdiutil setStandardOutput: outputPipe];
	
	[hdiutil launch];
	[hdiutil waitUntilExit];
	
	[hdiutil release];
	
	output	= [[outputPipe fileHandleForReading] availableData];
	hdiInfo	= [NSPropertyListSerialization propertyListFromData: output
											   mutabilityOption: NSPropertyListImmutable
														 format: nil
											   errorDescription: nil];

	return [hdiInfo objectForKey: @"images"];
}

- (NSString *) dataVolumeOfAudioCD: (NSString *)audioVolumePath
{
	audioVolumePath				= [audioVolumePath stringByStandardizingPath];
	NSString *audioDeviceName	= [self BSDNameForVolumePath: audioVolumePath];
	NSArray *dataVolumes		= [self mountedVolumesOfType: dataCDVolumeType];
	
	for (NSString *dataVolumePath in dataVolumes)
	{
		NSString *dataDeviceName = [self BSDNameForVolumePath: dataVolumePath];
		if ([dataDeviceName hasPrefix: audioDeviceName]) return dataVolumePath;
	}
	return nil;
}

- (NSString *) audioVolumeOfDataCD: (NSString *)dataVolumePath
{
	dataVolumePath				= [dataVolumePath stringByStandardizingPath];
	NSString *dataDeviceName	= [self BSDNameForVolumePath: dataVolumePath];
	NSArray *audioVolumes		= [self mountedVolumesOfType: audioCDVolumeType];
	
	for (NSString *audioVolumePath in audioVolumes)
	{
		NSString *audioDeviceName = [self BSDNameForVolumePath: audioVolumePath];
		if ([dataDeviceName hasPrefix: audioDeviceName]) return audioVolumePath;
	}
	return nil;
}

//Returns the BSD device name (dev/diskXsY) for the specified volume. Returns nil if no matching device name could be determined.
- (NSString *) BSDNameForVolumePath: (NSString *)volumePath
{
	NSString *deviceName = nil;
	struct statfs fs;
	
	if (statfs([volumePath fileSystemRepresentation], &fs) == ERR_SUCCESS)
	{
		NSFileManager *manager	= [NSFileManager defaultManager];
		deviceName = [manager stringWithFileSystemRepresentation: fs.f_mntfromname length: strlen(fs.f_mntfromname)];
	}
	return deviceName;
}

- (BOOL) isFloppyVolumeAtPath: (NSString *)path
{
	if (![[self volumeTypeForPath: path] isEqualToString: FATVolumeType]) return NO;

	return [self isFloppySizedVolumeAtPath: path];
}

- (BOOL) isFloppySizedVolumeAtPath: (NSString *)path
{
	NSFileManager *manager = [NSFileManager defaultManager];
	NSDictionary *fsAttrs = [manager attributesOfFileSystemForPath: path error: nil];
	unsigned long long volumeSize = [[fsAttrs valueForKey: NSFileSystemSize] unsignedLongLongValue];
	return volumeSize <= BXFloppySizeCutoff;	
}

@end
