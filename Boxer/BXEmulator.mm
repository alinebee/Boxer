/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//For NSEvent and NSApp
#import <Cocoa/Cocoa.h>

#import "BXEmulatorPrivate.h"
#import "BXEmulatorDelegate.h"

#import <SDL/SDL.h>
#import "cpu.h"
#import "control.h"
#import "shell.h"
#import "mapper.h"


//The singleton emulator instance. Returned by [BXEmulator currentEmulator].
static BXEmulator *currentEmulator = nil;
static BOOL hasStartedEmulator = NO;


//Default name that DOSBox uses when there's no process running. Used by processName for string comparisons.
NSString * const shellProcessName = @"DOSBOX";


//String encodings to use when talking to DOSBox
//----------------------------------------------

//Use for strings that should be displayed to the user
NSStringEncoding BXDisplayStringEncoding	= CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSLatin1);
//Use for strings that should be left unmunged (usually filesystem paths)
NSStringEncoding BXDirectStringEncoding		= NSUTF8StringEncoding;


//DOSBox functions and vars we hook into
//--------------------------------------

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
@synthesize inputHandler;
@synthesize videoHandler;
@synthesize cancelled, executing;


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

+ (NSString *) configStringForFixedSpeed: (NSInteger)speed isAuto: (BOOL)isAutoSpeed
{
	if (isAutoSpeed) return @"max";
	else return [[NSNumber numberWithInteger: speed] stringValue]; 
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


#pragma mark -
#pragma mark Key-value binding helper methods

//Every property depends on whether we're executing or not
+ (NSSet *) keyPathsForValuesAffectingValueForKey: (NSString *)key
{
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey: key];
	if (![key isEqualToString: @"isExecuting"]) keyPaths = [keyPaths setByAddingObject: @"isExecuting"];
	return keyPaths;
}

+ (NSSet *) keyPathsForValuesAffectingIsAtPrompt		{ return [NSSet setWithObjects: @"isRunningProcess", @"isInBatchScript", nil]; }
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
		
		inputHandler		= [[BXInputHandler alloc] init];
		videoHandler		= [[BXVideoHandler alloc] init];
		[inputHandler setEmulator: self];
		[videoHandler setEmulator: self];
	}
	return self;
}

- (void) dealloc
{	
	[self setProcessName: nil],	[processName release];
	
	[inputHandler release], inputHandler = nil;
	[videoHandler release], videoHandler = nil;
	[driveCache release], driveCache = nil;
	[configFiles release], configFiles = nil;
	[commandQueue release], commandQueue = nil;
	
	[super dealloc];
}


#pragma mark -
#pragma mark Controlling emulation state

- (void) start
{
	[self setExecuting: YES];
	
	//Record ourselves as the current emulator instance for DOSBox to talk to
	currentEmulator = self;
	hasStartedEmulator = YES;
	
	//Start DOSBox's main loop
	[self _startDOSBox];
	
	if (currentEmulator == self) currentEmulator = nil;
	
	[self setExecuting: NO];
}

- (void) cancel
{
	if ([self isExecuting] && ![self isCancelled])
	{
		//Breaks out of DOSBox's commandline input loop
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
	return [self isExecuting] && ![self isRunningProcess] && ![self isInBatchScript];
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
		//Let the delegate know that the emulation state has changed behind its back, so it can re-check CPU settings
		[self _postNotificationName: @"BXEmulationStateDidChange"
				   delegateSelector: @selector(didChangeEmulationState:)
						   userInfo: nil];
		
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
	}
}


#pragma mark -
#pragma mark Runloop handling

- (BOOL) _handleEventLoop
{
	//Implementation note: in a better world, this code wouldn't be here as event dispatch is normally done
	//automatically by NSApplication at opportune moments. However, DOSBox's emulation loop completely takes
	//over the application's main thread, leaving no time for events to get processed and dispatched.
	//This explicitly pumps NSApplication's event queue for all pending events and sends them on their way.
	
	if ([NSThread currentThread] == [NSThread mainThread])
	{
		NSEvent *event;
		while ((event = [NSApp nextEventMatchingMask: NSAnyEventMask untilDate: nil inMode: NSDefaultRunLoopMode dequeue: YES]))
			[NSApp sendEvent: event];

	}
	return YES;
}

- (BOOL) _handleRunLoop
{
	//If emulation has been cancelled, then break out of the current DOSBox run loop
	if ([self isCancelled]) return YES;
	
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
		
		//Registers the mapper's initialiser and configuration file parser.
		control->AddSection_prop("sdl", &MAPPER_StartUp);

		//Load up Boxer's own configuration files
		for (NSString *configPath in [self configFiles])
		{
			configPath = [configPath stringByStandardizingPath];
			const char * encodedConfigPath = [configPath cStringUsingEncoding: BXDirectStringEncoding];
			control->ParseConfigFile((const char * const)encodedConfigPath);
		}

		//Initialise the configuration.
		control->Init();
		 
		//Initialise the key mapper.
		MAPPER_Init();
		
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
