/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXEmulatorPrivate.h"

#import <SDL/SDL.h>
#import "cpu.h"
#import "control.h"
#import "shell.h"
#import "mapper.h"
#import "joystick.h"


#pragma mark -
#pragma mark Global tracking variables

//The singleton emulator instance. Returned by [BXEmulator currentEmulator].
static BXEmulator *currentEmulator = nil;
static BOOL hasStartedEmulator = NO;


#pragma mark -
#pragma mark Constants

//Default name that DOSBox uses when there's no process running. Used by processName for string comparisons.
NSString * const shellProcessName = @"DOSBOX";


//BXEmulatorDelegate constants, defined here for want of somewhere better to put them.

NSString * const BXEmulatorWillStartNotification					= @"BXEmulatorWillStartNotification";
NSString * const BXEmulatorDidInitializeNotification				= @"BXEmulatorDidInitializeNotification";
NSString * const BXEmulatorWillRunStartupCommandsNotification		= @"BXEmulatorWillRunStartupCommandsNotification";
NSString * const BXEmulatorDidRunStartupCommandsNotification		= @"BXEmulatorDidRunStartupCommandsNotification";
NSString * const BXEmulatorDidFinishNotification					= @"BXEmulatorDidFinishNotification";

NSString * const BXEmulatorWillStartProgramNotification				= @"BXEmulatorWillStartProgramNotification";
NSString * const BXEmulatorDidFinishProgramNotification				= @"BXEmulatorDidFinishProgramNotification";
NSString * const BXEmulatorDidReturnToShellNotification				= @"BXEmulatorDidReturnToShellNotification";

NSString * const BXEmulatorDidBeginGraphicalContextNotification		= @"BXEmulatorDidBeginGraphicalContextNotification";
NSString * const BXEmulatorDidFinishGraphicalContextNotification	= @"BXEmulatorDidFinishGraphicalContextNotification";

NSString * const BXEmulatorDidChangeEmulationStateNotification		= @"BXEmulatorDidChangeEmulationStateNotification";

NSString * const BXEmulatorDidCreateFileNotification				= @"BXEmulatorDidCreateFileNotification";
NSString * const BXEmulatorDidRemoveFileNotification				= @"BXEmulatorDidRemoveFileNotification";



//Use for strings that should be displayed to the user
NSStringEncoding BXDisplayStringEncoding	= CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSLatin1);
//Use for strings that should be left unmunged (usually filesystem paths)
NSStringEncoding BXDirectStringEncoding		= NSUTF8StringEncoding;


#pragma mark -
#pragma mark External function definitions

//Defined by us in midi.cpp
void boxer_toggleMIDIOutput(bool enabled);

//defined in dos_execute.cpp
extern const char* RunningProgram;

#if (C_DYNAMIC_X86)
//defined in core_dyn_x86.cpp
void CPU_Core_Dyn_X86_Cache_Init(bool enable_cache);
void CPU_Core_Dyn_X86_SetFPUMode(bool dh_fpu);

#elif (C_DYNREC)
//defined in core_dynrec.cpp
void CPU_Core_Dynrec_Cache_Init(bool enable_cache);
#endif


#pragma mark -
#pragma mark Implementation

@implementation BXEmulator
@synthesize processName, processPath, processLocalPath;
@synthesize delegate;
@synthesize configFiles;
@synthesize commandQueue;
@synthesize videoHandler;
@synthesize mouse, keyboard, joystick;
@synthesize cancelled, executing, initialized;


#pragma mark -
#pragma mark Class methods

//Returns the currently executing emulator instance, for DOSBox coalface functions to talk to.
+ (BXEmulator *) currentEmulator
{
	return currentEmulator;
}

//Whether it is safe to launch a new emulator instance.
+ (BOOL) canLaunchEmulator;
{
	return !hasStartedEmulator;
}

