/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXDriveImport is a simple extension of BXFileTransfer specifically to handle importing BXDrives.

#import "BXFileTransfer.h"

@class BXDrive;

@interface BXDriveImport : BXFileTransfer

#pragma mark -
#pragma mark Helper class methods

//Returns a suitable name under which to store the specified drive,
//using the standard format for Boxer mountable folders.
+ (NSString *) nameForDrive: (BXDrive *)drive;

#pragma mark -
#pragma mark Initializers

//Create/initialize a new drive import operation for the specified drive to the specified destination
//folder/gamebox. These will set drive to be the context info for the transfer.
//Unlike BXFileTransfer, destination should be the base folder and not the whole path: the destination
//filename will be determined automatically from the drive details, using +nameForDrive:.
+ (id) importForDrive: (BXDrive *)drive toFolder: (NSString *)destination copyFiles: (BOOL)copy;
- (id) initForDrive: (BXDrive *)drive toFolder: (NSString *)destination copyFiles: (BOOL)copy;

@end