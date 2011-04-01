/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
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
//Returns all mounted filesystems of the specified filesystem type.
- (NSArray *) mountedVolumesOfType: (NSString *)volumeType;

//Returns the underlying filesystem type of the specified path.
- (NSString *) volumeTypeForPath: (NSString *)path;

//Return the base volume path upon which the specified path resides.
- (NSString *) volumeForPath: (NSString *)path;

//Returns the path to the source disk image from which the specified volume path was created.
//Returns nil if the source image could not be determined (e.g. if the volume is not mounted from a disk image)
- (NSString *) sourceImageForVolume: (NSString *)volumePath;

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

//Returns the BSD device name (dev/diskXsY) for the specified volume.
//Returns nil if no matching device name could be determined.
- (NSString *) BSDNameForVolumePath: (NSString *)volumePath;

//Returns whether the specified volume is actually a DOS floppy disk.
- (BOOL) isFloppyVolumeAtPath: (NSString *)volumePath;

//Returns whether the specified volume is the size of a DOS floppy disk.
- (BOOL) isFloppySizedVolumeAtPath: (NSString *)path;

@end
