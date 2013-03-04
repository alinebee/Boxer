/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Foundation/Foundation.h>


#pragma mark -
#pragma mark Constants


//The error domain for general emulator errors.
extern NSString * const BXEmulatorErrorDomain;

//The error domain used for drive- and DOS filesystem-related errors.
extern NSString * const BXDOSFilesystemErrorDomain;

//The name of exceptions generated when the emulation hits an error it cannot recover from.
//The emulator should be assumed to be in an unusable state.
extern NSString * const BXEmulatorUnrecoverableException;


//User info key representing a BXDrive instance in drive-related errors.
extern NSString * const BXDOSFilesystemErrorDriveKey;

//Error constants for BXEmulatorErrorDomain
enum {
    BXEmulatorUnknownError,
    BXEmulatorUnrecoverableError,   //Error code used when DOSBox encounters any kind of unrecoverable error and must quit.
};

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
    
    BXDOSFilesystemDriveLocked,         //A drive could not be ejected because it was a required internal drive.
    BXDOSFilesystemDriveInUse           //A drive could not be ejected because it was currently in use.
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

@interface BXEmulatorDriveInUseError : NSError <BXDriveError>
@end


//An NSException subclass for wrapping exception data passed out
//from deep within DOSBox. This is subclassed to allow us to include
//our own stacktrace info.

//A C-compatible struct for throwing up exception data through the C++ throw()
//mechanism, which we can then safely convert into a BXEmulatorException on the
//other side. Thrown by boxer_die().
typedef struct {
    const char *fileName;
    const char *function;
    int lineNumber;
    const char *failureReason;
    size_t backtraceSize;
    void * const * backtraceAddresses;
} BXExceptionInfo;

@interface BXEmulatorException: NSException
{
    NSArray *_BXCallStackReturnAddresses;
    NSArray *_BXCallStackSymbols;
}

+ (id) exceptionWithName: (NSString *)name exceptionInfo: (BXExceptionInfo)info;

@end