//Used by processIsInternal, to determine when we're running one of DOSBox's own builtin programs
//TODO: generate this from DOSBox's builtin program manifest instead
+ (NSSet *) internalProcessNames
{
	static NSSet *names = nil;
	if (!names) names = [[NSSet alloc] initWithObjects:
		@"IPXNET",
		@"COMMAND",
		@"KEYB",
		@"IMGMOUNT",
		@"BOOT",
		@"INTRO",
		@"RESCAN",
		@"LOADFIX",
		@"MEM",
		@"MOUNT",
		@"MIXER",
		@"CONFIG",
	nil];
	return names;
}

+ (BOOL) isInternal: (NSString *)process
{
	return [[self internalProcessNames] containsObject: process];
}

+ (NSString *) configStringForFixedSpeed: (NSInteger)speed
								  isAuto: (BOOL)isAutoSpeed
{
	if (isAutoSpeed) return @"max";
	else return [NSString stringWithFormat: @"fixed %i", speed, nil]; 
}

+ (NSString *) configStringForCoreMode: (BXCoreMode)mode
{
	switch (mode)
	{
		case BXCoreNormal:
			return @"normal";
		case BXCoreFull:
			return @"full";
		case BXCoreDynamic:
			return @"dynamic";
		case BXCoreSimple:
			return @"simple";
		default:
			return @"auto";
	}
}

+ (NSString *) configStringForGameportTimingMode: (BXGameportTimingMode)mode
{
	return (mode == BXGameportTimingClockBased) ? @"true" : @"false";
}


#pragma mark -
#pragma mark Key-value binding helper methods

//Every property depends on whether we're executing or not
+ (NSSet *) keyPathsForValuesAffectingValueForKey: (NSString *)key
{
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey: key];
	if (![key isEqualToString: @"isExecuting"]) keyPaths = [keyPaths setByAddingObject: @"isExecuting"];
	return keyPaths;
}

+ (NSSet *) keyPathsForValuesAffectingIsAtPrompt		{ return [NSSet setWithObjects: @"isRunningProcess", @"isInBatchScript", @"isInitialized", nil]; }
+ (NSSet *) keyPathsForValuesAffectingIsRunningProcess	{ return [NSSet setWithObjects: @"processName", @"processPath", nil]; }
+ (NSSet *) keyPathsForValuesAffectingProcessIsInternal	{ return [NSSet setWithObject: @"processName"]; }


#pragma mark -
#pragma mark Initialization and teardown

- (id) init
{
	if ((self = [super init]))
	{
		configFiles			= [[NSMutableArray alloc] initWithCapacity: 10];
		commandQueue		= [[NSMutableArray alloc] initWithCapacity: 4];
		driveCache			= [[NSMutableDictionary alloc] initWithCapacity: DOS_DRIVES];
		
		videoHandler		= [[BXVideoHandler alloc] init];
		
		mouse				= [[BXEmulatedMouse alloc] init];
		keyboard			= [[BXEmulatedKeyboard alloc] init];
		
		[videoHandler setEmulator: self];
	}
	return self;
}

- (void) dealloc
{	
	[self setProcessName: nil],	[processName release];
	
	[videoHandler release], videoHandler = nil;
	
	[mouse release],	mouse = nil;
	[keyboard release], keyboard = nil;
	[joystick release], joystick = nil;
	
	[driveCache release], driveCache = nil;
	[configFiles release], configFiles = nil;
	[commandQueue release], commandQueue = nil;
	
	[super dealloc];
}


#pragma mark -
#pragma mark Controlling emulation state

- (void) start
{
	if ([self isCancelled]) return;
	
	//Record ourselves as the current emulator instance for DOSBox to talk to
	currentEmulator = self;
	hasStartedEmulator = YES;
	
	[self _willStart];
	
	[self setExecuting: YES];
	
	//Start DOSBox's main loop
	[self _startDOSBox];
	
	[self setExecuting: NO];
	
	if (currentEmulator == self) currentEmulator = nil;
	
	[self _didFinish];
}

