/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
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

#pragma mark -
#pragma mark Emulator constants

enum {
	BXSpeedFixed	= NO,
	BXSpeedAuto		= YES
};
typedef BOOL BXSpeedMode;

enum {
	BXCoreUnknown	= -1,
	BXCoreNormal	= 0,
	BXCoreDynamic	= 1,
	BXCoreSimple	= 2,
	BXCoreFull		= 3
};
typedef NSInteger BXCoreMode;

enum {
	BXGameportTimingPollBased = NO,
	BXGameportTimingClockBased = YES
};
typedef BOOL BXGameportTimingMode;

enum {
	BXNoJoystickSupport = 0,
	BXJoystickSupportSimple,
	BXJoystickSupportFull
};
typedef NSUInteger BXJoystickSupportLevel;


//C string encodings, used by BXShell executeCommand:encoding: and executeCommand:withArgumentString:encoding:
extern NSStringEncoding BXDisplayStringEncoding;	//Used for strings that will be displayed to the user
extern NSStringEncoding BXDirectStringEncoding;		//Used for file path strings that must be preserved raw

//The name and path to the DOSBox shell. Used when determining the current process.
extern NSString * const shellProcessName;
extern NSString * const shellProcessPath;


@class BXVideoHandler;
@class BXEmulatedKeyboard;
@class BXEmulatedMouse;

@protocol BXEmulatedJoystick;
@protocol BXEmulatorDelegate;
@protocol BXEmulatorFileSystemDelegate;
@protocol BXEmulatorAudioDelegate;

@protocol BXMIDIDevice;

@interface BXEmulator : NSObject
{
	id <BXEmulatorDelegate, BXEmulatorFileSystemDelegate, BXEmulatorAudioDelegate> delegate;
	BXVideoHandler *videoHandler;
	BXEmulatedKeyboard *keyboard;
	BXEmulatedMouse *mouse;
	id <BXEmulatedJoystick> joystick;
    
    
    BOOL joystickActive;
    
    float masterVolume;
    BOOL muted;
	
	NSString *processName;
	NSString *processPath;
	NSString *processLocalPath;
	
	NSMutableDictionary *driveCache;
	
	BOOL cancelled;
	BOOL executing;
	BOOL initialized;
	BOOL paused;
    BOOL wasAutoSpeed;
    
    //The autorelease pool for the current iteration of DOSBox's run loop.
    //Created in _willStartRunLoop and released in _didFinishRunLoop.
    NSAutoreleasePool *poolForRunLoop;
    
    //The thread on which start was called.
    NSThread *emulationThread;
	
	//The queue of commands we are waiting to execute at the DOS prompt.
    //Managed by BXShell.
	NSMutableArray *commandQueue;
    
    //Managed by BXAudio.
    id <BXMIDIDevice> activeMIDIDevice;
    NSDictionary *requestedMIDIDeviceDescription;
    NSMutableArray *pendingSysexMessages;
    BOOL autodetectsMT32;
}


#pragma mark -
#pragma mark Properties

//The delegate responsible for this emulator.
@property (assign) id <BXEmulatorDelegate, BXEmulatorFileSystemDelegate, BXEmulatorAudioDelegate> delegate;

@property (readonly, retain) BXVideoHandler *videoHandler;       //Our DOSBox video and rendering handler.
@property (readonly, retain) BXEmulatedKeyboard *keyboard;       //Our emulated keyboard.
@property (readonly, retain) BXEmulatedMouse *mouse;             //Our emulated mouse.
@property (retain) id <BXEmulatedJoystick> joystick;             //Our emulated joystick. Initially empty.

//The OS X filesystem path to which the emulator should resolve relative local filesystem paths.
//This is used by DOSBox commands like MOUNT, IMGMOUNT and CONFIG, and is directly equivalent
//to the current process's working directory.
@property (copy) NSString *basePath;

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

//The name of the currently-executing DOSBox process. Will be nil if no process is running.
@property (readonly, copy) NSString *processName;

//The DOS filesystem path of the currently-executing DOSBox process.
//Will be nil if no process is running.
@property (readonly, copy) NSString *processPath;

//The local filesystem path of the currently-executing DOSBox process.
//Will be nil if no process is running or if the process is on an image or DOSBox-internal drive.
@property (readonly, copy) NSString *processLocalPath;


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
//This can be set independently of muting.
@property (assign) float masterVolume;

//Whether the sound output is currently muted. Toggling this will have no effect
//on the reported master volume.
@property (assign, getter=isMuted) BOOL muted;


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