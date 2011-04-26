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


@class BXInputHandler;
@class BXVideoHandler;
@class BXEmulatedKeyboard;

@protocol BXEmulatorDelegate;

@interface BXEmulator : NSObject
{
	id <BXEmulatorDelegate> delegate;
	BXInputHandler *inputHandler;
	BXVideoHandler *videoHandler;
	BXEmulatedKeyboard *keyboard;
	
	NSString *processName;
	NSString *processPath;
	NSString *processLocalPath;
	
	NSMutableArray *configFiles;
	NSMutableDictionary *driveCache;
	
	BOOL cancelled;
	BOOL executing;
	BOOL isInterrupted;
	
	//Used by BXShell
	NSMutableArray *commandQueue;
}


#pragma mark -
#pragma mark Members

//The delegate responsible for this emulator.
@property (assign, nonatomic) id <BXEmulatorDelegate> delegate;

@property (readonly, nonatomic) BXInputHandler *inputHandler;	//Our DOSBox input handler.
@property (readonly, nonatomic) BXVideoHandler *videoHandler;	//Our DOSBox video and rendering handler.
@property (readonly, nonatomic) BXEmulatedKeyboard *keyboard;	//Our emulated keyboard.

//An array of OS X paths to configuration files that will be/have been loaded by this session during startup.
//This is read-only: configuration files can be loaded via applyConfigurationAtPath: 
@property (readonly, nonatomic) NSArray *configFiles;

//An array of queued command strings to execute on the DOS command line.
@property (readonly, nonatomic) NSMutableArray *commandQueue;


#pragma mark -
#pragma mark Introspecting emulation state

//Whether the emulator is currently running/cancelled respectively. Mirrors interface of NSOperation.
//The setters are for internal use only and should not be called outside of BXEmulator.
@property (assign, nonatomic, getter=isExecuting) BOOL executing;
@property (assign, nonatomic, getter=isCancelled) BOOL cancelled;

//Whether DOSBox is currently running a process.
@property (readonly, nonatomic) BOOL isRunningProcess;

//Returns whether the current process (if any) is an internal process.
@property (readonly, nonatomic) BOOL processIsInternal;

//Returns whether DOSBox is currently inside a batch script.
@property (readonly, nonatomic) BOOL isInBatchScript;

//Returns whether DOSBox is waiting patiently at the DOS prompt doing nothing.
@property (readonly, nonatomic) BOOL isAtPrompt;


//The following three accessors are intended to be readonly;
//they are only left as read-write for BXEmulator categories.

//The name of the currently-executing DOSBox process. Will be nil if no process is running.
@property (copy, nonatomic) NSString *processName;

//The DOS filesystem path of the currently-executing DOSBox process.
//Will be nil if no process is running.
@property (copy, nonatomic) NSString *processPath;

//The local filesystem path of the currently-executing DOSBox process.
//Will be nil if no process is running or if the process is on an image or DOSBox-internal drive.
@property (copy, nonatomic) NSString *processLocalPath;


#pragma mark -
#pragma mark Controlling emulation state

//The current fixed CPU speed.
@property (assign, nonatomic) NSInteger fixedSpeed;

//Whether we are running at automatic maximum speed.
@property (assign, getter=isAutoSpeed) BOOL autoSpeed;

//The current CPU core mode.
@property (assign, nonatomic) BXCoreMode coreMode;

//The OS X filesystem path to which the emulator should resolve relative local filesystem paths.
//This is used by DOSBox commands like MOUNT, IMGMOUNT and CONFIG, and is directly equivalent
//to the current process's working directory.
@property (copy, nonatomic) NSString *basePath;


#pragma mark -
#pragma mark Class methods

//Returns the currently active DOS session.
+ (BXEmulator *) currentEmulator;

//Whether it is safe to launch a new emulator instance. Will be NO after an emulator has been opened
//(and the memory state is too polluted to reuse.)
+ (BOOL) canLaunchEmulator;

//An array of names of internal DOSBox processes.
+ (NSSet *) internalProcessNames;

//Returns whether the specified process name is a DOSBox internal process (according to internalProcessNames).
+ (BOOL) isInternal: (NSString *)processName;

//Returns the configuration values that reflect the specified settings.
+ (NSString *) configStringForFixedSpeed: (NSInteger)speed isAuto: (BOOL)isAutoSpeed;
+ (NSString *) configStringForCoreMode: (BXCoreMode)mode;


#pragma mark -
#pragma mark Controlling emulation state

//Begin emulation.
- (void) start;

//Stop emulation.
- (void) cancel;

//Load the DOSBox configuration file at the specified path.
//Currently, this only takes effect if done before [BXEmulator start] is called.
- (void) applyConfigurationAtPath: (NSString *)configPath;


#pragma mark -
#pragma mark Responding to application state

//Used to notify the emulator that it will be interrupted by UI events.
//This will mute sound and otherwise prepare DOSBox for pausing.
- (void) willPause;
- (void) didResume;

@end