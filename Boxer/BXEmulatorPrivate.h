/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXEmulatorPrivate declares the internal interface that should only be seen by BXEmulator and
//its C++-aware helpers. It uses C++-specific symbols and cannot be included from any C or Obj-C
//implementation file.

#import "BXEmulator.h"
#import "BXEmulatorErrors.h"
#import "BXEmulatorDelegate.h"
#import "BXEmulator+BXShell.h"
#import "BXEmulator+BXDOSFileSystem.h"
#import "BXEmulator+BXAudio.h"
#import "BXEmulator+BXPaste.h"
#import "BXMIDIDevice.h"
#import "BXVideoHandler.h"
#import "BXEmulatedKeyboard.h"
#import "BXEmulatedJoystick.h"
#import "BXEmulatedPrinter.h"
#import "BXEmulatedMouse.h"
#import "BXKeyBuffer.h"
#import "BXAudioSource.h"
#import "BXCoalfaceAudio.h"
#import "BXDrive.h"
#include <stdexcept>
#include <execinfo.h>


#pragma mark - Private constants and type definitions

class DOS_Shell;
class DOS_Drive;
class MixerChannel;

/// The drive geometry settings used by @c -_DOSBoxDriveFromPath:freeSpace:geometry:mediaID:error:
/// for mounting local folders as FAT drives.
typedef struct BXDriveGeometry {
	NSUInteger bytesPerSector;
	NSUInteger sectorsPerCluster;
	NSUInteger numClusters;
	NSUInteger freeClusters;
} BXDriveGeometry;


/// The media descriptor ID for FAT12 1.44MB floppies. Used by @c -_DOSBoxDriveFromPath:freeSpace:geometry:mediaID:error:
#define BXFloppyMediaID		0xF0

/// The media descriptor ID for fixed disk volumes. Used by @c -_DOSBoxDriveFromPath:freeSpace:geometry:mediaID:error:
#define BXHardDiskMediaID	0xF8

/// The media descriptor ID for CD-ROM volumes. Used by @c -_DOSBoxDriveFromPath:freeSpace:geometry:mediaID:error:
#define BXCDROMMediaID		0xF8


/// Heuristic used when mounting raw disk images (.img and .ima format). Images smaller than this size in bytes will
/// be mounted as floppy disks; images larger than this will be mounted as hard disks.
/// @note Unused: currently all raw disk images are assumed to be floppies.
#define BXFloppyImageSizeCutoff 2880 * 1024

/// Heuristic used when pasting text, to determine whether the current program is regularly polling the BIOS key buffer
/// for new text. If the DOS program has last polled the BIOS key buffer *more* than this many seconds ago, we assume
/// that BIOS-level key pasting is not a suitable approach: either because the program doesn't use the BIOS keybuffer
/// at all, or it only checks the BIOS keyboard buffer in response to a hardware keyboard event.
#define BXBIOSKeyBufferPollIntervalCutoff 0.5

/// The process name of the DOSBox COMMAND.COM instance.
extern NSString * const shellProcessName;

/// The path to the DOSBox COMMAND.COM instance.
extern NSString * const shellProcessPath;


#pragma mark - Error states

//Error domains used for errors generated internally by DOSBox itself.
//Such errors are handled by BXEmulator and should never reach outside classes.

/// Error domain for internal DOSBox errors.
extern NSErrorDomain const BXDOSBoxErrorDomain;

/// Error domain for internal DOSBox error codes returned when unmounting a DOSBox drive.
extern NSErrorDomain const BXDOSBoxUnmountErrorDomain;

/// Error domain for internal DOSBox error codes returned when mounting a DOSBox drive.
extern NSErrorDomain const BXDOSBoxMountErrorDomain;


/// BXDOSBoxUnmountErrorDomain constants
NS_ERROR_ENUM(BXDOSBoxUnmountErrorDomain) {
    /// Unmounting failed for an unknown reason.
    BXDOSBoxUnmountUnknownError             = -1,
    
    /// Unmounting succeeded.
	BXDOSBoxUnmountSuccess                  = 0,
    
    /// Unmounting failed because the drive is an internal DOSBox drive (i.e. Z) and cannot be unmounted.
	BXDOSBoxUnmountLockedDrive              = 1,
    
    /// Unmounting failed because unmounting the drive would make CD-ROM drive letters non-sequential.
	BXDOSBoxUnmountNonContiguousCDROMDrives = 2
};