- (void) cancel
{
	if ([self isExecuting] && ![self isCancelled])
	{
		//Immediately kill audio output
		[self willPause];
		
		//Break out of DOSBox's commandline input loop
		[self discardShellInput];
	
		//Tells DOSBox to close the current shell at the end of the commandline input loop
		DOS_Shell *shell = [self _currentShell];
		if (shell) shell->exit = YES;
	}

	[self setCancelled: YES];
}

- (void) applyConfigurationAtPath: (NSString *)configPath;
{
	[configFiles addObject: configPath];
}

- (NSString *) basePath
{
	NSFileManager *manager = [[NSFileManager alloc] init];
	NSString *path = [manager currentDirectoryPath];
	[manager release];
	return path;
}

- (void) setBasePath: (NSString *)basePath
{
	NSFileManager *manager = [[NSFileManager alloc] init];
	[manager changeCurrentDirectoryPath: basePath];
	[manager release];
}



#pragma mark -
#pragma mark Introspecting emulation state

- (BOOL) isRunningProcess
{
	//Extra-safe - processPath is set earlier than processName
	return [self isExecuting] && ([self processName] || [self processPath]);
}

- (BOOL) processIsInternal
{
	if (![self isRunningProcess]) return NO;
	return [[self class] isInternal: [self processName]];
}

- (BOOL) isInBatchScript
{
	if ([self isExecuting])
	{
		DOS_Shell *shell = [self _currentShell];
		return (shell && shell->bf);		
	}
	return NO;
}

- (BOOL) isAtPrompt
{
	return [self isExecuting] && [self isInitialized] && ![self isRunningProcess] && ![self isInBatchScript];
}


#pragma mark -
#pragma mark Controlling DOSBox CPU settings

- (NSInteger) fixedSpeed
{
	NSInteger fixedSpeed = 0;
	if ([self isExecuting])
	{
		fixedSpeed = (NSInteger)CPU_CycleMax;
	}
	return fixedSpeed;
}

- (void) setFixedSpeed: (NSInteger)newSpeed
{
	if ([self isExecuting])
	{
		//Turn off automatic speed scaling
		[self setAutoSpeed: NO];
	
		CPU_OldCycleMax = CPU_CycleMax = (Bit32s)newSpeed;
		
		//Stop DOSBox from resetting the cycles after a program exits
		CPU_AutoDetermineMode &= ~CPU_AUTODETERMINE_CYCLES;
		
		//Wipe out the cycles queue: we do this because DOSBox's CPU functions do whenever they modify the cycles
		CPU_CycleLeft	= 0;
		CPU_Cycles		= 0;
	}
}

- (BOOL) isAutoSpeed
{
	BOOL autoSpeed = NO;
	if ([self isExecuting])
	{
		autoSpeed = (CPU_CycleAutoAdjust == BXSpeedAuto);
	}
	return autoSpeed;
}

- (void) setAutoSpeed: (BOOL)autoSpeed
{
	if ([self isExecuting] && [self isAutoSpeed] != autoSpeed)
	{
		//Be a good boy and record/restore the old cycles setting
		if (autoSpeed)	CPU_OldCycleMax = CPU_CycleMax;
		else			CPU_CycleMax = CPU_OldCycleMax;
		
		//Always force the usage percentage to 100
		CPU_CyclePercUsed = 100;
		
		CPU_CycleAutoAdjust = (autoSpeed) ? BXSpeedAuto : BXSpeedFixed;
	}
}

