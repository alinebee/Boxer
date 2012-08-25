/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXEmulatorPrivate.h"
#import "NSObject+BXPerformExtensions.h"

#import <SDL/SDL.h>
#import "cpu.h"
#import "control.h"
#import "shell.h"
#import "mapper.h"
#import "joystick.h"


#pragma mark -
#pragma mark Global tracking variables

//The singleton emulator instance. Returned by [BXEmulator currentEmulator].
static BXEmulator *_currentEmulator = nil;
static BOOL _hasStartedEmulator = NO;


#pragma mark -
#pragma mark Constants

//The name and path to the DOSBox shell. Used when determining the current process.
NSString * const shellProcessName = @"DOSBOX";
NSString * const shellProcessPath = @"Z:\\COMMAND.COM";


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


NSString * const BXEmulatorDOSPathKey           = @"DOSPath";
NSString * const BXEmulatorDriveKey             = @"drive";
NSString * const BXEmulatorLocalPathKey         = @"localPath";
NSString * const BXEmulatorLaunchArgumentsKey   = @"arguments";


//Use for strings that should be displayed to the user
NSStringEncoding BXDisplayStringEncoding	= CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSLatin1);
//Use for strings that should be left unmunged (usually filesystem paths)
NSStringEncoding BXDirectStringEncoding		= NSUTF8StringEncoding;

NSString * const BXDOSBoxErrorDomain = @"BXDOSBoxErrorDomain";


#pragma mark -
#pragma mark External function definitions

//defined in dos_execute.cpp
extern const char* RunningProgram;

//defined in dosbox.cpp
extern bool ticksLocked;

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
@synthesize processName = _processName;
@synthesize runningProcesses = _runningProcesses;
@synthesize delegate = _delegate;
@synthesize videoHandler = _videoHandler;
@synthesize mouse = _mouse;
@synthesize keyboard = _keyboard;
@synthesize cancelled = _cancelled;
@synthesize executing = _executing;
@synthesize initialized = _initialized;
@synthesize paused = _paused;

@synthesize commandQueue = _commandQueue;
@synthesize emulationThread = _emulationThread;
@synthesize clearsScreenBeforeCommandExecution = _clearsScreenBeforeCommandExecution;

@synthesize activeMIDIDevice = _activeMIDIDevice;
@synthesize requestedMIDIDeviceDescription = _requestedMIDIDeviceDescription;
@synthesize autodetectsMT32 = _autodetectsMT32;
@synthesize masterVolume = _masterVolume;
@synthesize keyBuffer = _keyBuffer;
@synthesize waitingForCommandInput = _waitingForCommandInput;


#pragma mark -
#pragma mark Class methods

//Returns the currently executing emulator instance, for DOSBox coalface functions to talk to.
+ (BXEmulator *) currentEmulator
{
	return [[_currentEmulator retain] autorelease];
}

//Whether it is safe to launch a new emulator instance.
+ (BOOL) canLaunchEmulator;
{
	return !_hasStartedEmulator;
}

