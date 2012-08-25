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
#import "BXEmulatedMouse.h"
#import "BXKeyBuffer.h"
#import "BXAudioSource.h"
#import "BXCoalfaceAudio.h"


#pragma mark -
#pragma mark Constants and type definitions


class DOS_Shell;
class DOS_Drive;
class MixerChannel;

typedef struct BXDriveGeometry {
	NSUInteger bytesPerSector;
	NSUInteger sectorsPerCluster;
	NSUInteger numClusters;
	NSUInteger freeClusters;
} BXDriveGeometry;



//Media IDs used by _DOSBoxDriveFromPath:freeSpace:geometry:mediaID:error:
#define BXFloppyMediaID		0xF0
#define BXHardDiskMediaID	0xF8
#define BXCDROMMediaID		0xF8

//Raw disk images larger than this size in bytes will be treated as hard disks
#define BXFloppyImageSizeCutoff 2880 * 1024

//If the DOS program has last polled the BIOS key buffer more than this many seconds ago,
//we assume that BIOS-level key pasting is not a suitable approach (because the program either
//doesn't use the BIOS keybuffer at all, or only checks it in response to keyboard signalling).
#define BXBIOSKeyBufferPollIntervalCutoff 0.5

#pragma mark -
#pragma mark Error states

//Error domains used for errors generated internally by DOSBox itself.
//Such errors are handled by BXEmulator and should never reach outside classes.
extern NSString * const BXDOSBoxErrorDomain;
extern NSString * const BXDOSBoxUnmountErrorDomain;
extern NSString * const BXDOSBoxMountErrorDomain;


//Error constants used by BXDOSFilesystem _unmountDriveAtIndex:error:
enum {
    BXDOSBoxUnmountUnknownError             = -1,
	BXDOSBoxUnmountSuccess                  = 0,
    
	BXDOSBoxUnmountLockedDrive              = 1,    //Drive is an internal DOSBox drive (i.e. Z) and cannot be unmounted
	BXDOSBoxUnmountNonContiguousCDROMDrives = 2     //Unmounting the drive would make CD-ROM drive letters non-sequential
};


//Error constants used by BXDOSFilesystem's DOSBox drive constructors.
enum {
    BXDOSBoxMountUnknownError               = -1,
	BXDOSBoxMountSuccess                    = 0,
    
    BXDOSBoxMountNonContiguousCDROMDrives   = 1,    //CD-ROM drive letters would not be sequential
    BXDOSBoxMountNotSupported               = 2,    //No longer returned anywhere, as far as I can tell
    BXDOSBoxMountCouldNotReadSource         = 3,    //Could not read the drive's source file
    BXDOSBoxMountTooManyCDROMDrives         = 4,    //Exceeded maximum number of MSCDEX drives
	BXDOSBoxMountSuccessCDROMLimited        = 5,    //Local folder was mounted as a CD-ROM, thus limited emulation
    
    BXDOSBoxMountInvalidImageFormat         = 6,    //Disc image was corrupted or type could not be determined
};


@interface BXEmulator()

//Overridden to add setters for internal use
@property (readwrite, assign) NSThread *emulationThread;
@property (readwrite, getter=isExecuting) BOOL executing;
@property (readwrite, getter=isCancelled) BOOL cancelled;
@property (readwrite, getter=isInitialized) BOOL initialized;
@property (readwrite, getter=isPaused) BOOL paused;
@property (readwrite, copy) NSString *processName;

@property (readwrite) BOOL joystickActive;
@property (readwrite, getter=isWaitingForCommandInput) BOOL waitingForCommandInput;


@property (readwrite, retain) BXVideoHandler *videoHandler;
@property (readwrite, retain) BXEmulatedKeyboard *keyboard;
@property (readwrite, retain) BXEmulatedMouse *mouse;
@property (readwrite, retain) BXKeyBuffer *keyBuffer;

@end


@interface BXEmulator (BXEmulatorInternals)

- (DOS_Shell *) _currentShell;

//Called when DOSBox is ready to process events during the run loop.
- (void) _processEvents;

//Called during DOSBox's run loop: return NO to short-circuit the loop.
- (BOOL) _runLoopShouldContinue;

//Called at the start and end of each iteration of DOSBox's run loop.
- (void) _runLoopWillStartWithContextInfo: (void **)contextInfo;
- (void) _runLoopDidFinishWithContextInfo: (void *)contextInfo;

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

//Called by videoHandler when each new frame is ready.
//Passes the frame on to the emulator's delegate.
- (void) _didFinishFrame: (BXVideoFrame *)frame;

@end


@protocol BXFilesystemEnumerator;
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
- (BOOL) _addDOSBoxDrive: (DOS_Drive *)drive
                 atIndex: (NSUInteger)driveIndex;

