/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXCDImageImport rips physical CDs to (CDR-format) ISO disc images using OS X's hdiutil.

#import "BXDriveImport.h"
#import "BXTaskOperation.h"

//Domain and constants for errors encountered during disc-image ripping
extern NSString * const BXCDImageImportErrorDomain;

enum {
	BXCDImageImportErrorRipFailed,          //Could not rip the image for an unknown reason
	BXCDImageImportErrorCouldNotReadDisc,	//Failed to read the contents of the disc
	BXCDImageImportErrorDiscInUse           //Could not begin ripping because the disc is in use
};


@interface BXCDImageImport : BXTaskOperation <BXDriveImport>
{
	BXDrive *_drive;
	unsigned long long _numBytes;
	unsigned long long _bytesTransferred;
	BXOperationProgress _currentProgress;
	BOOL _indeterminate;
	NSString *_destinationFolder;
    BOOL _hasWrittenFiles;
}

@property (assign, readwrite) unsigned long long numBytes;
@property (assign, readwrite) unsigned long long bytesTransferred;
@property (assign, readwrite) BXOperationProgress currentProgress;
@property (assign, readwrite, getter=isIndeterminate) BOOL indeterminate;


@end


@interface BXCDImageImportRipFailedError : NSError <BXDriveImportError>
@end

@interface BXCDImageImportDiscInUseError : NSError <BXDriveImportError>
@end