/// BXDOSBoxMountErrorDomain constants
NS_ERROR_ENUM(BXDOSBoxMountErrorDomain) {
    /// Mounting failed for an unknown reason.
    BXDOSBoxMountUnknownError               = -1,
    
    /// Mounting succeeded.
	BXDOSBoxMountSuccess                    = 0,
    
    /// Mounting failed because CD-ROM drive letters would not be sequential.
    BXDOSBoxMountNonContiguousCDROMDrives   = 1,
    
    /// Mounting failed because the filetype was unsupported. Not returned anywhere by DOSBox, as far as I can tell.
    BXDOSBoxMountNotSupported               = 2,
    
    /// Mounting failed because the drive's source file could not be read.
    BXDOSBoxMountCouldNotReadSource         = 3,
    
    /// Mounting failed because MSCDEX's maximum number of CD-ROM drives has been reached.
    BXDOSBoxMountTooManyCDROMDrives         = 4,
    
    /// Mounting succeeded, but low-level CD-ROM emulation is unavailable.
    /// Occurs when a local folder is mounted as a CDROM drive.
	BXDOSBoxMountSuccessCDROMLimited        = 5,
    
    /// Mounting failed because a disk image was corrupted or its format could not be determined.
    BXDOSBoxMountInvalidImageFormat         = 6,
};


@interface BXEmulator()

//Overridden to add setters for internal use
@property (readwrite, assign) NSThread *emulationThread;
@property (readwrite, getter=isExecuting) BOOL executing;
@property (readwrite, getter=isCancelled) BOOL cancelled;
@property (readwrite, getter=isInitialized) BOOL initialized;
@property (readwrite, getter=isPaused) BOOL paused;
@property (readwrite, copy) NSString *processName;
@property (readwrite, copy) NSDictionary *lastProcess;

@property (readwrite, retain) BXVideoHandler *videoHandler;
@property (readwrite, retain) BXEmulatedKeyboard *keyboard;
@property (readwrite, retain) BXEmulatedMouse *mouse;
@property (readwrite, retain) BXKeyBuffer *keyBuffer;

@property (readwrite) BOOL joystickActive;


/// Set to YES when the DOS shell is waiting for commandline input from STDIN.
@property (readwrite, getter=isWaitingForCommandInput) BOOL waitingForCommandInput;

@end


@interface BXEmulator (BXEmulatorInternals)

/// Called at emulator startup and replicates DOSBox's original startup process.
/// This initializes SDL, requests and parses any config files for this session,
/// initializes every DOSBox module, and finally starts up the DOSBox machine.
- (void) _startDOSBox;

/// The current innermost shell instance.
/// This is either the current process or the shell that spawned the current process.
- (DOS_Shell *) _currentShell;

/// Called when DOSBox is ready to process events during the run loop.
/// Calls the emulator delegate's methods for pumping the event loop.
- (void) _processEvents;

/// Called during DOSBox's run loop. Returns NO to short-circuit the loop.
- (BOOL) _runLoopShouldContinue;

/// Called at the start of each iteration of DOSBox's run loop.
/// @param contextInfo[out]  Populated with a retained reference to the @c NSAutoreleasePool
/// for the current iteration of the run loop.
- (void) _runLoopWillStartWithContextInfo: (out void **)contextInfo;

/// Called at the end of each iteration of DOSBox's run loop.
/// @param contextInfo  The contextInfo that was provided by @c _runLoopWillStartWithContextInfo:
///                     (in practice, the @c NSAutoreleasePool for the current iteration of the run loop.)
- (void) _runLoopDidFinishWithContextInfo: (void *)contextInfo;

/// Convenience method for sending a notification to both the default notification center and to a selector
/// on the emulator's delegate. The object of the notification will be the @c BXEmulator instance.
- (void) _postNotificationName: (NSString *)name
			  delegateSelector: (SEL)selector
					  userInfo: (NSDictionary *)userInfo;

/// Called by DOSBox whenever it changes states that we care about but that don't have more specific callbacks for.
/// This resyncs the emulator's cached notions of the DOSBox state and posts notifications properties that have changed.
- (void) _didChangeEmulationState;

/// Called by videoHandler when each new frame is ready. Passes the frame on to the emulator's delegate.
- (void) _didFinishFrame: (BXVideoFrame *)frame;

@end


@protocol ADBFilesystemFileURLEnumeration;
@interface BXEmulator (BXDOSFileSystemInternals)

#pragma mark - Translating between Boxer and DOSBox drives

/// @param driveLetter The drive letter to look up.
/// @return The DOSBox drive index for the specified drive letter.
- (NSUInteger)_indexOfDriveLetter: (NSString *)driveLetter;