//Unmounts the DOSBox drive at the specified index and clears any references to the drive.
//Returns YES if the drive was successfully removed, or NO abd populates outError
//if the unmount failed (e.g. it was an internal drive or there was no drive at that index.)
//TODO: should populate an optional NSError object for cases like this.
- (BOOL) _unmountDOSBoxDriveAtIndex: (NSUInteger)driveIndex error: (NSError **)outError;

//Force-close any open file resources for the specified DOSBox drive.
- (void) _closeFilesForDOSBoxDriveAtIndex: (NSUInteger)index;

//Generates a Boxer drive object for a drive at the specified drive index.
- (BXDrive *)_driveFromDOSBoxDriveAtIndex: (NSUInteger)driveIndex;

//Create and return new DOSBox drive instance of the appropriate type.
//This can then be mounted by _addDOSBoxDrive:atIndex:
- (DOS_Drive *) _floppyDriveFromImageAtPath: (NSString *)path
                                      error: (NSError **)outError;

- (DOS_Drive *) _hardDriveFromImageAtPath: (NSString *)path
                                    error: (NSError **)outError;

- (DOS_Drive *) _CDROMDriveFromImageAtPath:	(NSString *)path
                                  forIndex: (NSUInteger)driveIndex
                                     error: (NSError **)outError;

- (DOS_Drive *) _CDROMDriveFromPath: (NSString *)path
                           forIndex: (NSUInteger)driveIndex
                          withAudio: (BOOL)useCDAudio
                              error: (NSError **)outError;

- (DOS_Drive *) _hardDriveFromPath: (NSString *)path
                         freeSpace: (NSInteger)freeSpace
                             error: (NSError **)outError;

- (DOS_Drive *) _floppyDriveFromPath: (NSString *)path
                           freeSpace: (NSInteger)freeSpace
                               error: (NSError **)outError;

- (DOS_Drive *) _DOSBoxDriveFromPath: (NSString *)path
						   freeSpace: (NSInteger)freeSpace
							geometry: (BXDriveGeometry)size
							 mediaID: (NSUInteger)mediaID
                               error: (NSError **)outError;

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


#pragma mark -
#pragma mark Local filesystem access

- (FILE *) _openFileAtLocalPath: (NSString *)path
                  onDOSBoxDrive: (DOS_Drive *)dosboxDrive
                         inMode: (const char *)mode;

- (BOOL) _removeFileAtLocalPath: (NSString *)path
                  onDOSBoxDrive: (DOS_Drive *)dosboxDrive;

- (BOOL) _moveLocalPath: (NSString *)oldPath
            toLocalPath: (NSString *)newPath
          onDOSBoxDrive: (DOS_Drive *)dosboxDrive;

- (BOOL) _createDirectoryAtLocalPath: (NSString *)path
                       onDOSBoxDrive: (DOS_Drive *)dosboxDrive;

- (BOOL) _removeDirectoryAtLocalPath: (NSString *)path
                       onDOSBoxDrive: (DOS_Drive *)dosboxDrive;

- (BOOL) _getStats: (struct stat *)outStatus
      forLocalPath: (NSString *)path
     onDOSBoxDrive: (DOS_Drive *)dosboxDrive;

- (BOOL) _localDirectoryExists: (NSString *)path
                 onDOSBoxDrive: (DOS_Drive *)dosboxDrive;

- (BOOL) _localFileExists: (NSString *)path
            onDOSBoxDrive: (DOS_Drive *)dosboxDrive;

- (id <BXFilesystemEnumerator>) _directoryEnumeratorForLocalPath: (NSString *)path
                                                   onDOSBoxDrive: (DOS_Drive *)dosboxDrive;

@end


#pragma mark -
#pragma mark Shell-related internal methods

@interface BXEmulator (BXShellInternals)

//Returns YES if we can execute new commands directly, or NO if we must wait for the current
//process to finish before doing so (in which case commands will be queued up instead.)
- (BOOL) _canExecuteCommandsDirectly;

//Used internally by command execution functions. Should not be called directly.
- (void) _parseCommand: (NSString *)command
              encoding: (NSStringEncoding)encoding;

//Routes DOS commands to the appropriate selector according to commandList.
- (BOOL) _handleCommand: (NSString *)command withArgumentString: (NSString *)arguments;

//Runs the specified command string, bypassing the standard parsing and echoing behaviour.
//Used internally for rewriting and chaining commands.
- (void) _substituteCommand: (NSString *)theString encoding: (NSStringEncoding)encoding;

//Called by DOSBox when processing input at the commandline to allow it to rewrite
//or interrupt the specified command input. Returns YES if Boxer has modified any
//of the parameters provided by reference, or NO otherwise.
- (BOOL) _handleCommandInput: (inout NSString **)inOutCommand
              cursorPosition: (NSUInteger *)cursorPosition
              executeCommand: (BOOL *)execute;

//Called by DOSBox at opportune moments in the shell command process to give Boxer
//an opportunity to run its own commands.
- (BOOL) _executeNextPendingCommand;


