/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXEmulator.h"
#import "BXSession+BXEmulatorController.h"

#import "BXEmulator+BXShell.h"
#import "BXInputHandler.h"
#import "BXVideoHandler.h"

#import <SDL/SDL.h>
#import "config.h"
#import "cpu.h"
#import "control.h"
#import "shell.h"
#import "mapper.h"
#import "callback.h"

#import <crt_externs.h>		//for _NSGetArgc() and _NSGetArgv()

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


BXEmulator *currentEmulator = nil;


@implementation BXEmulator
@synthesize processName, processPath, processLocalPath;
@synthesize delegate, thread;
@synthesize minFixedSpeed, maxFixedSpeed, maxFrameskip;
@synthesize configFiles;
@synthesize commandQueue;
@synthesize inputHandler;
@synthesize videoHandler;


//Introspective class methods
//---------------------------

//Used by processIsInternal, to determine when we're running one of DOSBox's own builtin programs
//TODO: generate this from DOSBox's builtin program manifest instead
+ (NSArray *) internalProcessNames
{
	static NSArray *names = nil;
	if (!names) names = [[NSArray alloc] initWithObjects:
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


//Key-value binding-related class methods
//---------------------------------------

//Every property also depends on whether we're executing or not
+ (NSSet *) keyPathsForValuesAffectingValueForKey: (NSString *)key
{
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey: key];
	if (![key isEqualToString: @"isExecuting"]) keyPaths = [keyPaths setByAddingObject: @"isExecuting"];
	return keyPaths;
}

+ (NSSet *) keyPathsForValuesAffectingMouseLocked		{ return [NSSet setWithObject: @"fullScreen"]; }
+ (NSSet *) keyPathsForValuesAffectingDynamic			{ return [NSSet setWithObject: @"coreMode"]; }

+ (NSSet *) keyPathsForValuesAffectingIsAtPrompt		{ return [NSSet setWithObjects: @"isRunningProcess", @"isInBatchScript", nil]; }
+ (NSSet *) keyPathsForValuesAffectingIsRunningProcess	{ return [NSSet setWithObjects: @"processName", @"processPath", nil]; }
+ (NSSet *) keyPathsForValuesAffectingProcessIsInternal	{ return [NSSet setWithObject: @"processName"]; }


+ (BXEmulator *) currentEmulator
{
	return currentEmulator;
}

- (id) init
{
	if ((self = [super init]))
	{
		//Todo: bind these to hidden preferences instead?
		maxFixedSpeed		= BXMaxSpeedThreshold;
		minFixedSpeed		= BXMinSpeedThreshold;
		maxFrameskip		= 9;
		
		configFiles			= [[NSMutableArray alloc] initWithCapacity: 10];
		commandQueue		= [[NSMutableArray alloc] initWithCapacity: 4];
		driveCache			= [[NSMutableDictionary alloc] initWithCapacity: DOS_DRIVES];
		
		[self setInputHandler: [[[BXInputHandler alloc] init] autorelease]];
		[self setVideoHandler: [[[BXVideoHandler alloc] init] autorelease]];
		[[self inputHandler] setEmulator: self];
		[[self videoHandler] setEmulator: self];
	}
	return self;
}

- (void) dealloc
{
	[self setProcessName: nil],	[processName release];
	[self setInputHandler: nil], [inputHandler release];
	[self setVideoHandler: nil], [videoHandler release];
	
	[driveCache release], driveCache = nil;
	[configFiles release], configFiles = nil;
	[commandQueue release], commandQueue = nil;
	
	[super dealloc];
	
	NSLog(@"BXEmulator dealloc");
}


//Threading and operation control
//-------------------------------

- (void) main
{
	currentEmulator = self;
	
	//Record the thread we are running on for comparisons later
	//We don't retain it since presumably it will always outlive us
	thread = [NSThread currentThread];
	
	//Start DOSBox's main loop
	[self _startDOSBox];
	
	//Clean up after DOSBox finishes
	[[self videoHandler] shutdown];
	
	if (currentEmulator == self) currentEmulator = nil;
	
	NSLog(@"BXEmulator end of main");
}



//Introspecting emulation state
//-----------------------------

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
	DOS_Shell *shell = [self _currentShell];
	return (shell && shell->bf);
}

- (BOOL) isAtPrompt
{
	return ![self isRunningProcess] && ![self isInBatchScript];
}


//Controlling emulation state
//---------------------------

- (NSUInteger) frameskip
{
	return [[self videoHandler] frameskip];
}

