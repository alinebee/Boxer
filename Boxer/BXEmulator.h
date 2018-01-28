/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Foundation/Foundation.h>


#pragma mark - Emulator constants

/// The current DOSBox CPU speed mode: either a fixed speed or as fast as it can go.
typedef NS_ENUM(NSInteger, BXSpeedMode) {
    /// The emulator is running at a fixed rate of cycles.
    /// Corresponds to "cycles=fixed n" in DOSBox config parlance.
	BXSpeedFixed,
    /// The emulator is running to a maximum percentage of the host computer's available CPU.
    /// Corresponds to "cycles=max" in DOSBox config parlance.
	BXSpeedAuto,
};

/// The current DOSBox CPU core emulation mode.
typedef NS_ENUM(NSInteger, BXCoreMode) {
    /// The core emulation mode is not recognised or emulation has not been started.
	BXCoreUnknown	= -1,
    
    /// The default DOSBox CPU core ("core=normal" in DOSBox parlance.)
	BXCoreNormal	= 0,
    
    /// The dynamically recompiling core ("core=dynamic" in DOSBox parlance.)
	BXCoreDynamic	= 1,
    
    /// The simple CPU emulation core ("core=simple" in DOSBox parlance.) Not used by Boxer.
	BXCoreSimple	= 2,
    
    /// The full CPU emulation core ("core=full" in DOSBox parlance.) Not used by Boxer.
	BXCoreFull		= 3
};


/// The gameport timing options used by @c -gameportTimingMode and taken from the "timing" DOSBox config setting.
/// These affect how the gameport's axis values decay over time, which influences the calibration of the joystick.
/// The correct setting depends on the gmae's gameport polling strategy, which varies from game to game.
typedef NS_ENUM(NSInteger, BXGameportTimingMode) {
    /// Gameport timing is directly based on the rate at which the game polls the gameport for its status.
    /// Preferred for older games and is highly cycle-dependent: changing the CPU cycles will
    /// usually require recalibration of the joystick.
	BXGameportTimingPollBased,
    
    /// Gameport timing is based on the BIOS clock. Preferred for later games that poll the gameport
    /// at irregular intervals.
	BXGameportTimingClockBased
};

/// The current game's level of gameport joystick support used by @c -joystickSupport and taken from
/// the "joysticktype" DOSBox config setting.
/// Indicates whether the game supports 4-axis joysticks, 2-axis joysticks or no joystick at all.
typedef NS_ENUM(NSInteger, BXJoystickSupportLevel) {
    /// The current session does not support gameport devices. Controller capturing should be disabled altogether.
    /// Corresponds to "joysticktype=none" in DOSBox config parlance.
	BXNoJoystickSupport,
    
    /// The game only supports 2-axis, 2-button gameport devices. More advanced joystick emulation options
    /// should be made unavailable. Corresponds to "joysticktype=2axis" in DOSBox config parlance.
	BXJoystickSupportSimple,
    
    /// The game supports 4-axis, 4-button gameport devices. This is the default.
	BXJoystickSupportFull
};


/// The C string encoding to use for strings that will be displayed to the user. Intended for use with
/// @c -executeCommand:encoding: and @c -executeCommand:withArgumentString:encoding:.
/// Corresponds to @c kCFStringEncodingDOSLatin1.
extern NSStringEncoding BXDisplayStringEncoding;

/// The C string encoding to use for strings that should be preserved exactly as-is, such as filesystem paths.
/// Intended for use with @c -executeCommand:encoding: and @c -executeCommand:withArgumentString:encoding:.
/// Corresponds to NSUTF8StringEncoding.
extern NSStringEncoding BXDirectStringEncoding;


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

/// @c BXEmulator is our many-tentacled Cocoa wrapper for DOSBox's low-level emulation functions.
/// @c BXEmulator itself exposes an API for managing emulator startup, shutdown and general state.
/// It is extended by more specific categories for managing more other aspects of emulator functionality.
/// Because they talk directly to DOSBox, @c BXEmulator and its categories are Objective C++. All calls
/// to DOSBox emulation functionality pass through here or one of its categories.
/// @warning Only one instance of BXEmulator can be created by a single Boxer process, because DOSBox relies
/// extensive global state that is not cleaned up after exiting. Further BXEmulator instances cannot be created
/// without restarting the application process.
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
    NSDictionary *_lastProcess;
	
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


#pragma mark - Properties

