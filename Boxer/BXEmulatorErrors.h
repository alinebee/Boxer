/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Foundation/Foundation.h>


#pragma mark -
#pragma mark Constants


//The error domain for general emulator errors.
extern NSString * const BXEmulatorErrorDomain;

//The error domain used for drive- and DOS filesystem-related errors.
extern NSString * const BXDOSFilesystemErrorDomain;



//User info key representing a BXDrive instance in drive-related errors.
extern NSString * const BXDOSFilesystemErrorDriveKey;


//Error constants for BXDOSFilesystemErrorDomain
enum {
    BXDOSFilesystemUnknownError,
    BXDOSFilesystemCouldNotReadDrive,   //Drive source path did not exist or could not be read
    BXDOSFilesystemInvalidImage,        //Drive image could not be successfully loaded by DOSBox
    BXDOSFilesystemDriveLetterOccupied, //Requested drive letter was already taken
    BXDOSFilesystemOutOfDriveLetters,   //There are no more free drive letters left
    
    BXDOSFilesystemMSCDEXNonContiguousDrives,   //Attempting to mount a CD drive at a letter not directly
                                                //before or after a previous CD drive (MSCDEX limitation.)
    BXDOSFilesystemMSCDEXOutOfCDROMDrives,      //Exceeded the maximum number of CD drives supported (MSCDEX limitation.)
    
    BXDOSFilesystemDriveLocked          //A drive could not be ejected because it was a required internal drive.
};


#pragma mark -
#pragma mark Error classes

//A protocol for generic emulator-related error subclasses.
@protocol BXEmulatorError

//Returns an autoreleased error object preconfigured with
//the error code and domain for that error type.
+ (id) error;
@end


//A protocol for drive-related error subclasses.
@class BXDrive;
@protocol BXDriveError

//Returns an autoreleased error object preconfigured with
//the error code and domain for that error type, and a user
//info dictionary with the BXDOSFilesystemErrorDriveKey key
//referring to the specified drive.
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
