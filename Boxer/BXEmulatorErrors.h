/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Foundation/Foundation.h>


#pragma mark -
#pragma mark Constants

/// The error domain for general emulator errors.
extern NSErrorDomain const BXEmulatorErrorDomain;

/// The error domain used for drive- and DOS filesystem-related errors.
extern NSErrorDomain const BXDOSFilesystemErrorDomain;

/// The name of exceptions generated when the emulation hits an error it cannot recover from.
/// The emulator should be assumed to be in an unusable state.
extern NSExceptionName const BXEmulatorUnrecoverableException;


/// User info key representing a BXDrive instance in drive-related errors.
extern NSErrorUserInfoKey const BXDOSFilesystemErrorDriveKey;

/// Error constants for BXEmulatorErrorDomain
typedef NS_ERROR_ENUM(BXEmulatorErrorDomain, BXEmulatorErrors) {
    BXEmulatorUnknownError,
    BXEmulatorUnrecoverableError,   //!< Error code used when DOSBox encounters any kind of unrecoverable error and must quit.
};

/// Error constants for BXDOSFilesystemErrorDomain
typedef NS_ERROR_ENUM(BXDOSFilesystemErrorDomain, BXDOSFilesystemErrors) {
    BXDOSFilesystemUnknownError,
    BXDOSFilesystemCouldNotReadDrive,   //!< Drive source path did not exist or could not be read
    BXDOSFilesystemInvalidImage,        //!< Drive image could not be successfully loaded by DOSBox
    BXDOSFilesystemDriveLetterOccupied, //!< Requested drive letter was already taken
    BXDOSFilesystemOutOfDriveLetters,   //!< There are no more free drive letters left
    
    BXDOSFilesystemMSCDEXNonContiguousDrives,   //!< Attempting to mount a CD drive at a letter not directly
                                                //!< before or after a previous CD drive (MSCDEX limitation.)
    BXDOSFilesystemMSCDEXOutOfCDROMDrives,      //!< Exceeded the maximum number of CD drives supported (MSCDEX limitation.)
    
    BXDOSFilesystemDriveLocked,         //!< A drive could not be ejected because it was a required internal drive.
    BXDOSFilesystemDriveInUse           //!< A drive could not be ejected because it was currently in use.
};


#pragma mark -
#pragma mark Error classes

/// A protocol for generic emulator-related error subclasses.
@protocol BXEmulatorError <NSObject>

/// Returns an autoreleased error object preconfigured with
/// the error code and domain for that error type.
+ (id) error;
@end


@class BXDrive;
/// A protocol for drive-related error subclasses.
@protocol BXDriveError <NSObject>

/// Returns an autoreleased error object preconfigured with
/// the error code and domain for that error type, and a user
/// info dictionary with the \c BXDOSFilesystemErrorDriveKey key
/// referring to the specified drive.
+ (id) errorWithDrive: (BXDrive *)drive;

@end


@interface BXEmulatorCouldNotReadDriveError : NSError <BXDriveError>
@end

@interface BXEmulatorInvalidImageError : NSError <BXDriveError>
@end

@interface BXEmulatorDriveLetterOccupiedError : NSError <BXDriveError>
@end

@interface BXEmulatorOutOfDriveLettersError : NSError <BXDriveError>
@end

@interface BXEmulatorNonContiguousDrivesError : NSError <BXDriveError>
@end

@interface BXEmulatorOutOfCDROMDrivesError : NSError <BXDriveError>
@end

@interface BXEmulatorDriveLockedError : NSError <BXDriveError>
@end

@interface BXEmulatorDriveInUseError : NSError <BXDriveError>
@end
