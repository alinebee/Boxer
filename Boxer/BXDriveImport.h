/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "ADBOperation.h"
#import "ADBFileTransfer.h"

//The incremented filename format we should use for uniquely naming imported drives.
//Equivalent to nameForDrive (increment).driveExtension, e.g. "C DriveLabel (2).cdrom".
//The incremented number is guaranteed to be ignored by BXDrive's label parsing.
extern NSString * const BXUniqueDriveNameFormat;

@class BXDrive;

@protocol BXDriveImport <NSObject, ADBFileTransfer>

//The drive to import.
@property (retain) BXDrive *drive;

//The base folder into which to import the drive, not including the drive name.
@property (copy) NSURL *destinationFolderURL;

//The full destination path of the drive import, including the drive name.
//If left blank, it should be set at import time to preferredDestinationPath.
@property (copy) NSURL *destinationURL;

//This should return the preferred location to which this drive should be imported,
//taking into account destinationFolder and nameForDrive: and auto-incrementing as
//necessary to ensure uniqueness.
- (NSURL *) preferredDestinationURL;

//Returns whether this import class is appropriate for importing the specified drive.
+ (BOOL) isSuitableForDrive: (BXDrive *)drive;

//Returns the name under which the specified drive would be saved.
+ (NSString *) nameForDrive: (BXDrive *)drive;

//Returns whether the drive will become inaccessible during this import.
//This will cause the drive to be unmounted for the duration of the import,
//and then remounted once the import finishes.
+ (BOOL) driveUnavailableDuringImport;


//Return a suitably initialized BXOperation subclass for transferring the drive.
- (id <BXDriveImport>) initForDrive: (BXDrive *)drive
               destinationFolderURL: (NSURL *)destinationFolderURL
						  copyFiles: (BOOL)copyFiles;

@end


@interface BXDriveImport: ADBOperation

+ (id <BXDriveImport>) importOperationForDrive: (BXDrive *)drive
                          destinationFolderURL: (NSURL *)destinationFolder
                                     copyFiles: (BOOL)copyFiles;

//Returns the most suitable operation class to import the specified drive
+ (Class) importClassForDrive: (BXDrive *)drive;

//Returns a safe replacement import operation for the specified failed import,
//or nil if no fallback was available.
//The replacement will have the same source drive and destination folder as
//the original import.
//Used when e.g. a disc-ripping import fails because of a driver-related issue:
//this will fall back on a safer method of importing.
+ (id <BXDriveImport>) fallbackForFailedImport: (id <BXDriveImport>)failedImport;

@end

//A protocol for import-related error subclasses.
@protocol BXDriveImportError

+ (id) errorWithDrive: (BXDrive *)drive;

@end