/// @param driveIndex The DOSBox drive index to look up.
/// @return The uppercase drive letter for the specified drive index.
- (NSString *)_driveLetterForIndex: (NSUInteger)driveIndex;

/// @param dosDrive The DOSBox drive instance to look up.
/// @return The Boxer drive that corresponds to the specified DOSBox drive, or @c nil if no matching drive was found.
- (BXDrive *)_driveMatchingDOSBoxDrive: (DOS_Drive *)dosDrive;

/// @param drive The Boxer drive instance to look up.
/// @return The DOSBox drive that corresponds to the specified Boxer drive, or @c NULL if no matching drive was found.
- (DOS_Drive *)_DOSBoxDriveMatchingDrive: (BXDrive *)drive;


#pragma mark - Adding and removing DOSBox drives

/// @param drive The DOSBox drive instance to look up.
/// @return The drive index at which the specified DOSBox drive is mounted. Returns @c NSNotFound if specified drive is not mounted.
- (NSUInteger) _indexOfDOSBoxDrive: (DOS_Drive *)drive;

/// Registers a new drive with DOSBox and adds it to the Drives array. This does no further preparation of the drive.
/// @param drive    The DOSBox drive instance to add.
/// @return @c YES if the drive was successfully added to the Drives array, or @c NO if there was an error.
//TODO: should populate an optional NSError object for cases like this.
- (BOOL) _addDOSBoxDrive: (DOS_Drive *)drive
                 atIndex: (NSUInteger)driveIndex;

/// Unmounts the DOSBox drive at the specified index and clears any references to the drive.
/// @param driveIndex       The index of the drive to unmount.
/// @param outError[out]    If unmounting failed and this was provided, it will be populated
///                         with an error indicating the reason for failure.
/// @return @c YES if the drive was successfully removed, or @c NO if unmounting failed.
- (BOOL) _unmountDOSBoxDriveAtIndex: (NSUInteger)driveIndex
                              error: (out NSError **)outError;

/// Force-closes any open file resources on the specified DOSBox drive.
/// This will be called automatically during unmounting of the drive and ensures that e.g. CD-ROMs can be ejected successfully.
/// @param driveIndex       The index of the drive whose resources should be closed.
- (void) _closeFilesForDOSBoxDriveAtIndex: (NSUInteger)index;

/// Generates a Boxer drive object for a drive at the specified drive index.
/// @param driveIndex       The index of the drive for which to generate a Boxer drive instance.
/// @return A Boxer drive instance based on the DOS drive at the specified index.
/// @see _driveMatchingDOSBoxDrive:
- (BXDrive *)_driveFromDOSBoxDriveAtIndex: (NSUInteger)driveIndex;

/// Returns the Boxer drive type for the DOSBox drive at the specified index.
- (BXDriveType) _typeOfDOSBoxDrive: (DOS_Drive *)drive;

/// Creates a new DOSBox floppy drive instance from a disk image. This must then be mounted by @c -_addDOSBoxDrive:atIndex:.
/// @param imagePath        The local filesystem path to the image to mount for the drive.
/// @param outError[out]    If drive creation fails, this will be populated with an error giving the reason for failure.
/// @return A new DOSBox drive instance, or NULL if drive creation failed.
- (DOS_Drive *) _floppyDriveFromImageAtPath: (NSString *)imagePath
                                      error: (NSError **)outError;

/// Creates a new DOSBox hard drive instance from a disk image. This must then be mounted by @c -_addDOSBoxDrive:atIndex:.
/// @param imagePath        The local filesystem path to the image to mount for the drive.
/// @param outError[out]    If drive creation fails, this will be populated with an error giving the reason for failure.
/// @return A new DOSBox drive instance, or NULL if drive creation failed.
- (DOS_Drive *) _hardDriveFromImageAtPath: (NSString *)imagePath
                                    error: (NSError **)outError;

/// Creates a new DOSBox CDROM drive instance from a disk image. This must then be mounted by @c -_addDOSBoxDrive:atIndex:.
/// @param imagePath        The local filesystem path to the image to mount for the drive.
/// @param driveIndex       The index at which the new drive will be located. Required for MSCDEX.
/// @param outError[out]    If drive creation fails, this will be populated with an error giving the reason for failure.
/// @return A new DOSBox drive instance, or NULL if drive creation failed.
- (DOS_Drive *) _CDROMDriveFromImageAtPath:	(NSString *)imagePath
                                  forIndex: (NSUInteger)driveIndex
                                     error: (NSError **)outError;

