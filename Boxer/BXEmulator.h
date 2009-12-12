/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXEmulator is our many-tentacled Cocoa wrapper for DOSBox's low-level emulation functions.
//BXEmulator itself exposes an API for managing emulator startup, shutdown and general state.
//It is extended by more specific categories for managing more other aspects of emulator functionality.

//Because they talk directly to DOSBox, BXEmulator and its categories are Objective C++. All calls
//to DOSBox emulation functionality pass through here or one of its categories.

//Instances of this class are created by BXSession, and like BXSession the active emulator can be accessed
//as a singleton: via [[BXSession mainSession] emulator] or just [BXEmulator currentEmulator].

//While BXEmulator is an NSOperation subclass, multithreading is not yet supported and may never be
//via the NSOperation API.


#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import "boxer.h"

//Emulation-related constant definitions
//--------------------------------------

enum {
	BXSpeedFixed	= NO,
	BXSpeedAuto		= YES
};

enum {
	BXCoreUnknown	= -1,
	BXCoreNormal	= 0,
	BXCoreDynamic	= 1,
	BXCoreSimple	= 2,
	BXCoreFull		= 3
};

typedef BOOL BXSpeedMode;
typedef NSInteger BXCoreMode;


//C string encodings, used by BXShell executeCommand:encoding: and executeCommand:withArgumentString:encoding:
extern NSStringEncoding BXDisplayStringEncoding;	//Used for strings that will be displayed to the user
extern NSStringEncoding BXDirectStringEncoding;		//Used for file path strings that must be preserved raw


@class BXSession;

@interface BXEmulator : NSOperation
{
	NSThread *thread;
	
	NSInteger minFixedSpeed;
	NSInteger maxFixedSpeed;
	NSUInteger maxFrameskip;
	
	BOOL isInterrupted;
	BOOL pendingRefresh;
	
	//Used by BXShell
	NSUInteger queueDepth;
	NSUInteger numQueuedCommands;
	BOOL suppressOutput;
	
	//Used by BXRecording
	NSString *currentRecordingPath;
	
	NSString *processName;
	
	NSMutableArray *configFiles;
	
	BXSession *delegate;
}

//Properties
//----------

//The name of the currently-executing DOSBox process. Will be nil if no process is running.
@property (copy)		NSString *processName;

//The path to the movie we are currently recording. Will be nil if no recording is in progress.
//This is only used internally by BXRecording and should not be accessed outside of BXEmulator.
@property (copy)		NSString *currentRecordingPath;

//The BXSession delegate responsible for this emulator.
@property (assign)		BXSession *delegate;

//The current thread under which the emulator is running. This is not retained.
@property (readonly)	NSThread *thread;

//An array of OS X paths to configuration files that will be processed by this session during startup.
@property (retain)		NSMutableArray *configFiles;

//The maximum allowable value for the frameskip setting.
//Defaults to 9.
@property (assign)		NSUInteger maxFrameskip;

//The minimum and maximum allowable CPU speeds.
//These default to BXMinSpeedThreshold and BXMaxSpeedThreshold.
@property (assign)		NSInteger minFixedSpeed;
@property (assign)		NSInteger maxFixedSpeed;

//Whether the output of DOS programs should be discarded without printing to the DOS shell.
//Used by BXShell at opportune moments.
@property (assign)		BOOL suppressOutput;


//Class methods
//-------------

//An array of names of internal DOSBox processes.
+ (NSArray *) internalProcessNames;

//Returns whether the specified process name is a DOSBox internal process (according to internalProcessNames).
+ (BOOL) isInternal: (NSString *)processName;

//Returns the currently active DOS session.
+ (BXEmulator *) currentEmulator;


//Initializating the DOS emulator
//-------------------------------

//Starts up the main emulator loop. 
- (void) main;

//Adds the DOSBox configuration file at the specified OS X path to be parsed at startup.
//Has no effect if the emulator has already started.
- (void) addConfigFile: (NSString *)configPath;


//Introspecting emulation state
//-----------------------------

//Returns whether DOSBox is currently running a process.
- (BOOL) isRunningProcess;

//Returns whether the current process (if any) is an internal process.
- (BOOL) processIsInternal;

//Returns whether DOSBox is currently inside a batch script.
- (BOOL) isInBatchScript;

//Returns whether DOSBox is waiting patiently at the DOS prompt doing nothing.
- (BOOL) isAtPrompt;


//Controlling emulation settings
//------------------------------
//While it is safe to call these directly, in most cases these should be modified through
//BXEmulatorController's wrapper functions instead, as those use Boxer-specific logic.

//Get/set the current DOSBox CPU speed setting.
//Values will be clamped to minFixedSpeed and maxFixedSpeed.
- (NSInteger) fixedSpeed;
- (void) setFixedSpeed: (NSInteger)newSpeed;
- (BOOL) validateFixedSpeed: (id *)ioValue error: (NSError **)outError;

//Get/set whether CPU speed is fixed or automatically maxed.
//NOTE: this does not correspond to the DOSBox "auto" setting but to the DOSBox "max" setting.
//The naming of this accessor should be changed to clarify this.
- (BOOL) isAutoSpeed;
- (void) setAutoSpeed: (BOOL)autoSpeed;

//Get/set the current DOSBox frameskip settings.
//Values will be clamped to minFrameskip and maxFrameskip.
- (NSUInteger) frameskip;
- (void) setFrameskip: (NSUInteger)frameskip;
- (BOOL) validateFrameskip: (id *)ioValue error: (NSError **)outError;

//Get/set for the current mouselock state.
- (BOOL) mouseLocked;
- (void) setMouseLocked: (BOOL)lock;

//Get/set the current DOSBox core emulation mode.
//NOTE: this is not currently safe to change during program execution.
- (BOOL) isDynamic;
- (void) setDynamic: (BOOL)dynamic;

- (BXCoreMode) coreMode;
- (void) setCoreMode: (BXCoreMode)coreMode;


//Input-handling
//--------------

//Used to notify the emulator that it will be interrupted by UI events.
//This will mute sound and otherwise prepare DOSBox for pausing.
- (void) willPause;
- (void) didResume;

//Used to notify the emulator that the DOS session window has gained or
//lost input focus. Updates SDL's internal state accordingly.
- (void) captureInput;
- (void) releaseInput;
- (void) activate;
- (void) deactivate;
@end


//The methods in this category should not be executed outside of BXEmulator.
@interface BXEmulator (BXEmulatorInternals)

//Called by DOSBox whenever it changes states we care about. This resyncs BXEmulator's
//cached notions of the DOSBox state, and posts notifications for relevant properties.
- (void) _syncWithEmulationState;

//Called by DOSBox whenever control returns to the DOS prompt.
//This informs the rest of Boxer via a notification.
- (void) _didReturnToShell;


//Threading
//---------

//Returns YES if called on the thread on which the emulator was started, NO otherwise.
//Irrelevant in our current single-threaded environment.
- (BOOL) _executingOnDOSBoxThread;

//Perform the specified message on the thread upon which the emulator was started.
//Used internally in a vain, failed attempt to ensure that methods are thread-safe.
- (void) _performSelectorOnDOSBoxThread:(SEL)selector withObject:(id)arg waitUntilDone:(BOOL)wait;


//Event-handling
//--------------

//Called during DOSBox's event handling function: returns YES to abort event handling
//for that loop or NO to continue it.
- (BOOL) _handleEventLoop;

@end