/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXMountedVolumesError defines errors for NSWorkspace+BXMountedVolumes errors.

#import <Cocoa/Cocoa.h>


//Error domains and userInfo keys
extern NSString * const BXMountedVolumesErrorDomain;

//Mount-related error codes
enum
{
	//Produced when hdiutil cannot mount the image passed to mountImageAtPath:error:
	BXMountedVolumesHDIUtilAttachFailed
};


@interface BXMountedVolumesError : NSError
@end

@interface BXCouldNotMountImageError : BXMountedVolumesError
+ (id) errorWithImagePath: (NSString *)imagePath userInfo: (NSDictionary *)userInfo;
@end