/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */



#import "BXMultiFileTransfer.h"
#import "BXDriveImport.h"

@interface BXDriveBundleImport : BXMultiFileTransfer <BXFileTransfer, BXDriveImport>
{
	@private
	BXDrive *_drive;
	NSString *_destinationFolder;
	NSString *_importedDrivePath;
}

@end
