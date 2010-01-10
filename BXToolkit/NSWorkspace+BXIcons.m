/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "NSWorkspace+BXIcons.h"


@implementation NSWorkspace (BXIcons)

- (BOOL) fileHasCustomIcon: (NSString *)path
{
    FSRef fileRef;
    struct FSCatalogInfo catInfo;
    struct FileInfo *finderInfo = (struct FileInfo *)&catInfo.finderInfo;
	
	//Get an FSRef filesystem reference to the specified path
	BOOL gotFileRef = CFURLGetFSRef((CFURLRef)[NSURL fileURLWithPath: path], &fileRef);
	//Bail out if we couldn't resolve an FSRef
	if (!gotFileRef) return NO;
		
	//Retrieve the Finder catalog info for the file
    OSStatus result = FSGetCatalogInfo(	&fileRef,
									   kFSCatInfoFinderInfo,
									   &catInfo,
									   NULL,
									   NULL,
									   NULL);
    if (result != noErr) return NO;
	
	//Return whether the custom icon bit has been set
    return (finderInfo->finderFlags & kHasCustomIcon) == kHasCustomIcon;
}
@end