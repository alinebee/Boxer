/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "ADBFileTransferSet.h"
#import "BXDriveImport.h"

/// Domain and constants for errors encountered during disc-image ripping
extern NSErrorDomain const BXDriveBundleErrorDomain;

NS_ERROR_ENUM(BXDriveBundleErrorDomain) {
	BXDriveBundleCouldNotParseCue //Could not rip the cue file to determine source files
};


/// BXDriveBundleImport wraps BIN/CUE images and any associated audio tracks into a .cdmedia bundle,
/// rewriting cue paths as necessary.
@interface BXDriveBundleImport : ADBFileTransferSet <BXDriveImport>
{
	BXDrive *_drive;
	NSURL *_destinationFolderURL;
    NSURL *_destinationURL;
    BOOL _hasWrittenFiles;
}

@end


@interface BXDriveBundleCueParseError : NSError <BXDriveImportError>
@end
