/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXISOImport rips physical CDs to (CDR-format) ISO disc images using OS X's hdiutil.

#import "BXDriveImport.h"

@interface BXISOImport : BXOperation <BXDriveImport>
{
	@private
	BXDrive *_drive;
	unsigned long long _numBytes;
	unsigned long long _bytesTransferred;
	BXOperationProgress _currentProgress;
	BOOL _indeterminate;
	NSString *_destinationFolder;
	NSString *_importedDrivePath;
	
	NSTimeInterval _pollInterval;
}

//The interval at which to check the progress of the image creation
//and issue overall progress updates.
//Our overall running time will be a multiple of this interval.
@property (assign) NSTimeInterval pollInterval;

@end