//Whether to display the startup preamble for the specified shell.
- (BOOL) _shouldDisplayStartupMessagesForShell: (DOS_Shell *)shell;

//Called by DOSBox whenever control returns to the DOS prompt. Sends a delegate notification.
- (void) _didReturnToShell;

//Called by DOSBox just before AUTOEXEC.BAT is started. Sends a delegate notification.
- (void) _willRunStartupCommands;

//Called by DOSBox after AUTOEXEC.BAT has completed. Sends a delegate notification.
- (void) _didRunStartupCommands;

//Called by DOSBox just before a program will start. Sends a delegate notification.
- (void) _willExecuteFileAtDOSPath: (const char *)dosPath
                     onDOSBoxDrive: (DOS_Drive *)dosboxDrive
                     withArguments: (const char *)arguments;

//Called by DOSBox just after a program finishes executing and exits. Sends a delegate notification.
- (void) _didExecuteFileAtDOSPath: (const char *)dosPath
                    onDOSBoxDrive: (DOS_Drive *)dosboxDrive
                    withArguments: (const char *)arguments;

@end


#pragma mark -
#pragma mark Audio-related internal methods

@interface BXEmulator (BXAudioInternals)

//Pause/resume audio playback. Called during pause and resume.
- (void) _suspendAudio;
- (void) _resumeAudio;


//Returns the file path for the specified MT-32 ROM,
//or nil if no such ROM is available. This calls
//one of the delegate methods pathToMT32ControlROMForEmulator:
//or pathToMT32PCMROMForEmulator: to retrieve the path.
//ROMName is expected to be one of MT32_CONTROL.ROM, MT32_PCM.ROM,
//CM32L_CONTROL.ROM or CM32L_PCM.ROM, as specified by the MT32Emu
//framework.
- (NSString *) _pathForMT32ROMNamed: (NSString *)romName;

//Removes any automatically chosen MIDI device so that we can redetect it.
//Called when emulator returns to the DOS prompt.
- (void) _resetMIDIDevice;

//Used to queue up copies of sysex messages that we received before
//deciding on a MIDI device. These are delivered to a new device
//if we change our mind midstream about what kind of device to use.
- (void) _queueSysexMessage: (NSData *)message;

//Deliver queued sysex messages to the active MIDI device, and empty the queue.
- (void) _flushPendingSysexMessages;

//Clear the sysex queue without delivering messages.
- (void) _clearPendingSysexMessages;

//Returns whether we should keep listening for MT-32 messages.
- (BOOL) _shouldAutodetectMT32;

//Sleeps the thread until the active MIDI device is ready to receive messages.
- (void) _waitUntilActiveMIDIDeviceIsReady;

//Creates and attaches a new MIDI device matching the requested MIDI device description,
//if no device is attached already and if MIDI music is not disabled altogether.
//Called from handleSysex: and handleMessage: to create the MIDI device the first
//time it is needed.
- (void) _attachRequestedMIDIDeviceIfNeeded;

//Synchronizes volumes with the DOSBox mixer and MIDI devices whenever the master volume changes.
- (void) _syncVolume;

//Returns the DOSBox channel used for MIDI mixing, or NULL if none is available.
- (MixerChannel *) _MIDIMixerChannel;

//Creates and returns a new DOSBox mixer channel for handling MIDI.
- (MixerChannel *) _addMIDIMixerChannelWithSampleRate: (NSUInteger)sampleRate;

//Disables and removes the current MIDI mixer channel, if one exists.
- (void) _removeMIDIMixerChannel;

//Render the active MIDI device's MIDI output to the specified channel.
//Will raise an assertion exception if the current MIDI source does not support mixing.
- (void) _renderMIDIOutputToChannel: (MixerChannel *)channel
                             frames: (NSUInteger)numFrames;

//Render the specified number of output frames from the specified source to the specified channel.
- (void) _renderOutputFromSource: (id <BXAudioSource>)source
                       toChannel: (MixerChannel *)channel
                          frames: (NSUInteger)numFrames;

//Render the specified audio data buffer to the specified channel.
- (void) _renderBuffer: (void *)buffer
             toChannel: (MixerChannel *)channel
                frames: (NSUInteger)numFrames
                format: (BXAudioFormat)format;
@end


#pragma mark -
#pragma mark Paste-related internal methods

@interface BXEmulator (BXPasteInternals)

//Called whenever a program checks for new keys in the key buffer.
//Used for determining whether BIOS-level pasting can be used. 
- (void) _polledBIOSKeyBuffer;
   
//Whether we're able to paste directly to the BIOS. Faster, but not available for programs
//that read directly from the keyboard buffer themselves.
- (BOOL) _canPasteToBIOS;

//Whether we're able to paste text directly to the DOS prompt.
- (BOOL) _canPasteToShell;

@end