/// Creates a new DOSBox CDROM drive instance from a local folder. This must then be mounted by @c -_addDOSBoxDrive:atIndex:.
/// @param path             The local filesystem path to the folder to use as the mount point for the drive.
/// @param driveIndex       The index at which the new drive will be located.
/// @param withAudio        If @c YES, the first available audio CD volume will be used to provide audio tracks for the drive.
///                         If @c NO, the drive will not provide CD audio.
/// @param outError[out]    If drive creation fails, this will be populated with an error giving the reason for failure.
/// @return A new DOSBox drive instance, or NULL if drive creation failed.
- (DOS_Drive *) _CDROMDriveFromPath: (NSString *)path
                           forIndex: (NSUInteger)driveIndex
                          withAudio: (BOOL)useCDAudio
                              error: (NSError **)outError;

/// Creates a new DOSBox hard drive instance from a local folder. This must then be mounted by @c -_addDOSBoxDrive:atIndex:.
/// @param path             The local filesystem path to the folder to use as the mount point for the drive.
/// @param freeSpace        The amount of free space to report for the drive. If 0, the drive will be treated as read-only.
///                         Pass -1 to use an appropriate amount of space based on the drive type (~250MB for hard disks.)
///                         This does not actually restrict the storage space of the drive: it is only used
///                         when reporting the free space, to prevent problems with naive drive space checks.
/// @param outError[out]    If drive creation fails, this will be populated with an error giving the reason for failure.
/// @return A new DOSBox drive instance, or NULL if drive creation failed.
- (DOS_Drive *) _hardDriveFromPath: (NSString *)path
                         freeSpace: (NSInteger)freeSpace
                             error: (NSError **)outError;

/// Creates a new DOSBox floppy drive instance from a local folder. This must then be mounted by @c -_addDOSBoxDrive:atIndex:.
/// @param path             The local filesystem path to the folder to use as the mount point for the drive.
/// @param freeSpace        The amount of free space to report for the drive. If 0, the drive will be treated as read-only.
///                         Pass -1 to use an appropriate amount of space based on the drive type (1.44MB for floppy disks.)
///                         This does not actually restrict the storage space of the drive: it is only used
///                         when reporting the free space, to prevent problems with naive drive space checks.
/// @param outError[out]    If drive creation fails, this will be populated with an error giving the reason for failure.
/// @return A new DOSBox drive instance, or NULL if drive creation failed.
- (DOS_Drive *) _floppyDriveFromPath: (NSString *)path
                           freeSpace: (NSInteger)freeSpace
                               error: (NSError **)outError;

/// Creates a new DOSBox FAT drive instance from a local folder. This must then be mounted by @c -_addDOSBoxDrive:atIndex:.
/// @param path             The local filesystem path to the folder to use as the mount point for the drive.
/// @param freeSpace        The amount of free space to report for the drive. If 0, the drive will be treated as read-only.
///                         Pass -1 to use an appropriate amount of space based on the drive type.
///                         This does not actually restrict the storage space of the drive: it is only used
///                         when reporting the free space, to prevent problems with naive drive space checks.
/// @param geometry         The physical disk layout to emulate for this drive.
/// @param mediaID          The media descriptor ID to report for this drive.
/// @param outError[out]    If drive creation fails, this will be populated with an error giving the reason for failure.
/// @return A new DOSBox drive instance, or NULL if drive creation failed.
- (DOS_Drive *) _DOSBoxDriveFromPath: (NSString *)path
						   freeSpace: (NSInteger)freeSpace
							geometry: (BXDriveGeometry)size
							 mediaID: (NSUInteger)mediaID
                               error: (NSError **)outError;

/// Synchronizes Boxer's mounted drive cache with DOSBox's drive array,
/// adding and removing drives as necessary.
- (void) _syncDriveCache;

/// Adds the specified Boxer drive into the cached list of mounted drives.
/// Called when a new drive is mounted by Boxer or from the DOS command line.
- (void) _addDriveToCache: (BXDrive *)drive;

/// Removes the specified Boxer drive from the cached list of mounted drives.
/// Called when a drive is unmounted by Boxer or from the DOS command line.
- (void) _removeDriveFromCache: (BXDrive *)drive;


#pragma mark - Filesystem validation and notifications

/// Returns whether the specified drive is being used by DOS programs: i.e. whether any files are open on that drive.
- (BOOL) _DOSBoxDriveInUseAtIndex: (NSUInteger)driveIndex;

/// Called by commandline functions to decide whether a file should appear in DOS.
/// Used to exclude hidden files and OS X metadata files.
/// @note Passes the decision on to the delegate by calling @c -emulator:shouldShowFileWithName:.
/// @param fileName     The name of the file that should be displayed.
/// @return YES if the file should be shown in DOS directory listings, or NO otherwise.
- (BOOL) _shouldShowFileWithName: (NSString *)fileName;