- (BXCoreMode) coreMode
{
	if ([self isExecuting])
	{
		if (cpudecoder == &CPU_Core_Normal_Run ||
			cpudecoder == &CPU_Core_Normal_Trap_Run)	return BXCoreNormal;
		
#if (C_DYNAMIC_X86)
		if (cpudecoder == &CPU_Core_Dyn_X86_Run ||
			cpudecoder == &CPU_Core_Dyn_X86_Trap_Run)	return BXCoreDynamic;
#endif
		
#if (C_DYNREC)
		if (cpudecoder == &CPU_Core_Dynrec_Run ||
			cpudecoder == &CPU_Core_Dynrec_Trap_Run)	return BXCoreDynamic;
#endif
		
		if (cpudecoder == &CPU_Core_Simple_Run)			return BXCoreSimple;
		if (cpudecoder == &CPU_Core_Full_Run)			return BXCoreFull;
		
		return BXCoreUnknown;
	}
	else return BXCoreUnknown;
}
- (void) setCoreMode: (BXCoreMode)coreMode
{
	if ([self isExecuting] && [self coreMode] != coreMode)
	{
		switch(coreMode)
		{
			case BXCoreNormal:
				cpudecoder = &CPU_Core_Normal_Run;
				break;
				
			case BXCoreDynamic:
#if (C_DYNAMIC_X86)
				CPU_Core_Dyn_X86_Cache_Init(true);
				CPU_Core_Dyn_X86_SetFPUMode(true);
				cpudecoder = &CPU_Core_Dyn_X86_Run;
#endif
				
#if (C_DYNREC)
				CPU_Core_Dynrec_Cache_Init(true);
				cpudecoder = &CPU_Core_Dynrec_Run;
#endif
				break;
			case BXCoreSimple:	
				cpudecoder = &CPU_Core_Simple_Run;
				break;
			case BXCoreFull:
				cpudecoder = &CPU_Core_Full_Run;
				break;
		}
		
		//Prevent DOSBox from resetting the core mode after a program exits
		CPU_AutoDetermineMode &= ~CPU_AUTODETERMINE_CORE;
		
		//Reset DOSBox's emulated cycles counters
		CPU_CycleLeft=0;
		CPU_Cycles=0;
	}
}


#pragma mark -
#pragma mark Handling changes to application focus

//These methods are only necessary while we are running in single-threaded mode,
//and will be the first against the wall when the multiprocess revolution comes.
- (void) willPause
{
	if ([self isExecuting] && !isInterrupted)
	{
		SDL_PauseAudio(YES);
		boxer_toggleMIDIOutput(NO);
		isInterrupted = YES;
	}
}

- (void) didResume
{	
	if ([self isExecuting] && isInterrupted)
	{
		SDL_PauseAudio(NO);
		boxer_toggleMIDIOutput(YES);
		isInterrupted = NO;
	}
}


#pragma mark -
#pragma mark Gameport emulation

- (BXGameportTimingMode) gameportTimingMode
{
	return (BXGameportTimingMode)gameport_timed;
}

- (void) setGameportTimingMode: (BXGameportTimingMode)mode
{
	if (gameport_timed != mode)
	{
		gameport_timed = mode;
		[[self joystick] clearInput];
	}
}

- (BXJoystickSupportLevel) joystickSupport
{
	switch (joytype)
	{
		case JOY_NONE:
			return BXNoJoystickSupport;
			break;
		case JOY_2AXIS:
			return BXJoystickSupportSimple;
			break;
		default:
			return BXJoystickSupportFull;
	}
}

- (id <BXEmulatedJoystick>) attachJoystickOfType: (Class)joystickType
{
	if ([self validateJoystickType: &joystickType error: nil])
	{
		//A joystick is already connected, remove it first
		if (joystick) [self detachJoystick];
		
		[self willChangeValueForKey: @"joystick"];
		joystick = [[joystickType alloc] init];
		[self didChangeValueForKey: @"joystick"];
		
		[joystick didConnect];
		return joystick;
	}
	return nil;
}

- (BOOL) detachJoystick
{
	if (!joystick) return NO;
	
	[self willChangeValueForKey: @"joystick"];
	[joystick willDisconnect];
	[joystick release];
	joystick = nil;
	[self didChangeValueForKey: @"joystick"];
	
	return YES;
}