+ (NSString *) configStringForFixedSpeed: (NSInteger)speed
								  isAuto: (BOOL)isAutoSpeed
{
	if (isAutoSpeed) return @"max";
	else return [NSString stringWithFormat: @"fixed %i", speed]; 
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

+ (NSSet *) keyPathsForValuesAffectingIsAtPrompt
{
    return [NSSet setWithObjects: @"isRunningProcess", @"isInBatchScript", @"isInitialized", nil];
}

+ (NSSet *) keyPathsForValuesAffectingIsRunningProcess	{ return [NSSet setWithObjects: @"processName", @"processPath", nil]; }
+ (NSSet *) keyPathsForValuesAffectingProcessIsInternal	{ return [NSSet setWithObject: @"processName"]; }


#pragma mark -
#pragma mark Initialization and teardown

- (id) init
{
	if ((self = [super init]))
	{
        _runningProcesses       = [[NSMutableArray alloc] initWithCapacity: 1];
		_commandQueue           = [[NSMutableArray alloc] initWithCapacity: 4];
		_driveCache             = [[NSMutableDictionary alloc] initWithCapacity: DOS_DRIVES];
		_pendingSysexMessages   = [[NSMutableArray alloc] initWithCapacity: 4];
        
        self.masterVolume = 1.0f;
		
        self.keyboard = [[[BXEmulatedKeyboard alloc] init] autorelease];
        self.mouse = [[[BXEmulatedMouse alloc] init] autorelease];
        
        self.videoHandler = [[[BXVideoHandler alloc] init] autorelease];
		self.videoHandler.emulator = self;
        
        self.keyBuffer = [[[BXKeyBuffer alloc] init] autorelease];
        
    }
	return self;
}

- (void) dealloc
{	
    self.processName = nil;
    self.activeMIDIDevice = nil;
    self.requestedMIDIDeviceDescription = nil;
    
    self.keyboard = nil;
    self.mouse = nil;
    self.joystick = nil;
    self.videoHandler = nil;
    self.keyBuffer = nil;
    
    [_runningProcesses release], _runningProcesses = nil;
	[_driveCache release], _driveCache = nil;
	[_commandQueue release], _commandQueue = nil;
    [_pendingSysexMessages release], _pendingSysexMessages = nil;
	
	[super dealloc];
}


#pragma mark -
#pragma mark Controlling emulation state

- (void) start
{
    NSAssert(!_hasStartedEmulator, @"Emulation session started after one has already been started.");
    
	if (self.isCancelled) return;
    
    self.emulationThread = [NSThread currentThread];
	
	//Record ourselves as the current emulator instance for DOSBox to talk to
    if (!_currentEmulator)
    {
        _currentEmulator = [self retain];
    }
	_hasStartedEmulator = YES;
	
	[self _willStart];
	
	self.executing = YES;
	
	//Start DOSBox's main loop
	[self _startDOSBox];
	
	self.executing = NO;
	
	if (_currentEmulator == self)
    {
        [_currentEmulator autorelease];
        _currentEmulator = nil;
	}
    
	[self _didFinish];
}

- (void) cancel
{
    if (self.emulationThread && [NSThread currentThread] != self.emulationThread)
    {
        [self performSelector: _cmd onThread: self.emulationThread withObject: nil waitUntilDone: NO];
    }
    else
    {
        if (self.isExecuting && !self.isCancelled)
        {
            //Immediately kill audio output to avoid hanging notes
            [self pause];
        
            //Tells DOSBox to close the current shell at the end of the commandline input loop
            DOS_Shell *shell = self._currentShell;
            if (shell) shell->exit = YES;
        }

        self.cancelled = YES;
    }
}

+ (NSSet *) keyPathsForValuesAffectingConcurrent
{
    return [NSSet setWithObject: @"emulationThread"];
}

- (BOOL) isConcurrent
{
    return (self.emulationThread && self.emulationThread != [NSThread mainThread]);
}


- (NSString *) basePath
{
    NSString *path;
    @synchronized(self)
    {
        NSFileManager *manager = [[NSFileManager alloc] init];
        path = [[manager currentDirectoryPath] retain];
        [manager release];
    }
	return [path autorelease];
}

- (void) setBasePath: (NSString *)basePath
{
    @synchronized(self)
    {
        NSFileManager *manager = [[NSFileManager alloc] init];
        [manager changeCurrentDirectoryPath: basePath];
        [manager release];
    }
}



#pragma mark -
#pragma mark Introspecting emulation state

- (BOOL) isRunningProcess
{
    return self.processPath && ![self.processPath isEqualToString: shellProcessPath];
}

+ (NSSet *) keyPathsForValuesAffectingProcessPath
{
    return [NSSet setWithObject: @"runningProcesses"];
}

- (NSString *) processPath
{
    NSDictionary *currentProcess = [_runningProcesses lastObject];
    return [currentProcess objectForKey: BXEmulatorDOSPathKey];
}

+ (NSSet *) keyPathsForValuesAffectingProcessLocalPath
{
    return [NSSet setWithObject: @"runningProcesses"];
}

- (NSString *) processLocalPath
{
    NSDictionary *currentProcess = [_runningProcesses lastObject];
    return [currentProcess objectForKey: BXEmulatorLocalPathKey];
}

- (BOOL) processIsInternal
{
	if (!self.isRunningProcess) return NO;
    
    //Count any programs on drive Z as being internal
	return [self.processPath characterAtIndex: 0] == 'Z';
}

- (BOOL) isInBatchScript
{
	if (self.isExecuting)
	{
		DOS_Shell *shell = self._currentShell;
		return (shell && shell->bf);		
	}
	return NO;
}

- (BOOL) isAtPrompt
{
    if (!self.isExecuting) return NO;
    
    if (!self.isInitialized) return NO;
    if (self.isInBatchScript) return NO;
    if (self.isRunningProcess) return NO;
    
    return YES;
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
        //While in turbo mode, report the value we had before we entered turbo.
        if (self.isTurboSpeed) autoSpeed = _wasAutoSpeed;
        else autoSpeed = (CPU_CycleAutoAdjust == BXSpeedAuto);
	}
	return autoSpeed;
}

