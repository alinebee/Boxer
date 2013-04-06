/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXEmulator is our many-tentacled Cocoa wrapper for DOSBox's low-level emulation functions.
//BXEmulator itself exposes an API for managing emulator startup, shutdown and general state.
//It is extended by more specific categories for managing more other aspects of emulator functionality.

//Because they talk directly to DOSBox, BXEmulator and its categories are Objective C++. All calls
//to DOSBox emulation functionality pass through here or one of its categories.

//Instances of this class are created by BXSession, and like BXSession the active emulator can be accessed
//as a singleton: via [[[NSApp delegate] currentSession] emulator] or just [BXEmulator currentEmulator].


#import <Foundation/Foundation.h>

#pragma mark - Emulator constants

typedef enum {
	BXSpeedFixed,
	BXSpeedAuto
} BXSpeedMode;

typedef enum {
	BXCoreUnknown	= -1,
	BXCoreNormal	= 0,
	BXCoreDynamic	= 1,
	BXCoreSimple	= 2,
	BXCoreFull		= 3
} BXCoreMode;

typedef enum {
	BXGameportTimingPollBased,
	BXGameportTimingClockBased
} BXGameportTimingMode;

typedef enum {
	BXNoJoystickSupport,
	BXJoystickSupportSimple,
	BXJoystickSupportFull
} BXJoystickSupportLevel;


//C string encodings, used by BXShell executeCommand:encoding: and executeCommand:withArgumentString:encoding:
extern NSStringEncoding BXDisplayStringEncoding;	//Used for strings that will be displayed to the user
extern NSStringEncoding BXDirectStringEncoding;		//Used for file path strings that must be preserved raw

//The name and path to the DOSBox shell. Used when determining the current process.
extern NSString * const shellProcessName;
extern NSString * const shellProcessPath;

//Keys used in dictionaries returned by -runningProcesses. 
extern NSString * const BXEmulatorDOSPathKey;
extern NSString * const BXEmulatorDriveKey;
extern NSString * const BXEmulatorLocalURLKey;
extern NSString * const BXEmulatorLocalPathKey __deprecated;
extern NSString * const BXEmulatorLaunchArgumentsKey;


@class BXVideoHandler;
@class BXEmulatedKeyboard;
@class BXEmulatedMouse;
@class BXEmulatedPrinter;
@class BXKeyBuffer;
@class BXDrive;

@protocol BXEmulatedJoystick;
@protocol BXEmulatedPrinterDelegate;
@protocol BXEmulatorDelegate;
@protocol BXEmulatorFileSystemDelegate;
@protocol BXEmulatorAudioDelegate;

@protocol BXMIDIDevice;

@interface BXEmulator : NSObject
{
	__unsafe_unretained id <BXEmulatorDelegate, BXEmulatorFileSystemDelegate, BXEmulatorAudioDelegate, BXEmulatedPrinterDelegate> _delegate;
	BXVideoHandler *_videoHandler;
	BXEmulatedKeyboard *_keyboard;
	BXEmulatedMouse *_mouse;
    BXEmulatedPrinter *_printer;
	id <BXEmulatedJoystick> _joystick;
    
    BOOL _joystickActive;
    
    float _masterVolume;
	
	NSString *_processName;
    NSMutableArray *_runningProcesses;
	
	NSMutableDictionary *_driveCache;
	
	BOOL _cancelled;
	BOOL _executing;
	BOOL _initialized;
	BOOL _paused;
    BOOL _wasAutoSpeed;
    
    BOOL _waitingForCommandInput;
    BOOL _clearsScreenBeforeCommandExecution;
    
    //Whether an SDL CD-ROM was playing when we paused the emulator.
    //Used to selectively resume CD-ROM playback after unpausing.
    BOOL _cdromWasPlaying;
    
    //The thread on which start was called.
    NSThread *_emulationThread;
	
	//The queue of commands we are waiting to execute at the DOS prompt.
    //Managed by BXShell.
	NSMutableArray *_commandQueue;
    BXKeyBuffer *_keyBuffer;
    NSTimeInterval _keyBufferLastCheckTime;
    NSTimeInterval _lastRunLoopTime;
    
    //Managed by BXAudio.
    id <BXMIDIDevice> _activeMIDIDevice;
    NSDictionary *_requestedMIDIDeviceDescription;
    NSMutableArray *_pendingSysexMessages;
    BOOL _autodetectsMT32;
    
    //Used by BXDOSFilesystem to track drives while they're being mounted.
    BXDrive *_driveBeingMounted;
}


#pragma mark -
#pragma mark Properties

//The delegate responsible for this emulator.
@property (assign) id <BXEmulatorDelegate, BXEmulatorFileSystemDelegate, BXEmulatorAudioDelegate, BXEmulatedPrinterDelegate> delegate;

@property (readonly, retain) BXVideoHandler *videoHandler;       //Our DOSBox video and rendering handler.
@property (readonly, retain) BXEmulatedKeyboard *keyboard;       //Our emulated keyboard.
@property (readonly, retain) BXEmulatedMouse *mouse;             //Our emulated mouse.
@property (retain) id <BXEmulatedJoystick> joystick;             //Our emulated joystick. Initially empty.
@property (retain) BXEmulatedPrinter *printer;                   //Our emulated printer.

//The keybuffer we use for pasting text into DOS.
@property (readonly, retain) BXKeyBuffer *keyBuffer;

