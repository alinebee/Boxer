/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "IconFamily+BXIconFamily.h"
#import "NSString+CarbonFSRefCreation.h"

@implementation IconFamily (BXIconFamily)

+ (IconFamily *) iconFamilyWithRepresentationsFromImage: (NSImage *)image
{
	IconFamily *family	= [self iconFamily];
	
	for (NSBitmapImageRep *rep in [image representations])
	{
		//Skip non-bitmap reps altogether for now
		if (![rep isKindOfClass: [NSBitmapImageRep class]]) continue;
		
		NSSize size = [rep size];
		
		OSType elementType, maskType;
		NSInteger intHeight = (NSInteger)(size.height + 0.5);
		switch (intHeight)
		{
			case 512:	elementType = kIconServices512PixelDataARGB;	maskType = 0; break;
			case 256:	elementType = kIconServices256PixelDataARGB;	maskType = 0; break;
			case 128:	elementType = kThumbnail32BitData;				maskType = kThumbnail8BitMask; break;	
			case 32:	elementType = kLarge32BitData;					maskType = kLarge8BitMask; break;
			case 16:	elementType = kSmall32BitData;					maskType = kSmall8BitMask; break;
			default:	continue; //No suitable icon size found, skip this one
		}
		
		[family setIconFamilyElement: elementType fromBitmapImageRep: rep];
		if (maskType) [family setIconFamilyElement: maskType fromBitmapImageRep: rep];
	}
	return family;
}

//Most of this code was copy-pasted from removeCustomIconFromFile:
+ (BOOL) fileHasCustomIcon: (NSString *)path
{
    FSRef targetFileFSRef;
    struct FSCatalogInfo catInfo;
    struct FileInfo *finderInfo = (struct FileInfo *)&catInfo.finderInfo;

    //Get an FSRef for the target file
    if (![path getFSRef:&targetFileFSRef createFileIfNecessary:NO]) return NO;
		
	//Retrieve the Finder catalog info for the file
    OSStatus result = FSGetCatalogInfo(	&targetFileFSRef,
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