/// The delegate responsible for this emulator.
@property (nonatomic, assign) id <BXEmulatorDelegate, BXEmulatorFileSystemDelegate, BXEmulatorAudioDelegate, BXEmulatedPrinterDelegate> delegate;

/// The handler for DOSBox's video emulation and rendering output.
@property (readonly, retain) BXVideoHandler *videoHandler;

/// The emulated keyboard attached to this session.
@property (readonly, retain) BXEmulatedKeyboard *keyboard;

/// The emulated mouse attached to this session.
@property (readonly, retain) BXEmulatedMouse *mouse;

/// The emulated joystick currently attached to this session. Will be @c nil if no joystick is attached.
@property (retain) id <BXEmulatedJoystick> joystick;

/// The emulated dot-matrix printer for this session.
@property (retain) BXEmulatedPrinter *printer;

/// The keybuffer used for pasting text into DOS.
@property (readonly, retain) BXKeyBuffer *keyBuffer;

/// The OS X filesystem location to which the emulator should resolve relative local filesystem paths.
/// This is used by DOSBox commands like @c MOUNT, @c IMGMOUNT and @c CONFIG and is directly equivalent
/// to the current process's working directory: indeed, changing this will change the working
/// directory for the entire process.
@property (copy, nonatomic) NSURL *baseURL;


#pragma mark Introspecting emulation state

/// Whether the emulator is currently running.
@property (readonly, getter=isExecuting) BOOL executing;

/// Whether the emulator has been cancelled and is exiting. Set to @c YES by @c -cancel.
@property (readonly, getter=isCancelled) BOOL cancelled;

/// The thread on which the emulator was started via the @c -start method.
/// @warning Currently, threads other than the main thread are unsupported.
@property (readonly) NSThread *emulationThread;

/// Whether the emulator is running on its own thread.
/// Will be NO if the emulator is running on the main thread.
@property (readonly, getter=isConcurrent) BOOL concurrent;

/// Whether the emulation is currently paused.
@property (readonly, getter=isPaused) BOOL paused;


/// Whether DOSBox has finished initializing. At this point it is safe to modify DOSBox settings,
/// but not to execute programs.
/// Set to @c YES after all modules have been initialized but before the DOS machine
/// is started and the autoexec is executed.
@property (readonly, getter=isInitialized) BOOL initialized;

/// Whether DOSBox is currently running a process that is not a commandline or batch file.
@property (readonly) BOOL isRunningActiveProcess;

/// Whether DOSBox is waiting patiently at the DOS prompt doing nothing.
@property (readonly) BOOL isAtPrompt;

/// Whether DOSBox is currently executing its AUTOEXEC.BAT startup script.
@property (readonly) BOOL isRunningAutoexec;

/// The name of the currently-executing DOS process.
/// Will be nil if no process is running or the current process is a commandline.
@property (readonly, copy) NSString *processName;

/// An array of dictionaries of representing the stack of running processes.
/// Each dictionary contains the keys listed under "Process dictionary keys".
@property (readonly) NSArray *runningProcesses;

/// Returns a dictionary of info representing the current DOSBox process,
/// containing the keys listed under "Process dictionary keys".
/// Returns @c nil if no process is running.
@property (readonly, copy) NSDictionary *currentProcess;

/// Returns a dictionary of info representing either the current DOSBox process
/// (if one is still running) or the last process that was running.
/// @see currentProcess, runningProcesses
@property (readonly, copy) NSDictionary *lastProcess;


#pragma mark Controlling emulation

/// The current fixed CPU speed.
@property (assign) NSInteger fixedSpeed;

/// Whether we are running at automatic maximum speed.
@property (assign, getter=isAutoSpeed) BOOL autoSpeed;

/// Whether we are running in turbo mode (emulating as fast as possible.)
@property (assign, getter=isTurboSpeed) BOOL turboSpeed;

/// The current CPU core mode.
@property (assign) BXCoreMode coreMode;

/// The current gameport timing mode.
@property (assign) BXGameportTimingMode gameportTimingMode;

/// The game's level of joystick support:
/// none, simple (2-button, 2-axis) or full (4-button, 4-axis).
/// This is determined from the "joysticktype" conf setting,
/// and affects the choice of joystick types Boxer offers.
@property (readonly) BXJoystickSupportLevel joystickSupport;

/// Whether the current program has indicated that it accepts joystick input,
/// by attempting to read from the gameport.
@property (readonly) BOOL joystickActive;