- (void) setFrameskip: (NSUInteger)frameskip
{
	[self willChangeValueForKey: @"frameskip"];
	[[self videoHandler] setFrameskip: frameskip];
	[self didChangeValueForKey: @"frameskip"];
}

- (BOOL) validateFrameskip: (id *)ioValue error: (NSError **)outError
{
	NSInteger theValue = [*ioValue integerValue];
	if		(theValue < 0)						*ioValue = [NSNumber numberWithInteger: 0];
	else if	(theValue > [self maxFrameskip])	*ioValue = [NSNumber numberWithInteger: [self maxFrameskip]];
	return YES;
}



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
		[self willChangeValueForKey: @"fixedSpeed"];
		
		//Turn off automatic speed scaling
		[self setAutoSpeed: NO];
	
		CPU_OldCycleMax = CPU_CycleMax = (Bit32s)newSpeed;
		
		//Wipe out the cycles queue - we do this because DOSBox's CPU functions do whenever they modify the cycles
		CPU_CycleLeft	= 0;
		CPU_Cycles		= 0;
		
		[self didChangeValueForKey: @"fixedSpeed"];
	}
}

- (BOOL) validateFixedSpeed: (id *)ioValue error: (NSError **)outError
{
	NSInteger	min = [self minFixedSpeed],
				max	= [self maxFixedSpeed],
				theValue = [*ioValue integerValue];
	if		(theValue < min) *ioValue = [NSNumber numberWithInteger: min];
	else if	(theValue > max) *ioValue = [NSNumber numberWithInteger: max];
	return YES;
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
		[self willChangeValueForKey: @"autoSpeed"];
		
		//Be a good boy and record/restore the old cycles setting
		if (autoSpeed)	CPU_OldCycleMax = CPU_CycleMax;
		else			CPU_CycleMax = CPU_OldCycleMax;
		
		//Always force the usage percentage to 100
		CPU_CyclePercUsed = 100;
		
		CPU_CycleAutoAdjust = (autoSpeed) ? BXSpeedAuto : BXSpeedFixed;
		
		[self didChangeValueForKey: @"autoSpeed"];
	}
}


//CPU emulation
//-------------

//Note: these work but are currently unused. This is because this implementation is just too simple; games may crash when the emulation mode is arbitrarily changed in the middle of program execution, so instead we should queue this up and require an emulation restart for it to take effect.
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
		//We change the core by feeding command settings to Config
		NSString *modeName;
		switch(coreMode)
		{
			case BXCoreNormal:	modeName = @"normal";	break;
			case BXCoreDynamic:	modeName = @"dynamic";	break;
			case BXCoreSimple:	modeName = @"simple";	break;
			case BXCoreFull:	modeName = @"full";		break;
		}
		if (modeName)
		{
			NSInteger currentSpeed		= [self fixedSpeed];
			BOOL currentSpeedIsAuto		= [self isAutoSpeed];
			
			[self setConfig: @"core" to: modeName];
			
			//Changing the core mode will revert the speed settings, so we need to reset them manually afterwards
			//Todo: try to avoid the momentary flash of old values this causes
			[self setFixedSpeed: currentSpeed];
			[self setAutoSpeed: currentSpeedIsAuto];
		}
	}
}
- (BOOL) isDynamic	{ return [self coreMode] == BXCoreDynamic; }

//Todo: make this use the previous core mode, instead of just assuming normal
- (void) setDynamic: (BOOL)dynamic
{
	[self setCoreMode: ([self coreMode] == BXCoreDynamic) ? BXCoreNormal : BXCoreDynamic];
}


//Handling changes to application focus
//-------------------------------------

//These methods are only necessary if we are running in single-threaded mode,
//which currently is indicated by the isConcurrent flag
- (void) willPause
{
	
	if ([self isConcurrent] && [self isExecuting] && !isInterrupted)
	{
		SDL_PauseAudio(YES);
		boxer_toggleMIDIOutput(NO);
		isInterrupted = YES;
	}
}

- (void) didResume
{
	
	if ([self isConcurrent] && [self isExecuting] && isInterrupted)
	{
		SDL_PauseAudio(NO);
		boxer_toggleMIDIOutput(YES);
		isInterrupted = NO;
	}
}

- (void) cancel
{
	DOS_Shell *shell = [self _currentShell];
	if (shell) shell->exit = YES;
	[super cancel];
}
@end


@implementation BXEmulator (BXEmulatorInternals)

- (DOS_Shell *) _currentShell
{
	return (DOS_Shell *)first_shell;
}

