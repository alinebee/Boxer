/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//The BXMountedVolumes category adds methods to NSWorkspace to retrieve all volumes of a certain type,
//and to determine the source image for a mounted volume using HDIUtil.

#import <Cocoa/Cocoa.h>


//Filesystem types, for use with mountedVolumesOfType:
extern NSString * const dataCDVolumeType;
extern NSString * const audioCDVolumeType;
extern NSString * const FATVolumeType;
extern NSString * const HFSVolumeType;


@interface NSWorkspace (BXMountedVolumes)

//Returns an array of visible locally mounted volumes.
//If hidden is YES, or on 10.5, this will also include invisible volumes.
- (NSArray *) mountedLocalVolumePathsIncludingHidden: (BOOL)hidden;

//Returns whether the volume at the specified file path is visible in Finder.
//If this is NO, it means the volume has been mounted hidden (and should probably be ignored.)
- (BOOL) volumeIsVisibleAtPath: (NSString *)path;

//Returns all mounted filesystems of the specified filesystem type.
//If hidden is YES, or on 10.5, this will also include invisible volumes.
- (NSArray *) mountedVolumesOfType: (NSString *)volumeType includingHidden: (BOOL)hidden;

//Returns the underlying filesystem type of the specified path.
- (NSString *) volumeTypeForPath: (NSString *)path;

//Return the base volume path upon which the specified path resides.
- (NSString *) volumeForPath: (NSString *)path;

//Returns the path to the source disk image from which the specified volume path was created.
//Returns nil if the source image could not be determined (e.g. if the volume is not mounted from a disk image)
- (NSString *) sourceImageForVolume: (NSString *)volumePath;

//Returns the first path at which the specified source disk image is mounted.
//Returns nil if the source image is not currently mounted.
- (NSString *) volumeForSourceImage: (NSString *)imagePath;

//Mounts the disk image at the specified path, and returns the path to the newly-mounted volume if successful.
//Returns nil and populates error if mounting failed.
//If invisible is true, the mounted volume will not appear in Finder.
- (NSString *) mountImageAtPath: (NSString *)path
					   readOnly: (BOOL)readOnly
					  invisibly: (BOOL)invisible
						  error: (NSError **)error;

//Returns an array of NSDictionaries containing details about each mounted image volume, as reported by hdiutil.
//This data is used by sourceImageForPath: and is probably not much use otherwise.
- (NSArray *) mountedImages;

//Returns the path of the data volume associated with the specified CD volume path.
//Returns nil if the CD volume has no corresponding data volume.
- (NSString *) dataVolumeOfAudioCD: (NSString *)volumePath;

//Returns the path of the audio CD volume associated with the specified data CD volume path.
//Returns nil if the CD volume has no corresponding audio volume.
- (NSString *) audioVolumeOfDataCD: (NSString *)volumePath;

//Returns the BSD device name (dev/diskXsY) for the specified volume.
//Returns nil if no matching device name could be determined.
- (NSString *) BSDNameForVolumePath: (NSString *)volumePath;

//Returns whether the specified volume is actually a DOS floppy disk.
- (BOOL) isFloppyVolumeAtPath: (NSString *)volumePath;

//Returns whether the specified volume is the size of a DOS floppy disk.
- (BOOL) isFloppySizedVolumeAtPath: (NSString *)volumePath;

//When given a path to the HFS volume of a hybrid Mac+PC CD, returns the BSD device name
//of the corresponding ISO volume. Returns nil if the path was not a hybrid CD or no
//matching device name could be determined.
- (NSString *) BSDNameForISOVolumeOfHybridCD: (NSString *)volumePath;

//Returns YES if the specified path points to the HFS volume of a hybrid Mac+PC CD,
//NO otherwise.
- (BOOL) isHybridCDAtPath: (NSString *)volumePath;

@end