/// Called by commandline functions to decide whether the DOS session is allowed to mount the specified path as a drive.
/// @note Passes the decision on to the delegate by calling @c -emulator:shouldMountDriveFromShell:.
/// @param filePath     The absolute POSIX path to the location on the local filesystem which should be mounted as a drive.
/// @return YES if the path is allowed to be mounted as a drive, or NO otherwise.
- (BOOL) _shouldMountLocalPath: (const char *)localPath;

/// Called by local filesystem drives to decide whether a local path should be writeable by DOSBox.
/// @note Passes the decision on to the delegate by calling @c -emulator:shouldAllowWriteAccessToPath:onDrive:.
/// @param filePath     The POSIX path to the file or folder on the local filesystem to which write access is being requested.
/// @param dosboxDrive  The DOSBox drive instance which is requesting write access to the path.
/// @return YES if DOSBox should be allowed to write to the specified path, or NO otherwise.
- (BOOL) _shouldAllowWriteAccessToLocalPath: (const char *)localPath
                              onDOSBoxDrive: (DOS_Drive *)dosboxDrive;

#pragma mark - Local filesystem access

/// Resolves a DOS path on a particular drive to a local filesystem URL.
/// @note Used internally by many methods; the public API version of this is @c -fileURLForDOSPath:.
/// @param dosPath      The DOS path to resolve. This should be absolute and may include the drive letter on the front.
/// @param dosboxDrive  The drive relative to which the DOS path should be resolved.
/// @return The local filesystem location corresponding to the specified DOS path on the specified drive.
/// Returns @c nil if no local filesystem URL could be determined (e.g. if the drive is a disk image or DOSBox-internal drive.)
- (NSURL *) _filesystemURLForDOSPath: (const char *)dosPath
                       onDOSBoxDrive: (DOS_Drive *)dosboxDrive;

/// Resolves a DOS path on a particular drive to a logical URL.
/// @note Used internally by many methods; the public API version of this is @c -logicalURLForDOSPath:.
/// @param dosPath      The DOS path to resolve. This should be absolute and may include the drive letter on the front.
/// @param dosboxDrive  The drive relative to which the DOS path should be resolved.
/// @return the logical location corresponding to the specified DOS path on the specified drive.
/// Returns nil if there is no corresponding logical location (This will be the case if the drive is a DOSBox-internal drive.)
- (NSURL *) _logicalURLForDOSPath: (const char *)dosPath
                    onDOSBoxDrive: (DOS_Drive *)dosboxDrive;

/// Opens a local file handle for DOSBox to record captured output to, in write-only mode.
/// DOSBox is expected to close the file when done.
/// @note Passes the decision on to the delegate via -emulator:openCaptureFileOfType:description:.
/// @param typeDescription      A string describing the type of data to be captured.
/// @param fileExtension        The suggested file extension to use for that data.
/// @return An open file handle for DOSBox to record into, or @c nil if capturing is not permitted.
- (FILE *) _openFileForCaptureOfType: (const char *)typeDescription
                           extension: (const char *)fileExtension;


/// Attempts to open a file on the local filesystem.
/// @param localPath    The POSIX path to the file on the local filesystem which should be opened.
/// @param dosboxDrive  The DOSBox drive from which the file is being opened.
/// @param mode         The read-write mode in which the file should be opened. This corresponds to the @c mode parameter
///                     used by the POSIX @c file() function.
/// @return a POSIX file handle for the open file. Returns @c NULL if the file could not be opened.
- (FILE *) _openFileAtLocalPath: (const char *)localPath
                  onDOSBoxDrive: (DOS_Drive *)dosboxDrive
                         inMode: (const char *)mode;

/// Attempts to delete a file on the local filesystem.
/// @param localPath    The POSIX path to the file on the local filesystem which should be removed.
/// @param dosboxDrive  The DOSBox drive from which the file is being deleted.
/// @return YES if the file was successfully deleted, or NO if the file could not be deleted.
/// @return @c YES if the file was deleted successfully, or @c NO otherwise.
- (BOOL) _removeFileAtLocalPath: (const char *)localPath
                  onDOSBoxDrive: (DOS_Drive *)dosboxDrive;