- (BOOL) validateJoystickType: (Class *)ioValue error: (NSError **)outError
{
	Class joystickClass = *ioValue;
	
	//Nil values are just fine, skip all the other checks 
	if (!joystickClass) return YES;
	
	//Unknown classname or non-joystick class
	if (![joystickClass conformsToProtocol: @protocol(BXEmulatedJoystick)])
	{
		if (outError)
		{
			NSString *descriptionFormat = NSLocalizedString(@"“%@” is not a valid joystick type.",
															@"Format for error message when choosing an unrecognised joystick type. %@ is the classname of the chosen joystick type.");
			
			NSString *description = [NSString stringWithFormat: descriptionFormat, NSStringFromClass(joystickClass), nil];
			
			NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  description, NSLocalizedDescriptionKey,
									  joystickClass, BXEmulatedJoystickClassKey,
									  nil];
			
			*outError = [NSError errorWithDomain: BXEmulatedJoystickErrorDomain
											code: BXEmulatedJoystickInvalidType
										userInfo: userInfo];
		}
		return NO;
	}
	
	//Joystick class valid but not supported by the current session
	if ([self joystickSupport] == BXNoJoystickSupport || 
		([self joystickSupport] == BXJoystickSupportSimple && [joystickClass requiresFullJoystickSupport]))
	{
		if (outError)
		{
			NSString *localizedName	= [joystickClass localizedName];
			
			NSString *descriptionFormat = NSLocalizedString(@"Joysticks of type “%1$@” are not supported by the current session.",
															@"Format for error message when choosing an unsupported joystick type. %1$@ is the localized name of the chosen joystick type.");
			
			NSString *description = [NSString stringWithFormat: descriptionFormat, localizedName, nil];
			
			NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  description, NSLocalizedDescriptionKey,
									  joystickClass, BXEmulatedJoystickClassKey,
									  nil];
			
			*outError = [NSError errorWithDomain: BXEmulatedJoystickErrorDomain
											code: BXEmulatedJoystickUnsupportedType
										userInfo: userInfo];
		}
		return NO; 
	}
	
	//Joystick type is fine, go ahead
	return YES;
}

@end


#pragma mark -
#pragma mark Private methods

@implementation BXEmulator (BXEmulatorInternals)

- (DOS_Shell *) _currentShell
{
	return (DOS_Shell *)first_shell;
}

- (void) _postNotificationName: (NSString *)name
			  delegateSelector: (SEL)selector
					  userInfo: (NSDictionary *)userInfo
{
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	NSNotification *notification = [NSNotification notificationWithName: name
																 object: self
															   userInfo: userInfo];
	
	if ([[self delegate] respondsToSelector: selector])
		[[self delegate] performSelector: selector withObject: notification];
	
	[center postNotification: notification];
}


#pragma mark -
#pragma mark Synchronizing emulation state

//Called by coalface functions to notify Boxer that the emulation state may have changed behind its back
- (void) _didChangeEmulationState
{
	if ([self isExecuting])
	{
		[self willChangeValueForKey: @"fixedSpeed"];
		[self willChangeValueForKey: @"autoSpeed"];
		[self willChangeValueForKey: @"frameskip"];
		[self willChangeValueForKey: @"coreMode"];
		
		[self didChangeValueForKey: @"fixedSpeed"];
		[self didChangeValueForKey: @"autoSpeed"];
		[self didChangeValueForKey: @"frameskip"];
		[self didChangeValueForKey: @"coreMode"];
		
		NSString *newProcessName = [NSString stringWithCString: RunningProgram encoding: BXDirectStringEncoding];
		if ([newProcessName isEqualToString: shellProcessName]) newProcessName = nil;
		[self setProcessName: newProcessName];
		
		//Let the delegate know that the emulation state has changed behind its back, so it can re-check CPU settings
		[self _postNotificationName: BXEmulatorDidChangeEmulationStateNotification
				   delegateSelector: @selector(emulatorDidChangeEmulationState:)
						   userInfo: nil];
	}
}

