/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXFileTransfer.h"

@class BXDrive;

@protocol BXDriveImport <BXFileTransfer>

//The drive to import
@property (retain) BXDrive *drive;

//The base folder into which to import the drive to.
//This does not include the destination drive name, which will be determined automatically
//from the drive being imported.
@property (copy) NSString *destinationFolder;

//The path of the new drive once it is finally imported.
@property (copy, readonly) NSString *importedDrivePath;

//Return a suitably initialized BXOperation subclass for transferring the drive.
+ (id <BXDriveImport>) importForDrive: (BXDrive *)drive
						toDestination: (NSString *)destinationFolder
							copyFiles: (BOOL)copyFiles;

- (id <BXDriveImport>) initForDrive: (BXDrive *)drive
					  toDestination: (NSString *)destinationFolder
						  copyFiles: (BOOL)copyFiles;
@end