/// Called by local filesystem drives to move a file or folder on the local filesystem to another location.
/// This is also used when renaming files.
/// @param fromPath     The POSIX path to the location on the local filesystem which is to be moved.
/// @param toPath       The POSIX path to the location on the local filesystem to which to move the file or folder.
/// @param dosboxDrive  The drive on which the file is being moved. Files are never moved between drives.
/// @return @c YES if the resource was moved successfully, or @c NO otherwise.
- (BOOL) _moveLocalPath: (const char *)fromPath
            toLocalPath: (const char *)toPath
          onDOSBoxDrive: (DOS_Drive *)dosboxDrive;

/// Called by local filesystem drives to create a new directory at a specified local filesystem locaiton.
/// @param localPath    The POSIX path to the location on the local filesystem where the directory is to be created.
///                     Any intermediate directories that do not yet exist will also be created.
/// @param dosboxDrive  The drive on which the directory is being created.
/// @return @c YES if the directory was created successfully, or @c NO otherwise.
- (BOOL) _createDirectoryAtLocalPath: (const char *)localPath
                       onDOSBoxDrive: (DOS_Drive *)dosboxDrive;

/// Called by local filesystem drives to remove a directory and its contents from a specified local filesystem locaiton.
/// @param localPath    The POSIX path to the directory on the local filesystem to be removed.
/// @param dosboxDrive  The drive from which the directory is being removed.
/// @return @c YES if the directory was removed successfully, or @c NO otherwise.
- (BOOL) _removeDirectoryAtLocalPath: (const char *)localPath
                       onDOSBoxDrive: (DOS_Drive *)dosboxDrive;

/// Called by local filesystem drives when a new file is created on that drive.
/// @note This notification is not called when moving or renaming files or when creating new directories.
/// @param localPath    The POSIX path to the file on the local filesystem that was created.
/// @param dosboxDrive  The DOSBox drive instance on which the file was created.
- (void) _didCreateFileAtLocalPath: (const char *)localPath
                     onDOSBoxDrive: (DOS_Drive *)dosboxDrive;

/// Called by local filesystem drives when a file is removed from that drive.
/// @note This notification is not called when moving or renaming files or when removing directories.
/// @param localPath    The POSIX path to the file on the local filesystem that was removed.
/// @param dosboxDrive  The DOSBox drive instance from which the file was removed.
- (void) _didRemoveFileAtLocalPath: (const char *)localPath
                     onDOSBoxDrive: (DOS_Drive *)dosboxDrive;

/// Gets a POSIX file stat block for the specified resource on the local filesystem.
/// @param outStatus[out]   If the method returns @c YES, this will be populated with a POSIX file stat block.
///                         If the method returns @c NO, the value of this variable should not be accessed.
/// @param localPath        The POSIX path to the resource on the local filesystem for which to retrieve stats.
/// @return @c YES if stats were retrieved for the specified resource, or @c NO otherwise
/// (in which case the resource did not exist or could not be read.)
- (BOOL) _getStats: (out struct stat *)outStatus
      forLocalPath: (const char *)localPath
     onDOSBoxDrive: (DOS_Drive *)dosboxDrive;

/// Checks whether a directory exists at a specified location on the local filesystem.
/// @param localPath        The POSIX path on the local filesystem to check.
/// @param dosboxDrive      The DOSBox drive instance that is checking for the directory's existence.
/// @return YES if a directory exists at the specified location, or NO otherwise
/// (including if the resource at the specified location was a file rather than a directory.)
- (BOOL) _localDirectoryExists: (const char *)localPath
                 onDOSBoxDrive: (DOS_Drive *)dosboxDrive;

/// Checks whether a file exists at a specified location on the local filesystem.
/// @param localPath        The POSIX path on the local filesystem to check.
/// @param dosboxDrive      The DOSBox drive instance that is checking for the file's existence.
/// @return YES if a regular file exists at the specified location, or NO otherwise
/// (including if the resource at the specified location was a directory rather than a file.)
- (BOOL) _localFileExists: (const char *)path
            onDOSBoxDrive: (DOS_Drive *)dosboxDrive;

/// Enumerates a location on the local filesystem.
/// @param localPath    The POSIX path on the local filesystem for the directory to enumerate.
///                     If this path is a regular file rather than a directory, the behaviour is undetermined.
/// @param dosboxDrive  The DOSBox drive which is performing the enumeration.
/// @return An enumerator to use for listing the contents of the specified location.
- (id <ADBFilesystemFileURLEnumeration>) _directoryEnumeratorForLocalPath: (const char *)path
                                                            onDOSBoxDrive: (DOS_Drive *)dosboxDrive;

@end


#pragma mark - Shell-related internal methods

@interface BXEmulator (BXShellInternals)

/// Returns YES if the emulator can execute new commands directly, or NO if it must wait for the current
//process to finish before doing so (in which case commands will be queued up instead.)
- (BOOL) _canExecuteCommandsDirectly;

