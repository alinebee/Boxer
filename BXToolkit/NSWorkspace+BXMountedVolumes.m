/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "NSWorkspace+BXMountedVolumes.h"
#import "NSString+BXPaths.h"
#include <sys/param.h>
#include <sys/mount.h>

NSString * const dataCDVolumeType	= @"cd9660";
NSString * const audioCDVolumeType	= @"cddafs";
NSString * const FATVolumeType		= @"msdos";
NSString * const HFSVolumeType		= @"hfs";


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
	hdiInfo	= [NSPropertyListSerialization	propertyListFromData: output
											mutabilityOption: NSPropertyListImmutable
											format: nil errorDescription: nil];

	return [hdiInfo objectForKey: @"images"];
}

//Returns the path of the data volume associated with the specified CD volume path.
//Returns nil if the CD volume has no corresponding data volume.
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

@end