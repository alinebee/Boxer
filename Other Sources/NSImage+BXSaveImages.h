/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Cocoa/Cocoa.h>

//The BXSaveImages category adds convenience methods for saving an NSImage directly to a file.

@interface NSImage (BXSaveImages)

//Convenience method to save an image to the specified path with the specified filetype.
//Returns YES if file was saved successfully, or NO and populates outError if there was an error.
- (BOOL) saveToPath: (NSString *)path
		   withType: (NSBitmapImageFileType)type
		 properties: (NSDictionary *)properties
			  error: (NSError **)outError;

@end