/// Used internally by command execution functions to interpret and dispatch commandline commands.
/// Should not be called directly.
- (void) _parseCommand: (NSString *)command
              encoding: (NSStringEncoding)encoding;

/// Dispatches DOS commandline commands to the appropriate method to handle them. Should not be called directly.
- (BOOL) _handleCommand: (NSString *)command withArgumentString: (NSString *)arguments;

/// Executes the specified command string bypassing the shell's standard parsing and echoing behaviour.
/// Used internally for rewriting and chaining commands. Should not be called directly.
- (void) _executeCommand: (NSString *)theString encoding: (NSStringEncoding)encoding;

/// Called by DOSBox when processing input at the commandline to allow it to rewrite or interrupt the specified command input.
/// @return @c YES if Boxer has modified or discarded any of the parameters provided by reference, or @c NO otherwise.
//TODO Currently Boxer never modifies commandline input, and only uses this method for interrupting and discarding commandline
//input when it has pending commands it wants to execute. This calling convention is a leftover and could be greatly simplified.
- (BOOL) _handleCommandInput: (inout NSString **)inOutCommand
              cursorPosition: (NSUInteger *)cursorPosition
              executeCommand: (BOOL *)execute;

/// Called by DOSBox at opportune moments in the shell command process to give Boxer an opportunity to run its own commands.
- (BOOL) _executeNextPendingCommand;

/// Whether to display the startup preamble for the specified shell.
/// Passes the decision on to the delegate by calling @c -emulatorShouldDisplayStartupMessages:.
- (BOOL) _shouldDisplayStartupMessagesForShell: (DOS_Shell *)shell;

/// Called by DOSBox whenever control returns to the DOS prompt: this includes when a program exits but also when a new shell
/// process is opened. Sends the @c BXEmulatorDidReturnToShellNotification delegate notification.
- (void) _didReturnToShell;

/// Called by DOSBox whenever a new shell process is opened. Currently does nothing.
- (void) _shellWillStart: (DOS_Shell *)shell;

/// Called by DOSBox whenever a shell process exits. Currently does nothing.
- (void) _shellDidFinish: (DOS_Shell *)shell;

/// Called by DOSBox just before AUTOEXEC.BAT is started. Sends the BXEmulatorWillRunStartupCommandsNotification delegate notification.
- (void) _willRunStartupCommands;

/// Called by DOSBox just before a program or batch file will be executed.
/// Sends a @c BXEmulatorWillStartProgramNotification delegate notification.
- (void) _willExecuteFileAtDOSPath: (const char *)dosPath
                     withArguments: (const char *)arguments
                       isBatchFile: (BOOL)isBatchFile;

/// Called by DOSBox just after the current program or batch file finishes executing and exits.
/// Sends a @c BXEmulatorDidFinishProgramNotification delegate notification.
- (void) _didExecuteFileAtDOSPath: (const char *)dosPath;

@end


#pragma mark - Audio-related internal methods

@interface BXEmulator (BXAudioInternals)

/// Suspend audio emulation and stop all playback. Called when the emulator is paused to prevent hanging notes.
- (void) _suspendAudio;

/// Resume audio emulation and playback. Called when the emulator is resumed.
- (void) _resumeAudio;

/// Used during MIDI input format detection to queue up copies of sysex messages that we received before deciding on a MIDI device.
/// If a more appropriate MIDI device is later detected, these queued messages will be delivered to the new device.
/// @note This is primarily for the benefit of MT-32 autodetection: a game may send a sequence of ambiguous MIDI sysex messages
/// followed by one that conclusively determines that it thinks it's talking to an MT-32, at which point MT-32 emulation is enabled
/// and all previous sysex messages should be delivered to the MT-32 to ensure it's properly initialized.
- (void) _queueSysexMessage: (NSData *)message;

/// Deliver queued sysex messages to the active MIDI device, and empty the sysex message queue.
/// Called when switching to a more appropriate MIDI emulation mode.
/// @see _queueSysexMessage: and _clearPendingSysexMessages:
- (void) _flushPendingSysexMessages;

/// Clear the sysex queue, discarding all queued messages. Called when conclusively determining that the current MIDI
/// emulation mode is the best one for the current program.
/// @see _queueSysexMessage: and _flushPendingSysexMessages:
- (void) _clearPendingSysexMessages;

/// Removes any active MIDI output device to allow an appropriate one to be redetected when MIDI output is next used.
/// Called automatically when emulator returns to the DOS prompt, in case the user switches to a program or audio mode
/// that needs a different MIDI device (e.g., switching from MT-32 audio to General MIDI or vice-versa.)
- (void) _resetMIDIDevice;