- (void) setAutoSpeed: (BOOL)autoSpeed
{
	if ([self isExecuting] && [self isAutoSpeed] != autoSpeed)
	{
        //While we're in turbo, don't change the auto-speed setting directly;
        //instead, set the value we'll return to when we come out of turbo.
        if (self.isTurboSpeed)
        {
            _wasAutoSpeed = autoSpeed;
        }
        else
        {
            //Be a good boy and record/restore the old cycles setting
            if (autoSpeed)	CPU_OldCycleMax = CPU_CycleMax;
            else			CPU_CycleMax = CPU_OldCycleMax;
            
            //Always force the usage percentage to 100
            CPU_CyclePercUsed = 100;
            
            CPU_CycleAutoAdjust = (autoSpeed) ? BXSpeedAuto : BXSpeedFixed;
        }
	}
}

- (BOOL) isTurboSpeed
{
    return ticksLocked;
}

- (void) setTurboSpeed: (BOOL)turboSpeed
{
    if (turboSpeed != self.isTurboSpeed)
    {
        if (turboSpeed)
        {
            ticksLocked = YES;
            
            _wasAutoSpeed = (CPU_CycleAutoAdjust == BXSpeedAuto);
            //Suppress auto-speed temporarily
            if (_wasAutoSpeed)
            {
                CPU_CycleAutoAdjust = NO;
                //Hurray, magic numbers!
                CPU_CycleMax /= 3;
                if (CPU_CycleMax < 1000) CPU_CycleMax = 1000;
            }
        }
        else
        {
            ticksLocked = NO;
            
            //Restore the previous auto-speed value.
            if (_wasAutoSpeed)
            {
                _wasAutoSpeed = NO;
                CPU_CycleAutoAdjust = BXSpeedAuto;
                //TODO: should we set this using setAutoSpeed:?
            }
        }
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

- (void) pause
{
	if (!self.isPaused)
	{
        if (self.emulationThread && [NSThread currentThread] != self.emulationThread)
        {
            [self performSelector: _cmd onThread: self.emulationThread withObject: nil waitUntilDone: NO];
        }
        else
        {
            @synchronized(self)
            {
                self.paused = YES;
                [self _suspendAudio];
            }
        }
	}
}

- (void) resume
{	
	if (self.isPaused)
    {
        if (self.emulationThread && [NSThread currentThread] != self.emulationThread)
        {
            [self performSelector: _cmd onThread: self.emulationThread withObject: nil waitUntilDone: NO];
        }
        else
        {
            @synchronized(self)
            {
                self.paused = NO;
                [self _resumeAudio];
            }
        }
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
    @synchronized(self)
    {
        if (gameport_timed != mode)
        {
            gameport_timed = mode;
            [self.joystick clearInput];
        }
    }
}

- (BOOL) joystickActive
{
    return _joystickActive;
}

- (void) setJoystickActive: (BOOL)flag
{
    @synchronized(self)
    {
        //TWEAK: disregard attempts to access the gameport when there's nothing connected to it.
        //This way, the joystickActive flag indicates to Boxer whether the game is *still* listening
        //to input, rather than whether the game looked for a joystick that wasn't there at startup
        //and then gave up.
        if (self.joystick || !flag)
        {
            _joystickActive = flag;
        }
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

- (id <BXEmulatedJoystick>) joystick
{
    @synchronized(self)
    {
        [_joystick retain];
    }
    return [_joystick autorelease];
}

- (void) setJoystick: (id <BXEmulatedJoystick>)newJoystick
{
    @synchronized(self)
    {
        if (self.joystick != newJoystick)
        {
            //Detach the existing joystick...
            if (_joystick)
            {
                [_joystick willDisconnect];
                [_joystick release];
            }
            
            _joystick = [newJoystick retain];
            
            //...and prepare the new one
            if (_joystick)
            {
                [_joystick didConnect];
            }
        }
    }
}

- (BOOL) validateJoystick: (id <BXEmulatedJoystick> *)ioValue error: (NSError **)outError
{
	id <BXEmulatedJoystick> newJoystick = *ioValue;
    Class joystickClass = [newJoystick class];
	
	//Nil values are just fine, skip all the other checks 
	if (!newJoystick) return YES;
	
	//Not actually a joystick class
	if (![newJoystick conformsToProtocol: @protocol(BXEmulatedJoystick)])
	{
		if (outError)
		{
			NSString *descriptionFormat = NSLocalizedString(@"“%@” is not a valid joystick type.",
															@"Format for error message when choosing an unrecognised joystick type. %@ is the classname of the chosen joystick type.");
			
			NSString *description = [NSString stringWithFormat: descriptionFormat, NSStringFromClass(joystickClass)];
			
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
	if (self.joystickSupport == BXNoJoystickSupport || 
		(self.joystickSupport == BXJoystickSupportSimple && [joystickClass requiresFullJoystickSupport]))
	{
		if (outError)
		{
			NSString *localizedName	= [joystickClass localizedName];
			
			NSString *descriptionFormat = NSLocalizedString(@"Joysticks of type “%1$@” are not supported by the current session.",
															@"Format for error message when choosing an unsupported joystick type. %1$@ is the localized name of the chosen joystick type.");
			
			NSString *description = [NSString stringWithFormat: descriptionFormat, localizedName];
			
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
    //Always post notifications on the main thread.
    if (![NSThread isMainThread])
    {
        [self performSelectorOnMainThread: _cmd waitUntilDone: NO withValues: &name, &selector, &userInfo];
    }
    else
    {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        NSNotification *notification = [NSNotification notificationWithName: name
                                                                     object: self
                                                                   userInfo: userInfo];
        
        if ([self.delegate respondsToSelector: selector])
            [self.delegate performSelector: selector withObject: notification];
        
        [center postNotification: notification];
    }
}


#pragma mark -
#pragma mark Synchronizing emulation state

//Dispatch KVC notifications on the main thread
- (void) willChangeValueForKey: (NSString *)key
{
    if (![NSThread isMainThread])
        [self performSelectorOnMainThread: _cmd withObject: key waitUntilDone: NO];
    else
        [super willChangeValueForKey: key];
}

- (void) didChangeValueForKey: (NSString *)key
{
    if (![NSThread isMainThread])
        [self performSelectorOnMainThread: _cmd withObject: key waitUntilDone: NO];
    else
        [super didChangeValueForKey: key];
}

//Called by coalface functions to notify Boxer that the emulation state may have changed behind its back
- (void) _didChangeEmulationState
{
    if (![NSThread isMainThread])
    {
        [self performSelectorOnMainThread: _cmd withObject: nil waitUntilDone: NO];
    }
    else
    {
        [self willChangeValueForKey: @"fixedSpeed"];
        [self willChangeValueForKey: @"autoSpeed"];
        [self willChangeValueForKey: @"frameskip"];
        [self willChangeValueForKey: @"coreMode"];
        
        [self didChangeValueForKey: @"fixedSpeed"];
        [self didChangeValueForKey: @"autoSpeed"];
        [self didChangeValueForKey: @"frameskip"];
        [self didChangeValueForKey: @"coreMode"];
        
        NSString *newProcessName = [NSString stringWithCString: RunningProgram
                                                      encoding: BXDirectStringEncoding];
        
        if ([newProcessName isEqualToString: shellProcessName]) newProcessName = nil;
        self.processName = newProcessName;
        
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
	self.initialized = YES;
	
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

- (void) _didFinishFrame: (BXVideoFrame *)frame
{
    [self.delegate emulator: self didFinishFrame: frame];
}
                           

#pragma mark -
#pragma mark Runloop handling

- (void) _processEvents
{
    //Let our delegate process events for us if we don't have our own thread
    if (!self.isConcurrent)
    {
        [self.delegate processEventsForEmulator: self];
    }
    else
    {
        NSDate *untilDate = self.isPaused ? [NSDate distantFuture] : [NSDate distantPast];
        
        while ([[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode beforeDate: untilDate])
        {
            if (self.isCancelled) break;
            if (!self.isPaused) break;
        }
    }
}

- (BOOL) _runLoopShouldContinue
{
	//If emulation has been cancelled or we otherwise want to wrest control away
	//from DOSBox, then break out of the current DOSBox run loop.
	//TWEAK: it's only safe to break out once initialization is done, since some
	//of DOSBox's initialization routines rely on running tasks on the run loop
	//and may crash if they fail to complete.
	if (self.isCancelled && self.isInitialized)
    {
        return NO;
	}
	return YES;
}

- (void) _runLoopWillStartWithContextInfo: (void **)contextInfo
{
    //Create an autorelease pool for this iteration of the runloop:
    //we'll drain it down in _runLoopDidFinishWithAutoreleasePool:
    if (contextInfo)
    {
        *contextInfo = [[NSAutoreleasePool alloc] init];
    }
	[self.delegate emulatorWillStartRunLoop: self];
}

- (void) _runLoopDidFinishWithContextInfo: (void *)contextInfo
{
	[self.delegate emulatorDidFinishRunLoop: self];
    
    if (contextInfo)
    {
        [(NSAutoreleasePool *)contextInfo drain];
    }
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

		//Ask our delegate for the configuration files we should be loading today.
        NSArray *configPaths = [self.delegate configurationPathsForEmulator: self];
		for (NSString *configPath in configPaths)
		{
			configPath = configPath.stringByStandardizingPath;
			const char *encodedConfigPath = configPath.fileSystemRepresentation;
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
		NSLog(@"DOSBox died with the following error: %@",
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
	[self.videoHandler shutdown];
    control = NULL;
}

@end
