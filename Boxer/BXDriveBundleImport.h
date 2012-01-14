/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXDriveBundleImport wraps BIN/CUE images and any associated audio tracks into a .cdmedia bundle,
//rewriting cue paths as necessary.

#import "BXFileTransferSet.h"
#import "BXDriveImport.h"

//Domain and constants for errors encountered during disc-image ripping
extern NSString * const BXDriveBundleErrorDomain;

enum {
	BXDriveBundleCouldNotParseCue //Could not rip the cue file to determine source files
};


@interface BXDriveBundleImport : BXFileTransferSet <BXDriveImport>
{
	BXDrive *_drive;
	NSString *_destinationFolder;
	NSString *_importedDrivePath;
}

@end


@interface BXDriveBundleCueParseError : NSError <BXDriveImportError>
@end
