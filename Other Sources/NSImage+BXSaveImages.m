/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "NSImage+BXSaveImages.h"


@implementation NSImage (BXSaveImages)

- (BOOL) saveToPath: (NSString *)path
		   withType: (NSBitmapImageFileType)type
		 properties: (NSDictionary *)properties
			  error: (NSError **)outError
{
	NSBitmapImageRep *rep = (NSBitmapImageRep *)[self bestRepresentationForDevice: nil];
	
	//If the image representation is not actually an NSBitmapImageRep,
	//(e.g. it's vector data) then create one from the TIFF data.
	//FIXME: this will be needlessly slow
	if (![rep isKindOfClass: [NSBitmapImageRep class]])
	{
		rep = [NSBitmapImageRep imageRepWithData: [self TIFFRepresentation]];
	}
	
	NSData *data = [rep representationUsingType: type properties: nil];
	return [data writeToFile: path options: NSAtomicWrite error: outError];
}

@end
