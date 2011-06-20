/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXEmulatorPrivate declares the internal interface that should only be seen by BXEmulator and
//its C++-aware helpers. It uses C++-specific symbols and cannot be included from any C or Obj-C
//implementation file.

#import "BXEmulator.h"
#import "BXEmulatorDelegate.h"
#import "BXEmulator+BXShell.h"
#import "BXEmulator+BXDOSFileSystem.h"
#import "BXVideoHandler.h"
#import "BXEmulatedKeyboard.h"
#import "BXEmulatedJoystick.h"
#import "BXEmulatedMouse.h"


class DOS_Shell;
class DOS_Drive;

typedef struct BXDriveGeometry {
	NSUInteger bytesPerSector;
	NSUInteger sectorsPerCluster;
	NSUInteger numClusters;
	NSUInteger freeClusters;
} BXDriveGeometry;


@interface BXEmulator()

//Overridden to add setters for internal use
@property (readwrite, nonatomic, getter=isExecuting) BOOL executing;
@property (readwrite, nonatomic, getter=isCancelled) BOOL cancelled;
@property (readwrite, nonatomic, getter=isInitialized) BOOL initialized;
@property (readwrite, copy, nonatomic) NSString *processName;
@property (readwrite, copy, nonatomic) NSString *processPath;
@property (readwrite, copy, nonatomic) NSString *processLocalPath;

@end


@interface BXEmulator (BXEmulatorInternals)

- (DOS_Shell *) _currentShell;

//Called during DOSBox's event handling function: returns YES to abort event handling
//for that loop or NO to continue it.
- (BOOL) _handleEventLoop;

//Called during DOSBox's run loop: returns YES to short-circuit the loop.
- (BOOL) _handleRunLoop;

//Called at emulator startup.
- (void) _startDOSBox;

//Shortcut method for sending a notification both to the default notification center
//and to a selector on our delegate. The object of the notification will be self.
- (void) _postNotificationName: (NSString *)name
			  delegateSelector: (SEL)selector
					  userInfo: (NSDictionary *)userInfo;

//Called by DOSBox whenever it changes states we care about. This resyncs BXEmulator's
//cached notions of the DOSBox state, and posts notifications for relevant properties.
- (void) _didChangeEmulationState;

//Called at various points throughout the emulator's lifecycle, to send notifications
//to our emulator delegate.
- (void) _willStart;
- (void) _didInitialize;
- (void) _didFinish;

@end


@interface BXEmulator (BXDOSFileSystemInternals)

#pragma mark -
#pragma mark Translating between Boxer and DOSBox drives

//Returns the DOSBox drive index for a specified drive letter and vice-versa.
- (NSUInteger)_indexOfDriveLetter: (NSString *)driveLetter;
- (NSString *)_driveLetterForIndex: (NSUInteger)driveIndex;


//Returns the Boxer drive that matches the specified DOSBox drive, or nil if no drive was found.
- (BXDrive *)_driveMatchingDOSBoxDrive: (DOS_Drive *)dosDrive;

//Does the inverse of the above - returns the DOSBox drive corresponding to the specified Boxer drive.
- (DOS_Drive *)_DOSBoxDriveMatchingDrive: (BXDrive *)drive;

//Returns the local filesystem path corresponding to the specified DOS path on the specified drive.
//Returns nil if there is no corresponding local file (e.g. if the drive is a disk image or DOSBox-internal drive.)
- (NSString *)_filesystemPathForDOSPath: (const char *)dosPath onDOSBoxDrive: (DOS_Drive *)dosboxDrive;


#pragma mark -
#pragma mark Adding and removing DOSBox drives

//Returns the drive index at which the specified DOSBox drive is mounted.
//Returns NSNotFound if specified drive is not mounted.
- (NSUInteger) _indexOfDOSBoxDrive: (DOS_Drive *)drive;

//Registers a new drive with DOSBox and adds it to the drive list.
//Returns YES if the drive was successfully added, or NO if there was an error
//(e.g. there was already a drive at that index).
//TODO: should populate an optional NSError object for cases like this.
- (BOOL) _addDOSBoxDrive: (DOS_Drive *)drive atIndex: (NSUInteger)driveIndex;

//Unmounts the DOSBox drive at the specified index and clears any references to the drive.
//Returns YES if the drive was successfully removed, or NO if there was an error
//(e.g. there was no drive at that index.)
//TODO: should populate an optional NSError object for cases like this.
- (BOOL) _unmountDOSBoxDriveAtIndex: (NSUInteger)driveIndex;