/// If the current MIDI device is busy processing previous MIDI messages, pauses the emulation thread until
/// the active MIDI device is ready to receive messages again.
/// Used when talking to a real MIDI device to avoid flooding it with MIDI messages it can't process in time.
- (void) _waitUntilActiveMIDIDeviceIsReady;

/// If no MIDI device is currently attached, creates and attaches a new MIDI device matching the requested MIDI device description.
/// Called from @c -sendMIDIMessage: and @c -sendMIDISysex: to create a MIDI device the first time MIDI input is received.
- (void) _attachRequestedMIDIDeviceIfNeeded;

/// Called whenever the master volume changes to synchronize volumes with the DOSBox mixer and MIDI devices.
- (void) _syncVolume;

/// Returns the DOSBox channel used for MIDI mixing, or @c NULL if none is necessary.
- (MixerChannel *) _MIDIMixerChannel;

/// Creates and returns a new DOSBox mixer channel for handling MIDI.
- (MixerChannel *) _addMIDIMixerChannelWithSampleRate: (NSUInteger)sampleRate;

/// Disables and removes the current MIDI mixer channel, if one exists.
- (void) _removeMIDIMixerChannel;

/// Renders the active MIDI device's MIDI output to the specified channel.
/// Will raise an assertion if the current MIDI source does not support mixing.
- (void) _renderMIDIOutputToChannel: (MixerChannel *)channel
                             frames: (NSUInteger)numFrames;

/// Render the specified number of output frames from the specified audio source to the specified output channel.
- (void) _renderOutputFromSource: (id <BXAudioSource>)source
                       toChannel: (MixerChannel *)channel
                          frames: (NSUInteger)numFrames;

/// Render the specified audio data buffer to the specified channel.
- (void) _renderBuffer: (void *)buffer
             toChannel: (MixerChannel *)channel
                frames: (NSUInteger)numFrames
                format: (BXAudioFormat)format;
@end


#pragma mark - Paste-related internal methods

@interface BXEmulator (BXPasteInternals)

/// Called whenever a program checks for new keys in the BIOS key buffer. This is used to check how regularly
/// the current program is polling the buffer, and thus whether BIOS-keybuffer pasting can be used.
- (void) _polledBIOSKeyBuffer;
   
/// Whether text can be pasted directly to the BIOS key buffer. Faster, but not available for programs
/// that read directly from the keyboard buffer themselves or that do not poll the BIOS key buffer regularly.
- (BOOL) _canPasteToBIOS;

/// Whether text can be pasted text directly to the DOSBox shell. Text pasted to the shell will be sanitised
/// in such a way that it can be executed directly as commands.
- (BOOL) _canPasteToShell;

@end


#pragma mark - IO-related methods

@interface BXEmulator (BXParallelInternals)

/// Called when the DOS session wants an emulated printer to be attached to the specified port.
/// (i.e., when any emulated parallel port has been configured to point to a printer.)
- (void) _didRequestPrinterOnLPTPort: (NSUInteger)portNumber;

@end


#pragma mark - Exception handling

/// Thrown by boxer_die. Encapsulates as much data as we can about the stack at the moment of creation.
/// Caught and converted into a BXEmulatorException by BXEmulator _startDOSBox.
struct boxer_emulatorException: public std::exception {
    char errorReason[1024];
    char fileName[256];
    char functionName[256];
    int lineNumber;
    void *backtraceAddresses[20];
    char **backtraceSymbols;
    int backtraceSize;
    
    boxer_emulatorException(const char *reason,
                            const char *file,
                            const char *function,
                            int line)
    {
        strlcpy(errorReason, reason, sizeof(errorReason));
        strlcpy(fileName, file, sizeof(fileName));
        strlcpy(functionName, function, sizeof(functionName));
        lineNumber = line;
        
        backtraceSize = backtrace(backtraceAddresses, 20);
        backtraceSymbols = backtrace_symbols(backtraceAddresses, backtraceSize);
    }
    
    ~boxer_emulatorException() throw()
    {
        free(backtraceSymbols);
    }
    
    const char * what() const throw() { return errorReason; }
};


@interface BXEmulatorException: NSException
{
    NSArray *_BXCallStackReturnAddresses;
    NSArray *_BXCallStackSymbols;
}

@property (copy) NSArray *callStackReturnAddresses;
@property (copy) NSArray *callStackSymbols;

+ (instancetype) exceptionWithName: (NSString *)name originalException: (boxer_emulatorException *)info;

@end
