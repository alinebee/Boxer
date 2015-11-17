/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXDriveImport protocol defines the public interface for drive import operations,
//which are expected to descend from NSOperation. BXDriveImport is also a class that defines a number
//of helper methods and factory methods for use by concrete import operations.

#import "ADBOperation.h"
#import "ADBFileTransfer.h"

//The incremented filename format we should use for uniquely naming imported drives.
//Equivalent to baseNameForDrive (increment).driveExtension, e.g. "C DriveLabel (2).cdrom".
//The incremented number is ignored by BXDrive's label parsing.
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
- (instancetype) initForDrive: (BXDrive *)drive
         destinationFolderURL: (NSURL *)destinationFolderURL
                    copyFiles: (BOOL)copyFiles;

@end


//A set of class helper methods useful to all drive import operations
//(none of which actually inherit from this class).
//This class is not intended to be instantiated or used as a parent class.
@interface BXDriveImport: NSObject

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

//Returns the standard filename (sans extension) under which to import the specified drive,
//given Boxer's drive-naming conventions. This can be used as a starting-point by specific
//drive types.
+ (NSString *) baseNameForDrive: (BXDrive *)drive;

@end

//A protocol for import-related error subclasses.
@protocol BXDriveImportError <NSObject>

+ (instancetype) errorWithDrive: (BXDrive *)drive;

@end