//Generates a Boxer drive object for a drive at the specified drive index.
- (BXDrive *)_driveFromDOSBoxDriveAtIndex: (NSUInteger)driveIndex;

//Create and return new DOSBox drive instance of the appropriate type.
//This can then be mounted by _addDOSBoxDrive:atIndex:
- (DOS_Drive *) _floppyDriveFromImageAtPath:(NSString *)path;
- (DOS_Drive *) _CDROMDriveFromImageAtPath:	(NSString *)path forIndex: (NSUInteger)driveIndex;
- (DOS_Drive *) _CDROMDriveFromPath:		(NSString *)path forIndex: (NSUInteger)driveIndex withAudio: (BOOL)useCDAudio;
- (DOS_Drive *) _hardDriveFromPath:			(NSString *)path freeSpace: (NSInteger)freeSpace;
- (DOS_Drive *) _floppyDriveFromPath:		(NSString *)path freeSpace: (NSInteger)freeSpace;

- (DOS_Drive *) _DOSBoxDriveFromPath: (NSString *)path
						   freeSpace: (NSInteger)freeSpace
							geometry: (BXDriveGeometry)size
							 mediaID: (NSUInteger)mediaID;

//Synchronizes Boxer's mounted drive cache with DOSBox's drive array,
//adding and removing drives as necessary.
- (void) _syncDriveCache;
- (void) _addDriveToCache: (BXDrive *)drive;
- (void) _removeDriveFromCache: (BXDrive *)drive;


#pragma mark -
#pragma mark Filesystem validation and notifications

//Returns whether the specified drive is being used by DOS programs.
//Currently, this means whether any files are open on that drive.
- (BOOL) _DOSBoxDriveInUseAtIndex: (NSUInteger)driveIndex;

//Decides whether to let the DOS session mount the specified path
//This checks against pathIsSafeToMount, and prints an error to the console if not
- (BOOL) _shouldMountPath: (NSString *)thePath;

//Returns whether to show files with the specified name in DOS directory listings
//This hides all files starting with . or that are in dosFileExclusions
- (BOOL) _shouldShowFileWithName: (NSString *)fileName;

//Returns whether to allow the file at the specified path to be written to or modified by DOS, via the specified drive.
- (BOOL) _shouldAllowWriteAccessToPath: (NSString *)filePath onDOSBoxDrive: (DOS_Drive *)dosboxDrive;

- (void) _didCreateFileAtPath: (NSString *)filePath onDOSBoxDrive: (DOS_Drive *)dosboxDrive;
- (void) _didRemoveFileAtPath: (NSString *)filePath onDOSBoxDrive: (DOS_Drive *)dosboxDrive;

@end


#pragma mark -
#pragma mark Shell-related internal methods

@interface BXEmulator (BXShellInternals)

//Routes DOS commands to the appropriate selector according to commandList.
- (BOOL) _handleCommand: (NSString *)command withArgumentString: (NSString *)arguments;

//Runs the specified command string, bypassing the standard parsing and echoing behaviour.
//Used internally for rewriting and chaining commands.
- (void) _substituteCommand: (NSString *)theString encoding: (NSStringEncoding)encoding;

//Called by DOSBox when processing input at the commandline. Returns a modified command string,
//along with a flag to execute the command or leave it on the commandline for further modification.
//Returns nil if Boxer does not wish to meddle with the command string.
- (NSString *)_handleCommandInput: (NSString *)commandLine
				 atCursorPosition: (NSUInteger *)cursorPosition
			   executeImmediately: (BOOL *)execute;

//Called by DOSBox whenever control returns to the DOS prompt. Sends a delegate notification.
- (void) _didReturnToShell;

//Called by DOSBox just before AUTOEXEC.BAT is started. Sends a delegate notification.
- (void) _willRunStartupCommands;

//Called by DOSBox after AUTOEXEC.BAT has completed. Sends a delegate notification.
- (void) _didRunStartupCommands;

//Called by DOSBox just before a program will start. Sends a delegate notification.
- (void) _willExecuteFileAtDOSPath: (const char *)dosPath onDOSBoxDrive: (DOS_Drive *)dosboxDrive;

//Called by DOSBox just after a program finishes executing and exits. Sends a delegate notification.
- (void) _didExecuteFileAtDOSPath: (const char *)dosPath onDOSBoxDrive: (DOS_Drive *)dosboxDrive;

@end
