/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "ADBSingleFileTransfer.h"
#import "BXDriveImport.h"

@class BXDrive;

/// \c BXSimpleDriveImport handles the importing of a drive to a specified destination.
@interface BXSimpleDriveImport : ADBSingleFileTransfer <BXDriveImport>
{
	BXDrive *_drive;
	NSURL *_destinationFolderURL;
	NSURL *_destinationURL;
}
@end