//The OS X filesystem location to which the emulator should resolve relative local filesystem paths.
//This is used by DOSBox commands like MOUNT, IMGMOUNT and CONFIG, and is directly equivalent
//to the current process's working directory: indeed, changing this will change the working
//directory for the entire process.
@property (copy, nonatomic) NSURL *baseURL;

#pragma mark -
#pragma mark Introspecting emulation state

//Whether the emulator is currently running/cancelled respectively.
//Mirrors interface of NSOperation.
@property (readonly, getter=isExecuting) BOOL executing;
@property (readonly, getter=isCancelled) BOOL cancelled;

//The thread on which the emulator was started via the -start method.
@property (readonly) NSThread *emulationThread;

//Whether the emulator is running on its own thread.
@property (readonly, getter=isConcurrent) BOOL concurrent;

//Whether the emulation is currently paused.
@property (readonly, getter=isPaused) BOOL paused;


//Whether DOSBox has finished initializing. Set to YES after all modules have been initialized
//but before the DOS machine is started.
@property (readonly, getter=isInitialized) BOOL initialized;

//Whether DOSBox is currently running a process.
@property (readonly) BOOL isRunningProcess;

//Returns whether the current process (if any) is an internal process.
@property (readonly) BOOL processIsInternal;

//Returns whether DOSBox is currently inside a batch script.
@property (readonly) BOOL isInBatchScript;

//Returns whether DOSBox is waiting patiently at the DOS prompt doing nothing.
@property (readonly) BOOL isAtPrompt;

//Returns whether DOSBox is actively waiting for command input at the DOS prompt.
@property (readonly, getter=isWaitingForCommandInput) BOOL waitingForCommandInput;

//The name of the currently-executing DOSBox process. Will be nil if no process is running.
@property (readonly, copy) NSString *processName;

//The DOS path of the currently-executing DOSBox process.
//Will be nil if no process is running.
@property (readonly) NSString *processPath;

//The local filesystem URL of the currently-executing DOSBox process.
//Will be nil if no process is running or no URL is applicable to that process.
@property (readonly) NSURL *processURL;

//An array of dictionaries of [processPath, processLocalURL] pairs representing
//the stack of running processes.
@property (readonly) NSArray *runningProcesses;


#pragma mark -
#pragma mark Controlling emulation settings

//The current fixed CPU speed.
@property (assign) NSInteger fixedSpeed;

//Whether we are running at automatic maximum speed.
@property (assign, getter=isAutoSpeed) BOOL autoSpeed;

//Whether we are running in turbo mode (emulating as fast as possible.)
@property (assign, getter=isTurboSpeed) BOOL turboSpeed;

//The current CPU core mode.
@property (assign) BXCoreMode coreMode;

//The current gameport timing mode.
@property (assign) BXGameportTimingMode gameportTimingMode;

//The game's level of joystick support:
//none, simple (2-button, 2-axis) or full (4-button, 4-axis).
//This is determined from the "joysticktype" conf setting,
//and affects the choice of joystick types Boxer offers.
@property (readonly) BXJoystickSupportLevel joystickSupport;

//Whether the current program has indicated that it accepts joystick input,
//by attempting to read from the gameport.
@property (readonly) BOOL joystickActive;

//An array of queued command strings to execute on the DOS command line.
@property (readonly) NSMutableArray *commandQueue;

//Whether the emulator will clear the screen before executing a command
//with the executeCommand: and executeProgram: methods.
@property (assign) BOOL clearsScreenBeforeCommandExecution;


//The properties requested by the game for what kind of MIDI playback
//device we should use. See BXAudio for keys and constants.
@property (retain) NSDictionary * requestedMIDIDeviceDescription;

//The device to which we are currently sending MIDI signals.
//One of MT32MIDIDevice, MIDISynth or externalMIDIDevice.
@property (retain) id <BXMIDIDevice> activeMIDIDevice;

//Whether to autodetect when a game is playing MT-32 music.
//If YES, the game's MIDI output will be sniffed to see if it is using MT-32 music:
//If so, we will request to switch to an MT-32-capable MIDI output device.
@property (assign) BOOL autodetectsMT32;

//The volume by which to scale all sound output, ranging from 0.0 to 1.0.
@property (assign) float masterVolume;


#pragma mark -
#pragma mark Class methods

//Returns the currently active DOS session.
+ (BXEmulator *) currentEmulator;

//Whether it is safe to launch a new emulator instance. Will be NO after an emulator has been opened
//(and the memory state is too polluted to reuse.)
+ (BOOL) canLaunchEmulator;

//Returns the configuration values that reflect the specified settings.
+ (NSString *) configStringForFixedSpeed: (NSInteger)speed isAuto: (BOOL)isAutoSpeed;
+ (NSString *) configStringForCoreMode: (BXCoreMode)mode;
+ (NSString *) configStringForGameportTimingMode: (BXGameportTimingMode)mode;


#pragma mark -
#pragma mark Controlling emulation state

//Begin emulation.
- (void) start;

//Stop emulation.
- (void) cancel;

//Pause/resume the emulation. This will mute all sound and pause the DOSBox emulation loop.
- (void) pause;
- (void) resume;


#pragma mark -
#pragma mark Managing gameport devices

//Validates whether the specified joystick is a valid joystick type and supported by the current session.
- (BOOL) validateJoystick: (id <BXEmulatedJoystick> *)ioValue error: (NSError **)outError;

@end