- (void) _willStart
{
	[self _postNotificationName: BXEmulatorWillStartNotification
			   delegateSelector: @selector(emulatorWillStart:)
					   userInfo: nil];
}

- (void) _didInitialize
{
	[self setInitialized: YES];
	
	//These flags will only change during initialization
	[self willChangeValueForKey: @"gameportTimingMode"];
	[self willChangeValueForKey: @"joystickSupport"];
	
	[self didChangeValueForKey: @"gameportTimingMode"];
	[self didChangeValueForKey: @"joystickSupport"];
	
	//Let the delegate know that the emulation state has changed behind its back, so it can re-check CPU settings
	[self _postNotificationName: BXEmulatorDidInitializeNotification
			   delegateSelector: @selector(emulatorDidInitialize:)
					   userInfo: nil];
}

- (void) _didFinish
{
	[self _postNotificationName: BXEmulatorDidFinishNotification
			   delegateSelector: @selector(emulatorDidFinish:)
					   userInfo: nil];
}

#pragma mark -
#pragma mark Runloop handling

- (BOOL) _handleEventLoop
{
	//A bit of a misnomer, as the event loop happens in the middle of DOSBox's runloop
	[[self delegate] emulatorDidBeginRunLoop: self];
	[[self delegate] emulatorDidFinishRunLoop: self];
	return YES;
}

- (BOOL) _handleRunLoop
{
	//If emulation has been cancelled or we otherwise want to wrest control away
	//from DOSBox, then break out of the current DOSBox run loop.
	//TWEAK: it's only safe to break out once initialization is done, since some
	//of DOSBox's initialization routines rely on running tasks on the run loop
	//and may crash if they fail to complete.
	if ([self isCancelled] && [self isInitialized]) return YES;

	//If we have a command of our own waiting at the command prompt, then break out of DOSBox's stdin input loop
	if ([[self commandQueue] count] && [self isAtPrompt]) return YES;
	
	return NO;
}


//This is a cut-down and mashed-up version of DOSBox's old main and GUI_StartUp functions,
//chopping out all the stuff that Boxer doesn't need or want.
- (void) _startDOSBox
{
	//Initialize the SDL modules that DOSBox will need.
	NSAssert1(!SDL_Init(SDL_INIT_AUDIO|SDL_INIT_TIMER|SDL_INIT_CDROM|SDL_INIT_NOPARACHUTE),
			  @"SDL failed to initialize with the following error: %s", SDL_GetError());
	
	try
	{
		//Create a new configuration instance and feed it an empty set of parameters.
		char const *argv[0];
		CommandLine commandLine(0, argv);
		Config configuration(&commandLine);
		control=&configuration;
		
		//Sets up the vast swathes of DOSBox configuration file parameters,
		//and registers the shell to start up when we finish initializing.
		DOSBOX_Init();

		//Load up Boxer's own configuration files
		for (NSString *configPath in [self configFiles])
		{
			configPath = [configPath stringByStandardizingPath];
			const char *encodedConfigPath = [configPath fileSystemRepresentation];
			control->ParseConfigFile(encodedConfigPath);
		}

		//Initialise the configuration.
		control->Init();
		
		[self _didInitialize];
		
		//Start up the main machine.
		control->StartUp();
	}
	catch (char *errMessage)
	{
		NSLog(@"DOSBox died with the following error: %s",
			  [NSString stringWithCString: errMessage encoding: BXDirectStringEncoding]);
	}
	catch (int)
	{
		//This means that something pressed the killswitch in DOSBox and we should shut down normally.
	}
	//Any other exception is a genuine fuckup and needs to be thrown all the way up.
	
	//Shut down SDL after DOSBox exits.
	SDL_Quit();
	
	
	//Clean up after DOSBox finishes
	[[self videoHandler] shutdown];
}

@end