- (void) _postNotificationName: (NSString *)name
			  delegateSelector: (SEL)selector
					  userInfo: (id)userInfo
{
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	NSNotification *notification = [NSNotification notificationWithName: name
																 object: self
															   userInfo: userInfo];
	
	BXSession *theSession = [self delegate];
	if (theSession && [theSession respondsToSelector: selector]) [theSession performSelector: selector withObject: notification];
	
	[center postNotification: notification];
}


//Synchronising emulation state
//-----------------------------

//Post change notifications on all likely properties to resync KVC bindings
//This is called by coalface functions to notify Boxer that the emulation state may have changed behind its back
- (void) _syncWithEmulationState
{
	if ([self isExecuting])
	{
		//Post event notifications for settings we have no way of detecting changes to,
		//so that all bound objects will update just in case
		[self willChangeValueForKey:	@"mouseLocked"];
		[self didChangeValueForKey:		@"mouseLocked"];
		
		[self willChangeValueForKey:	@"fixedSpeed"];
		[self didChangeValueForKey:		@"fixedSpeed"];
		
		[self willChangeValueForKey:	@"autoSpeed"];
		[self didChangeValueForKey:		@"autoSpeed"];
		
		[self willChangeValueForKey:	@"frameskip"];
		[self didChangeValueForKey:		@"frameskip"];
		
		[self willChangeValueForKey:	@"coreMode"];
		[self didChangeValueForKey:		@"coreMode"];
		
		
		//Now perform fine-grained checking on the process name, and post appropriate notifications
		
		NSString *newProcessName = [NSString stringWithCString: RunningProgram encoding: BXDirectStringEncoding];
		if ([newProcessName isEqualToString: shellProcessName]) newProcessName = nil;
		[self setProcessName: newProcessName];
		
		//Update our max fixed speed if the real speed has gone higher
		//this allows us to gracefully handle extra-high speeds imposed by game settings
		//Disabled for now, since we have implemented the banded CPU slider any adjustments to the max speed will fuck with its shit - will reenable this when I write code to sync changes to this with the highest slider band
		
		//NSInteger newFixedSpeed = [self fixedSpeed];
		//if (newFixedSpeed > [self maxFixedSpeed]) [self setMaxFixedSpeed: newFixedSpeed];
	}
}


//Event-handling
//--------------

- (BOOL) _handleEventLoop
{
	//Implementation note: in a better world, this code wouldn't be here as event dispatch is normally done
	//automatically by NSApplication at opportune moments. However, DOSBox's emulation loop completely takes
	//over the application's main thread, leaving no time for events to get processed and dispatched.
	//This explicitly pumps NSApplication's event queue for all pending events and sends them on their way.
	
	if ([NSThread currentThread] == [NSThread mainThread])
	{
		NSEvent *event;
		while (event = [NSApp nextEventMatchingMask: NSAnyEventMask untilDate: nil inMode: NSDefaultRunLoopMode dequeue: YES])
			[NSApp sendEvent: event];
				
	}
	return YES;
}

- (BOOL) _handleRunLoop
{
	if ([self isCancelled]) return YES;
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
		//Create a new configuration instance and feed it our commandline parameters (ugh)
		//TODO: use our own (empty) argc and argv instead of these.
		
		CommandLine commandLine(*_NSGetArgc(), *_NSGetArgv());
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
	catch (char * error)
	{
		NSLog(@"DOSBox died with the following error: %@",
			  [NSString stringWithCString: error encoding: BXDirectStringEncoding]);
	}
	catch (int)
	{
		//This means that something pressed the killswitch in DOSBox and we should shut down normally.
	}
	//Any other exception is a genuine fuckup and needs to be thrown all the way up.
	
	//Shut down SDL after DOSBox exits.
	SDL_Quit();
	
	
	//Cleanup leftover globals
	cpu = CPUBlock();
	dos = DOS_Block();
	control = NULL;
	cpudecoder = &CPU_Core_Normal_Run;
	
	SDLNetInited = NO;
	machine = MCH_HERC;
	svgaCard = SVGA_None;
	
	CPU_Cycles = 3000;
	CPU_CycleLeft = 3000;
	CPU_CycleMax = 3000;
	CPU_OldCycleMax = 3000;
	CPU_CyclePercUsed = 100;
	CPU_CycleLimit = -1;
	CPU_IODelayRemoved = 0;
	CPU_CycleAutoAdjust = false;
	CPU_SkipCycleAutoAdjust = false;
	CPU_AutoDetermineMode = 0;
	CPU_ArchitectureType = CPU_ARCHTYPE_MIXED;
	CPU_PrefetchQueueSize = 0;
}

@end