/// An array of queued command strings to execute on the DOS command line.
@property (readonly) NSMutableArray *commandQueue;

/// Whether the emulator will clear the screen before executing a command
/// with the executeCommand: and executeProgram: methods.
@property (assign) BOOL clearsScreenBeforeCommandExecution;

/// The properties requested by the game for what kind of MIDI playback
/// device we should use.
/// @see BXEmulator+BXAudio for keys and constants.
@property (nonatomic, retain) NSDictionary * requestedMIDIDeviceDescription;

/// The device to which we are currently sending MIDI signals.
/// One of MT32MIDIDevice, MIDISynth or externalMIDIDevice.
@property (nonatomic, retain) id <BXMIDIDevice> activeMIDIDevice;

/// Whether to autodetect when a game is playing MT-32 music.
/// If YES, the game's MIDI output will be sniffed to see if it is using MT-32 music:
/// If so, we will request to switch to an MT-32-capable MIDI output device.
@property (assign) BOOL autodetectsMT32;

/// The volume by which to scale all sound output, ranging from 0.0 to 1.0.
@property (nonatomic, assign) float masterVolume;


#pragma mark - Methods

#pragma mark Class methods

/// Returns the currently active DOS session.
+ (BXEmulator *) currentEmulator;

/// Whether it is safe to launch a new emulator instance. Will be NO after an emulator has been opened
/// (and the memory state is too polluted to reuse.)
+ (BOOL) canLaunchEmulator;

/// Returns the correct DOSBox configuration string for the "cycles" setting given the specified values.
+ (NSString *) configStringForFixedSpeed: (NSInteger)speed isAuto: (BOOL)isAutoSpeed;

/// Returns the correct DOSBox configuration string for the "core" setting given the specified core mode.
+ (NSString *) configStringForCoreMode: (BXCoreMode)mode;

/// Returns the correct DOSBox configuration string for the "timing" setting given the specified timing mode.
+ (NSString *) configStringForGameportTimingMode: (BXGameportTimingMode)mode;


#pragma mark Controlling emulation state

/// Begin emulation.
- (void) start;

/// Stop emulation as soon as possible.
- (void) cancel;

/// Pause the emulation. This will mute all sound and pause the DOSBox emulation loop.
- (void) pause;

/// Resume emulation if it was paused.
- (void) resume;


#pragma mark Process management

/// Returns whether the specified process info represents an instance of DOSBox's COMMAND.COM.
/// @param process  A process info dictionary of the kind returned by @c -currentProcess.
/// @return YES if the process info represents DOSBox's own COMMAND.COM shell, NO otherwise.
/// @note This will return NO for third-party shell processes, including the official MS-DOS COMMAND.COM.
- (BOOL) processIsShell: (NSDictionary *)process;

/// Returns whether the specified process info represents an instance of DOSBox's AUTOEXEC.BAT.
/// @param process  A process info dictionary of the kind returned by @c -currentProcess.
/// @return YES if the process info represents DOSBox's own AUTOEXEC.BAT startup script, NO otherwise.
- (BOOL) processIsAutoexec: (NSDictionary *)process;

/// Returns whether the specified process is one of DOSBox's internal programs.
/// @param process  A process info dictionary of the kind returned by @c -currentProcess.
/// @return YES if the process info represents a DOSBox-internal program (as found on drive Z), NO otherwise.
- (BOOL) processIsInternal: (NSDictionary *)process;

/// Returns whether the specified process is a batchfile or a regular program.
/// @param process  A process info dictionary of the kind returned by @c -currentProcess.
/// @return YES if the process info represents a batch file, NO otherwise.
- (BOOL) processIsBatchFile: (NSDictionary *)process;


#pragma mark Gameport devices

/// Validates whether the specified joystick is a valid joystick type and supported by the current session.
/// @param ioValue[inout]   A reference to the joystick instance to validate. If the method returns YES,
///                         this will be populated with a valid joystick instance (usually the same that was passed in.)
///                         If the method returns NO, the contents of this variable should not be accessed.
/// @param outError[out]    If provided the method returns NO, this will contain an error explaining the reason
///                         why the joystick instance was invalid.
/// @return YES if the specified joystick instance was valid and supported for this session, or NO otherwise.
- (BOOL) validateJoystick: (inout id <BXEmulatedJoystick> *)ioValue
                    error: (out NSError **)outError;

@end
