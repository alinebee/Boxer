/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXSessionPrivate.h"

#import "BXPackage.h"
#import "BXGameProfile.h"
#import "BXBootlegCoverArt.h"
#import "BXDrive.h"
#import "BXAppController.h"
#import "BXDOSWindowController.h"
#import "BXEmulatorConfiguration.h"
#import "BXCloseAlert.h"

#import "BXEmulator+BXDOSFileSystem.h"
#import "BXEmulator+BXShell.h"
#import "NSWorkspace+BXFileTypes.h"
#import "NSString+BXPaths.h"
#import "UKFNSubscribeFileWatcher.h"
#import "NSWorkspace+BXExecutableTypes.h"


#pragma mark -
#pragma mark Constants

//How we will store our gamebox-specific settings in user defaults.
//%@ is the unique identifier for the gamebox.
NSString * const BXGameboxSettingsKeyFormat	= @"BXGameSettings: %@";
NSString * const BXGameboxSettingsNameKey	= @"BXGameName";

//The length of time in seconds after which we figure that if the program was
//Windows-only, it would have failed by now. If a program exits before this time,
//then we check if it's a Windows-only program and warn the user.
#define BXWindowsOnlyProgramFailTimeThreshold 0.2

//The length of time in seconds after which we count a program as having run successfully,
//and allow it to auto-quit. If a program exits before this time, we count it as
//a probable startup crash and leave the user at the DOS prompt to diagnose it.
#define BXSuccessfulProgramRunningTimeThreshold 10

//How soon after the program to enter fullscreen, if the run-programs-in-fullscreen toggle
//is enabled. The delay gives the program time to crash andour program panel time to hide.
#define BXAutoSwitchToFullScreenDelay 0.5

//How soon after launching a program to auto-hide the program panel.
//This gives the program time to fail miserably.
#define BXHideProgramPanelDelay 0.1

//How soon after returning to the DOS prompt to display the program panel.
//The delay gives the window time to resize or return from windowed mode.
#define BXShowProgramPanelDelay 0.25


#pragma mark -
#pragma mark Notifications

NSString * const BXSessionWillEnterFullScreenNotification	= @"BXSessionWillEnterFullScreen";
NSString * const BXSessionDidEnterFullScreenNotification	= @"BXSessionDidEnterFullScreen";
NSString * const BXSessionWillExitFullScreenNotification	= @"BXSessionWillExitFullScreen";
NSString * const BXSessionDidExitFullScreenNotification		= @"BXSessionDidExitFullScreen";

NSString * const BXSessionDidLockMouseNotification		= @"BXSessionDidLockMouse";
NSString * const BXSessionDidUnlockMouseNotification	= @"BXSessionDidUnlockMouse";

NSString * const BXWillBeginInterruptionNotification = @"BXWillBeginInterruptionNotification";
NSString * const BXDidFinishInterruptionNotification = @"BXDidFinishInterruptionNotification";


#pragma mark -
#pragma mark Implementation

@implementation BXSession

@synthesize DOSWindowController;
@synthesize gamePackage;
@synthesize emulator;
@synthesize targetPath;
@synthesize activeProgramPath;
@synthesize gameProfile;
@synthesize gameSettings;
@synthesize drives, executables, documentation;
@synthesize emulating;
@synthesize paused, autoPaused, interrupted, suspended;
@synthesize userToggledProgramPanel;

#pragma mark -
#pragma mark Helper class methods

+ (BXGameProfile *) profileForPath: (NSString *)path
{
	//Which folder to look in to detect the game we’re running.
	//This will choose any gamebox, Boxer drive folder or floppy/CD volume in the
	//file's path (setting shouldRecurse to YES) if found, falling back on the file's
	//containing folder otherwise (setting shouldRecurse to NO).
	BOOL shouldRecurse = NO;
	NSString *profileDetectionPath = [self gameDetectionPointForPath: path 
											  shouldSearchSubfolders: &shouldRecurse];
	
	//Detect any appropriate game profile for this session
	if (profileDetectionPath)
	{
		//IMPLEMENTATION NOTE: we only scan subfolders of the detection path if it's a gamebox,
		//mountable folder or CD/floppy disk, since these will have a finite and manageable file
		//heirarchy to scan.
		//Otherwise, we restrict our search to just the base folder to avoids massive blowouts
		//if the user opens something big like their home folder or startup disk, and to avoid
		//false positives when opening the DOS Games folder.
		return [BXGameProfile detectedProfileForPath: profileDetectionPath
									searchSubfolders: shouldRecurse];	
	}
	return nil;
}

+ (NSImage *) bootlegCoverArtForGamePackage: (BXPackage *)package withEra: (BXGameEra)era
{
	Class <BXBootlegCoverArt> coverArtClass;
	if (era == BXUnknownEra) era = [BXGameProfile eraOfGameAtPath: [package bundlePath]];
	switch (era)
	{
		case BXCDROMEra:		coverArtClass = [BXJewelCase class];	break;
		case BX525DisketteEra:	coverArtClass = [BX525Diskette class];	break;
		default:				coverArtClass = [BX35Diskette class];	break;
	}
	NSString *iconTitle = [package gameName];
	NSImage *icon = [coverArtClass coverArtWithTitle: iconTitle];
	return icon;
}


#pragma mark -
#pragma mark Initialization and cleanup

- (id) init
{
	if ((self = [super init]))
	{
		NSString *defaultsPath			= [[NSBundle mainBundle] pathForResource: @"GameDefaults" ofType: @"plist"];
		NSMutableDictionary *defaults	= [NSMutableDictionary dictionaryWithContentsOfFile: defaultsPath];
		
		[self setDrives: [NSMutableArray arrayWithCapacity: 10]];
		[self setExecutables: [NSMutableDictionary dictionaryWithCapacity: 10]];
		
		[self setEmulator: [[[BXEmulator alloc] init] autorelease]];
		[self setGameSettings: defaults];
		
		importQueue = [[NSOperationQueue alloc] init];
		watcher = [[UKFNSubscribeFileWatcher alloc] init];
	}
	return self;
}

- (void) dealloc
{ 	
	[self setDOSWindowController: nil],	[DOSWindowController release];
	[self setEmulator: nil],			[emulator release];
	[self setGamePackage: nil],			[gamePackage release];
	[self setGameProfile: nil],			[gameProfile release];
	[self setGameSettings: nil],		[gameSettings release];
	[self setTargetPath: nil],			[targetPath release];
	[self setActiveProgramPath: nil],	[activeProgramPath release];
	
	[self setDrives: nil],				[drives release];
	[self setExecutables: nil],			[executables release];
	[self setDocumentation: nil],		[documentation release];
		
	[temporaryFolderPath release], temporaryFolderPath = nil;
	
	[importQueue release], importQueue = nil;
	[watcher release], watcher = nil;
	
	[super dealloc];
}

- (BOOL) readFromURL: (NSURL *)absoluteURL
			  ofType: (NSString *)typeName
			   error: (NSError **)outError
{
	NSWorkspace *workspace	= [NSWorkspace sharedWorkspace];
	NSString *filePath		= [absoluteURL path];
	
	//Set our target launch path to point to this file, if we don't have a target already
	if (![self targetPath]) [self setTargetPath: filePath];
	
	//Check if the chosen file is located inside a gamebox
	NSString *packagePath	= [workspace parentOfFile: filePath
										matchingTypes: [NSSet setWithObject: @"net.washboardabs.boxer-game-package"]];
	
	//If the fileURL is located inside a gamebox, load the gamebox and use the gamebox itself as the fileURL.
	//This way, the DOS window will show the gamebox as the represented file, and our Recent Documents
	//list will likewise show the gamebox instead.
	if (packagePath)
	{
		BXPackage *package = [[BXPackage alloc] initWithPath: packagePath];
		[self setGamePackage: package];
		
		//If we opened the package directly, check if it has a target of its own;
		//if so, use that as our target path instead.
		if ([[self targetPath] isEqualToString: packagePath])
		{
			NSString *packageTarget = [package targetPath];
			if (packageTarget) [self setTargetPath: packageTarget];
		}
		[package release];
		
		//FIXME: move the fileURL reset out of here and into a later step: we can't rely on the order
		//in which NSDocument's setFileURL/readFromURL methods are called.
		[self setFileURL: [NSURL fileURLWithPath: packagePath]];
	}
	return YES;
}

- (void) setGamePackage: (BXPackage *)package
{	
	if (package != gamePackage)
	{
		[gamePackage release];
		gamePackage = [package retain];
		
		//Also load up the settings for this gamebox
		if (gamePackage)
		{
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
			NSString *defaultsKey = [NSString stringWithFormat: BXGameboxSettingsKeyFormat, [gamePackage gameIdentifier], nil];
			
			NSDictionary *gameboxSettings = [defaults objectForKey: defaultsKey];
			
			//Merge the loaded values in, rather than replacing the settings altogether.
			[gameSettings addEntriesFromDictionary: gameboxSettings]; 
		}
	}
}

- (void) setEmulator: (BXEmulator *)newEmulator
{	
	if (newEmulator != emulator)
	{
		if (emulator)
		{
			[emulator setDelegate: nil];
			[[emulator videoHandler] unbind: @"aspectCorrected"];
			[[emulator videoHandler] unbind: @"filterType"];
			
			[self _deregisterForPauseNotifications];
			[self _deregisterForFilesystemNotifications];
		}
		
		[emulator release];
		emulator = [newEmulator retain];
		
		if (newEmulator)
		{
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
			
			[newEmulator setDelegate: self];
			
			//FIXME: we shouldn't be using bindings for these
			[[newEmulator videoHandler] bind: @"aspectCorrected" toObject: defaults withKeyPath: @"aspectCorrected" options: nil];
			[[newEmulator videoHandler] bind: @"filterType" toObject: defaults withKeyPath: @"filterType" options: nil];
			
			[self _registerForFilesystemNotifications];
			[self _registerForPauseNotifications];
		}
	}
}

- (void) setActiveProgramPath: (NSString *)newPath
{
	if (![newPath isEqualToString: activeProgramPath])
	{
		[activeProgramPath release];
		activeProgramPath = [newPath copy];
		
		[DOSWindowController synchronizeWindowTitleWithDocumentName];
	}
}


#pragma mark -
#pragma mark Window management

- (void) makeWindowControllers
{
	//Use layer-based rendering
	//BXDOSWindowController *controller = [[BXDOSWindowController alloc] initWithWindowNibName: @"LayeredDOSWindow"];
	
	//Use display-linked rendering
	//BXDOSWindowController *controller = [[BXDOSWindowController alloc] initWithWindowNibName: @"DisplayLinkedDOSWindow"];

	//Use regular rendering
	BXDOSWindowController *controller = [[BXDOSWindowController alloc] initWithWindowNibName: @"DOSWindow"];

	[self addWindowController:		controller];
	[self setDOSWindowController:	controller];
	
	[controller setShouldCloseDocument: YES];
	
	[controller release];
}

- (void) removeWindowController: (NSWindowController *)windowController
{
	if (windowController == [self DOSWindowController])
	{
		[self setDOSWindowController: nil];
	}
	[super removeWindowController: windowController];
}


- (void) showWindows
{
	[super showWindows];
	
	//Start the emulator as soon as our windows appear
	[self start];
}

- (NSWindow *) windowForSheet
{
	NSWindow *activeWindow = [[self DOSWindowController] activeWindow];
	if (activeWindow) return activeWindow;
	else return [super windowForSheet];
}

- (void) setUserToggledProgramPanel: (BOOL)flag
{
	//Finesse: ignore program toggles while a program is running, only pay attention
	//when the user hides the program panel at the DOS prompt. This makes the behaviour
	//feel more 'natural', in that the panel will stay hidden while the user is mucking
	//around at the prompt but will return as soon as the user exits.
	if ([emulator isAtPrompt]) userToggledProgramPanel = flag;
}

#pragma mark -
#pragma mark Flow control

- (void) start
{
	//We schedule our internal _startEmulator method to be called separately on the main thread,
	//so that it doesn't block completion of whatever UI event led to this being called.
	//This prevents menu highlights from getting 'stuck' because of DOSBox's main loop blocking
	//the thread.
	
	if (!hasStarted) [self performSelector: @selector(_startEmulator)
								withObject: nil
								afterDelay: 0.1];
	
	//So we don't try to restart the emulator
	hasStarted = YES;
}

//Cancel the DOSBox emulator
- (void) cancel { [[self emulator] cancel]; }


#pragma mark -
#pragma mark Handling document closing

//Tell the emulator to close itself down when the document closes
- (void) close
{
	//Ensure that the document close procedure only happens once, no matter how many times we close
	if (!isClosing)
	{
		isClosing = YES;
		[self cancel];
		
		[self synchronizeSettings];
		[self _cleanup];
		
		[super close];
	}
}

//Overridden solely so that NSDocumentController will call canCloseDocumentWithDelegate:
//in the first place. This otherwise should have no effect and should not show up in the UI.
- (BOOL) isDocumentEdited	{ return [[self emulator] isRunningProcess]; }

//Overridden to display our own custom confirmation alert instead of the standard NSDocument one.
- (void) canCloseDocumentWithDelegate: (id)delegate
				  shouldCloseSelector: (SEL)shouldCloseSelector
						  contextInfo: (void *)contextInfo
{
	//Define an invocation for the callback, which has the signature:
	//- (void)document:(NSDocument *)document shouldClose:(BOOL)shouldClose contextInfo:(void *)contextInfo;
	NSMethodSignature *signature = [delegate methodSignatureForSelector: shouldCloseSelector];
	NSInvocation *callback = [NSInvocation invocationWithMethodSignature: signature];
	[callback setSelector: shouldCloseSelector];
	[callback setTarget: delegate];
	[callback setArgument: &self atIndex: 2];
	[callback setArgument: &contextInfo atIndex: 4];	
	
	BOOL hasActiveImports = NO;
	for (NSOperation *import in [importQueue operations])
	{
		if (![import isFinished] && ![import isCancelled])
		{
			hasActiveImports = YES;
			break;
		}
	}
	
	//We confirm the close if a process is running and if we're not already shutting down
	BOOL shouldConfirm = hasActiveImports ||
						(![[NSUserDefaults standardUserDefaults] boolForKey: @"suppressCloseAlert"]
						  && [emulator isRunningProcess]
						  && ![emulator isCancelled]);
	
	if (shouldConfirm)
	{
		//Show our custom close alert, passing it the callback so we can complete
		//our response down in _closeAlertDidEnd:returnCode:contextInfo:
		
		BXCloseAlert *alert;
		if (hasActiveImports) 
			alert = [BXCloseAlert closeAlertWhileImportingDrives: self];
		else
			alert = [BXCloseAlert closeAlertWhileSessionIsEmulating: self];
		
		[alert retain];
		[alert beginSheetModalForWindow: [self windowForSheet]
						  modalDelegate: self
						 didEndSelector: @selector(_closeAlertDidEnd:returnCode:contextInfo:)
							contextInfo: [callback retain]];
	}
	else
	{
		BOOL shouldClose = YES;
		//Otherwise we can respond directly: call the callback straight away with YES for shouldClose:
		[callback setArgument: &shouldClose atIndex: 3];
		[callback invoke];
	}
}

- (void) _closeAlertDidEnd: (BXCloseAlert *)alert
				returnCode: (int)returnCode
			   contextInfo: (NSInvocation *)callback
{
	if ([alert showsSuppressionButton] && [[alert suppressionButton] state] == NSOnState)
		[[NSUserDefaults standardUserDefaults] setBool: YES forKey: @"suppressCloseAlert"];
	
	BOOL shouldClose = (returnCode == NSAlertFirstButtonReturn);
	[callback setArgument: &shouldClose atIndex: 3];
	[callback invoke];
	
	//Release the previously-retained callback and alert instance
	[callback release];
	[alert release];
}

- (void) _windowsOnlyProgramCloseAlertDidEnd: (BXCloseAlert *)alert
								  returnCode: (int)returnCode
								 contextInfo: (void *)info
{
	if (returnCode == NSAlertFirstButtonReturn)
	{
		[self close];
	}
	[alert release];
}

//Save our configuration changes to disk before exiting
- (void) synchronizeSettings
{
	if ([self isGamePackage])
	{
		//Go through the settings working out which ones we should store in user defaults,
		//and which ones in the gamebox's configuration file.
		BXEmulatorConfiguration *runtimeConf = [BXEmulatorConfiguration configuration];
		
		//These are the settings we want to keep in the configuration file
		NSNumber *fixedSpeed	= [gameSettings objectForKey: @"fixedSpeed"];
		NSNumber *isAutoSpeed	= [gameSettings objectForKey: @"autoSpeed"];
		NSNumber *coreMode		= [gameSettings objectForKey: @"coreMode"];
		
		if (coreMode)
		{
			NSString *coreString = [BXEmulator configStringForCoreMode: [coreMode integerValue]];
			[runtimeConf setValue: coreString forKey: @"core" inSection: @"cpu"];
		}
		
		if (fixedSpeed || isAutoSpeed)
		{
			NSString *cyclesString = [BXEmulator configStringForFixedSpeed: [fixedSpeed integerValue]
																	isAuto: [isAutoSpeed boolValue]];
			
			[runtimeConf setValue: cyclesString forKey: @"cycles" inSection: @"cpu"];
		}
		
		//Strip out these settings once we're done, so we won't preserve them in user defaults
		[gameSettings removeObjectsForKeys: [NSArray arrayWithObjects: @"fixedSpeed", @"autoSpeed", @"coreMode", nil]];

		
		//Persist the gamebox-specific configuration into the gamebox's configuration file.
		NSString *configPath = [[self gamePackage] configurationFilePath];
		[self _saveConfiguration: runtimeConf toFile: configPath];
		
		//Save whatever's left into user defaults.
		if ([gameSettings count])
		{
			//Add the gamebox name into the settings, to make it easier to identify to which gamebox the record belongs
			[gameSettings setObject: [gamePackage gameName] forKey: BXGameboxSettingsNameKey];
			
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
			NSString *defaultsKey = [NSString stringWithFormat: BXGameboxSettingsKeyFormat, [[self gamePackage] gameIdentifier], nil];
			[defaults setObject: gameSettings forKey: defaultsKey];			
		}
	}
}
 

#pragma mark -
#pragma mark Describing the document/process

- (NSString *) displayName
{
	if ([self isGamePackage])	return [[self gamePackage] gameName];
	else if ([self fileURL])	return [super displayName];
	else						return [self processDisplayName];
}

- (NSString *) processDisplayName
{
	NSString *processName = nil;
	if ([emulator isRunningProcess])
	{
		//Use the active program name where possible;
		//Failing that, fall back on the original process name
		if ([self activeProgramPath]) processName = [[self activeProgramPath] lastPathComponent];
		else processName = [emulator processName];
	}
	return processName;
}


#pragma mark -
#pragma mark Introspecting the gamebox

- (BOOL) isGamePackage	{ return ([self gamePackage] != nil); }

- (NSImage *)representedIcon
{
	if ([self isGamePackage])
	{
		NSImage *icon = [[self gamePackage] coverArt];
		return icon;
	}
	else return nil;
}

- (void) setRepresentedIcon: (NSImage *)icon
{
	BXPackage *thePackage = [self gamePackage];
	if (thePackage)
	{
		[thePackage setCoverArt: icon];
				
		//Force our file URL to appear to change, which will update icons elsewhere in the app 
		[self setFileURL: [self fileURL]];
	}
}


- (NSArray *) documentation
{
	//Generate our documentation cache the first time it is needed
	if (!documentation)
	{
		NSWorkspace *workspace	= [NSWorkspace sharedWorkspace];
		
		NSArray *docPaths = [[[self gamePackage] documentation] sortedArrayUsingSelector: @selector(pathDepthCompare:)];
		
		NSMutableSet *docNames = [[NSMutableSet alloc] initWithCapacity: [docPaths count]];

		documentation = [[NSMutableArray alloc] initWithCapacity: [docPaths count]];
		
		for (NSString *path in docPaths)
		{
			path = [path stringByStandardizingPath];
			NSString *fileName = [path lastPathComponent];
			
			//If we already have a document with this name, skip it so we don't offer ambiguous choices
			//TODO: this filtering should be done downstream in the UI controller, it's not our call
			if (![docNames containsObject: fileName])
			{
				NSImage *icon		= [workspace iconForFile: path];
				NSDictionary *data	= [NSDictionary dictionaryWithObjectsAndKeys:
									   path,	@"path",
									   icon,	@"icon",
									   nil];
				
				[docNames addObject: fileName];
				[documentation addObject: data];
			}
		}
		[docNames release];
	}
	return documentation;
}

+ (NSSet *) keyPathsForValuesAffectingIsGamePackage		{ return [NSSet setWithObject: @"gamePackage"]; }
+ (NSSet *) keyPathsForValuesAffectingRepresentedIcon	{ return [NSSet setWithObject: @"gamePackage.coverArt"]; }


#pragma mark -
#pragma mark Emulator delegate methods and notifications

//If we have not already performed our own configuration, do so now
- (void) runPreflightCommandsForEmulator: (BXEmulator *)theEmulator
{
	if (!hasConfigured)
	{
		//Conceal drive notifications during startup
		showDriveNotifications = NO;
		
		[self _mountDrivesForSession];
		
		//From here on out, it's OK to show drive notifications.
		showDriveNotifications = YES;
		
		//Flag that we have completed our initial game configuration.
		hasConfigured = YES;
	
		//Flag that we are now officially emulating.
		//We wait until now because at this point the emulator is in
		//a properly initialized state, and can respond properly to
		//commands and settings changes.
		//TODO: move this decision off to the emulator itself.
		[self setEmulating: YES];
	}
}

- (void) runLaunchCommandsForEmulator: (BXEmulator *)theEmulator
{
	hasLaunched = YES;
	[self _launchTarget];
}

- (void) emulator: (BXEmulator *)theEmulator didFinishFrame: (BXFrameBuffer *)frame
{
	[[self DOSWindowController] updateWithFrame: frame];
}

- (NSSize) maxFrameSizeForEmulator: (BXEmulator *)theEmulator
{
	return [[self DOSWindowController] maxFrameSize];
}

- (NSSize) viewportSizeForEmulator: (BXEmulator *)theEmulator
{
	return [[self DOSWindowController] viewportSize];
}

- (void) emulatorDidBeginRunLoop: (BXEmulator *)theEmulator
{
	//Implementation note: in a better world, this code wouldn't be here as event
	//dispatch is normally done automatically by NSApplication at opportune moments.
	//However, DOSBox's emulation loop takes over the application's main thread,
	//leaving no time for events to get processed and dispatched.
	//Hence in each iteration of DOSBox's run loop, we pump NSApplication's event
	//queue for all pending events and send them on their way.
	
	//Bugfix: if we are in the process of shutting down, then don't dispatch events:
	//NSApp may not know yet that our window has closed, and will crash when trying
	//send events to it. This isn't a bug per se but an edge-case with the
	//NSWindow/NSDocument close flow.
	
	NSEvent *event;
	NSDate *untilDate = nil;
	
	while (!isClosing && (event = [NSApp nextEventMatchingMask: NSAnyEventMask
													 untilDate: untilDate
														inMode: NSDefaultRunLoopMode
													   dequeue: YES]))
	{
		[NSApp sendEvent: event];
		
		//If we're suspended, keep dispatching events until we are unpaused;
		//otherwise, allow emulation to resume after the first batch
		//of events has been processed.
		untilDate = [self isSuspended] ? [NSDate distantFuture] : nil;
	}
}

- (void) emulatorDidFinishRunLoop: (BXEmulator *)theEmulator {}


- (void) emulatorWillStartProgram: (NSNotification *)notification
{
	//Don't set the active program if we already have one: this way, we keep
	//track of when a user launches a batch file and don't immediately discard
	//it in favour of the next program the batch-file runs
	if (![self activeProgramPath])
	{
		NSString *activePath = [[notification userInfo] objectForKey: @"localPath"];
		[self setActiveProgramPath: activePath];
		
		//If the user hasn't manually opened/closed the program panel themselves,
		//and we don't need to ask the user what to do with this program, then
		//automatically hide the program panel shortly after launching.
		if (![self userToggledProgramPanel] && ![self _leaveProgramPanelOpenAfterLaunch])
		{
			[NSObject cancelPreviousPerformRequestsWithTarget: [self DOSWindowController]
													 selector: @selector(showProgramPanel)
													   object: nil];
			
			[[self DOSWindowController] performSelector: @selector(hideProgramPanel)
											 withObject: nil
											 afterDelay: BXHideProgramPanelDelay];
		}
	}
	
	//Track how long this program has run for
	programStartTime = [NSDate timeIntervalSinceReferenceDate];
}

- (void) emulatorDidFinishProgram: (NSNotification *)notification
{
	//Clear the active program when a startup program or 'non-defaultable' program
	//finishes. This way, programWillStart: won't hang onto programs we can't use
	//as the default, such as autoexec commands or dispatch batchfiles.
	//(Note that the active program is always cleared down in didReturnToShell:)
	NSString *activePath = [self activeProgramPath];
	if (activePath && (!hasLaunched || ([self gamePackage] && ![[self gamePackage] validateTargetPath: &activePath error: NULL])))
	{
		[self setActiveProgramPath: nil];		
	}
	
	//Check the running time of the program. If it was suspiciously short,
	//then check for possible error conditions that we can inform the user about.
	NSTimeInterval programRunningTime = [NSDate timeIntervalSinceReferenceDate] - programStartTime; 
	if (programRunningTime < BXWindowsOnlyProgramFailTimeThreshold)
	{
		//If this was the target program for this launch, then
		//warn if the program is Windows-only.
		//(we only do this for the target program because we
		//don't want to bother the user if they're just trying
		//out programs at the DOS prompt)
		NSString *programPath = [[notification userInfo] objectForKey: @"localPath"];
		if (programPath && [programPath isEqualToString: [self targetPath]])
		{
			BXExecutableType programType = [[NSWorkspace sharedWorkspace] executableTypeAtPath: programPath error: NULL];
			
			if (programType == BXExecutableTypeWindows)
			{
				BXCloseAlert *alert = [BXCloseAlert closeAlertAfterWindowsOnlyProgramExited: programPath];
				[alert retain];
				[alert beginSheetModalForWindow: [self windowForSheet]
								  modalDelegate: self
								 didEndSelector: @selector(_windowsOnlyProgramCloseAlertDidEnd:returnCode:contextInfo:)
									contextInfo: nil];
			}
		}
	}
}

- (void) emulatorDidReturnToShell: (NSNotification *)notification
{
	//If we should close after exiting, then close down the application now
	if ([self _shouldCloseOnProgramExit])
	{
		[self close];
	}
	
	//Clear the active program
	[self setActiveProgramPath: nil];
	
	
	//Show the program chooser after returning to the DOS prompt, as long
	//as the program chooser hasn't been manually toggled from the DOS prompt
	if ([self isGamePackage] && ![self userToggledProgramPanel] && [[self programPathsOnPrincipalDrive] count])
	{
		[NSObject cancelPreviousPerformRequestsWithTarget: [self DOSWindowController]
												 selector: @selector(hideProgramPanel)
												   object: nil];
		
		//Show only after a delay, so that the window has time to resize after quitting the game
		[[self DOSWindowController] performSelector: @selector(showProgramPanel)
										 withObject: nil
										 afterDelay: BXShowProgramPanelDelay];
	}

	if ([[NSUserDefaults standardUserDefaults] boolForKey: @"startUpInFullScreen"])
	{
		//Drop out of fullscreen mode when we return to the prompt,
		//if we automatically switched into fullscreen at startup
		[[self DOSWindowController] exitFullScreen: self];
	}
}

- (void) emulatorDidBeginGraphicalContext: (NSNotification *)notification
{
	//Tweak: only switch into fullscreen mode if we don't need to prompt
	//the user about choosing a default program.
	if ([[NSUserDefaults standardUserDefaults] boolForKey: @"startUpInFullScreen"] &&
		![self _leaveProgramPanelOpenAfterLaunch])
	{
		//Switch to fullscreen mode automatically after a brief delay:
		//This will be cancelled if the context exits within that time,
		//in case of a program that crashes early.
		[[self DOSWindowController] performSelector: @selector(toggleFullScreenWithZoom:) 
										  withObject: [NSNumber numberWithBool: YES] 
										  afterDelay: BXAutoSwitchToFullScreenDelay];
	}
}

- (void) emulatorDidFinishGraphicalContext: (NSNotification *)notification
{
	[NSObject cancelPreviousPerformRequestsWithTarget: [self DOSWindowController]
											 selector: @selector(toggleFullScreenWithZoom:)
											   object: [NSNumber numberWithBool: YES]];
}

- (void) emulatorDidChangeEmulationState: (NSNotification *)notification
{
	//These reside in BXEmulatorControls, as should this function, but so be it
	[self willChangeValueForKey: @"sliderSpeed"];
	[self didChangeValueForKey: @"sliderSpeed"];
	
	[self willChangeValueForKey: @"frameskip"];
	[self didChangeValueForKey: @"frameskip"];
	
	[self willChangeValueForKey: @"dynamic"];
	[self didChangeValueForKey: @"dynamic"];	
}


#pragma mark -
#pragma mark Private methods

- (BOOL) _shouldCloseOnEmulatorExit { return YES; }

- (BOOL) _shouldCloseOnProgramExit
{
	//Don't close if the auto-close preference is disabled for this gamebox
	if (![[gameSettings objectForKey: @"closeOnExit"] boolValue]) return NO;
	
	//Don't close if the user skipped the startup program in order to start up at the DOS prompt
	if (userSkippedDefaultProgram) return NO;
	
	//Don't close if we've been running a program other than the default program for the gamebox
	if (![[self activeProgramPath] isEqualToString: [[self gamePackage] targetPath]]) return NO;
	
	//Don't close if there are drive imports in progress
	if ([[importQueue operations] count]) return NO;
	
	//Don't close if the last program quit suspiciously early, since this may be a crash
	NSTimeInterval executionTime = [NSDate timeIntervalSinceReferenceDate] - programStartTime;
	if (executionTime < BXSuccessfulProgramRunningTimeThreshold) return NO;
	
	//Don't close if the user is currently holding down the Option key override
	CGEventFlags currentModifiers = CGEventSourceFlagsState(kCGEventSourceStateCombinedSessionState);
	BOOL optionKeyDown = (currentModifiers & NSAlternateKeyMask) == NSAlternateKeyMask;
	if (optionKeyDown) return NO;
	
	//If we get this far then go right ahead and die
	return YES;
}

//We leave the panel open when we don't have a default program already,
//and can adopt the current program as the default program. This way
//we can ask the user what they want to do with the program.
- (BOOL) _leaveProgramPanelOpenAfterLaunch
{
	NSString *activePath = [[[self activeProgramPath] copy] autorelease];
	return ![gamePackage targetPath] && [gamePackage validateTargetPath: &activePath error: NULL];
}

- (void) _startEmulator
{
	//Load up our configuration files
	[self _loadDOSBoxConfigurations];
	
	//Set the emulator's current working directory relative to whatever we're opening
	if ([self fileURL])
	{
		NSString *filePath = [[self fileURL] path];
		BOOL isFolder = NO;
		if ([[NSFileManager defaultManager] fileExistsAtPath: filePath isDirectory: &isFolder])
		{
			//If we're opening a folder/gamebox, use that as the base path; if we're opening
			//a program or disc image, use its containing folder as the base path instead.
			NSString *basePath = (isFolder) ? filePath : [filePath stringByDeletingLastPathComponent];
			[[self emulator] setBasePath: basePath];
		}
	}
	
	//Start up the emulator itself.
	[[self emulator] start];
	//This method will block until completion, so everything following this occurs after the emulator has shut down.
	
	
	//Flag that we're no longer emulating
	//(This will have been set to YES in runPreflightCommands)
	[self setEmulating: NO];
	
	//Clear our drive and program caches (suppressing notifications)
	[self setActiveProgramPath: nil];
	showDriveNotifications = NO;
	[self setDrives: nil];
	showDriveNotifications = YES;

	//Clear the final rendered frame
	[[self DOSWindowController] updateWithFrame: nil];
	
	//Close the document once we're done, if desired
	if ([self _shouldCloseOnEmulatorExit]) [self close];
}

- (void) _loadDOSBoxConfigurations
{
	//The configuration files we will be using today, loaded in this order.
	NSString *preflightConf	= [[NSBundle mainBundle] pathForResource: @"Preflight" ofType: @"conf"];
	NSString *profileConf	= nil;
	NSString *packageConf	= nil;
	NSString *launchConf	= [[NSBundle mainBundle] pathForResource: @"Launch" ofType: @"conf"];
	
	//If we don't have a manually-defined game-profile, detect the game profile from our target path
	if ([self targetPath] && ![self gameProfile])
	{
		BXGameProfile *profile = [[self class] profileForPath: [self targetPath]];
		[self setGameProfile: profile];
	}	
	
	//Get the appropriate configuration file for this game profile
	if ([self gameProfile])
	{
		NSString *configName = [[self gameProfile] confName];
		if (configName)
		{
			profileConf = [[NSBundle mainBundle] pathForResource: configName
														  ofType: @"conf"
													 inDirectory: @"Configurations"];
		}
	}
	
	//Get the gamebox's own configuration file, if it has one
	if ([self gamePackage]) packageConf = [[self gamePackage] configurationFile];
	
	
	//Apply all our configuration files in order.
	[emulator applyConfigurationAtPath: preflightConf];
	if (profileConf) [emulator applyConfigurationAtPath: profileConf];
	if (packageConf) [emulator applyConfigurationAtPath: packageConf];
	[emulator applyConfigurationAtPath: launchConf];	
}

- (void) _mountDrivesForSession
{
	BXPackage *package = [self gamePackage];
	if (package)
	{
		//Mount the game package as a new hard drive, at drive C
		//(This may get replaced below by a custom bundled C volume)
		BXDrive *packageDrive = [BXDrive hardDriveFromPath: [package gamePath] atLetter: @"C"];
		packageDrive = [self mountDrive: packageDrive];
		
		//Then, mount any extra volumes included in the game package
		NSMutableArray *packageVolumes = [NSMutableArray arrayWithCapacity: 10];
		[packageVolumes addObjectsFromArray: [package floppyVolumes]];
		[packageVolumes addObjectsFromArray: [package hddVolumes]];
		[packageVolumes addObjectsFromArray: [package cdVolumes]];
		
		BXDrive *bundledDrive;
		for (NSString *volumePath in packageVolumes)
		{
			bundledDrive = [BXDrive driveFromPath: volumePath atLetter: nil];
			//The bundled drive was explicitly set to drive C, so override our existing C package-drive with it
			if ([[bundledDrive letter] isEqualToString: [packageDrive letter]])
			{
				[self unmountDrive: packageDrive];
				
				//Rewrite the target to point to the new C drive, if it was pointing to the old one
				if ([[self targetPath] isEqualToString: [packageDrive path]]) [self setTargetPath: volumePath];
				
				//Aaand use this as our package drive from here on
				packageDrive = bundledDrive;
			}
			[self mountDrive: bundledDrive];
		}
	}
	
	//Automount all currently mounted floppy and CD-ROM volumes.
	//TWEAK: don't mount extra drives if the gamebox already contains bundled drives of that type.
	//This is a hamfisted way of avoiding redundant drive mounts in the case of e.g. recently-imported
	//games, where we'd otherwise mount the original install disc alongside the newly-bundled drive.
	//This is a hack and should be replaced with a more sophisticated comparison between the OS X
	//volume and the bundled drive(s).
	if (!package || ![self hasFloppyDrives])	[self mountFloppyVolumes];
	if (!package || ![self hasCDDrives])		[self mountCDVolumes];
	
	//Mount our internal DOS toolkit and temporary drives
	[self mountToolkitDrive];
	[self mountTempDrive];
	
	
	//Once all regular drives are in place, make a mount point allowing access to our target program/folder,
	//if it's not already accessible in DOS.
	if ([self targetPath])
	{
		if ([self shouldMountDriveForPath: targetPath]) [self mountDriveForPath: targetPath];
	}
}

- (void) _launchTarget
{	
	//Do any just-in-time configuration, which should override all previous startup stuff
	//TODO: abstract this to a proper post-autoexec method rather than assuming this is
	//always going to be called right at the end of the autoexec thankyou very much
	NSNumber *frameskip = [gameSettings objectForKey: @"frameskip"];
	
	//Set the frameskip setting if it's valid
	if (frameskip && [self validateValue: &frameskip forKey: @"frameskip" error: nil])
		[self setValue: frameskip forKey: @"frameskip"];
	
	
	//After all preflight configuration has finished, go ahead and open whatever file we're pointing at
	NSString *target = [self targetPath];
	if (target)
	{
		//If the Option key was held down, don't launch the gamebox's target;
		//Instead, just switch to its parent folder
		CGEventFlags currentModifiers = CGEventSourceFlagsState(kCGEventSourceStateCombinedSessionState);
		userSkippedDefaultProgram = (currentModifiers & NSAlternateKeyMask) == NSAlternateKeyMask;
		
		if (userSkippedDefaultProgram && [[self class] isExecutable: target])
		{
			target = [target stringByDeletingLastPathComponent];
		}
		[self openFileAtPath: target];
	}
}

- (void) _saveConfiguration: (BXEmulatorConfiguration *)configuration toFile: (NSString *)filePath
{
	NSFileManager *manager = [NSFileManager defaultManager];
	BOOL fileExists = [manager fileExistsAtPath: filePath];
	
	//Save the configuration if any changes have been made, or if the file at that path does not exist.
	if (!fileExists || ![configuration isEmpty])
	{
		BXEmulatorConfiguration *gameboxConf = [BXEmulatorConfiguration configurationWithContentsOfFile: filePath];
		
		//If a configuration file exists at that path already, then merge
		//the changes with its existing settings.
		if (gameboxConf)
		{
			[gameboxConf addSettingsFromConfiguration: configuration];
		}
		//Otherwise, use the runtime configuration as our basis
		else gameboxConf = configuration;
		
		
		//Add comment preambles to saved configuration
		NSString *configurationHelpURL = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"ConfigurationFileHelpURL"];
		if (!configurationHelpURL) configurationHelpURL = @"";
		NSString *preambleFormat = NSLocalizedStringFromTable(@"Configuration preamble", @"Configuration",
															  @"Used generated configuration files as a commented header at the top of the file. %1$@ is an absolute URL to Boxer’s configuration setting documentation.");
		[gameboxConf setPreamble: [NSString stringWithFormat: preambleFormat, configurationHelpURL, nil]];
		 
		[gameboxConf setStartupCommandsPreamble: NSLocalizedStringFromTable(@"Preamble for startup commands", @"Configuration",
																			@"Used in generated configuration files as a commented header underneath the [autoexec] section.")];
		
		
		//If we have an auto-detected game profile, check against its configuration file
		//and eliminate any duplicate configuration parameters. This way, we don't persist
		//settings we don't need to.
		NSString *profileConfName = [gameProfile confName];
		if (profileConfName)
		{
			NSString *profileConfPath = [[NSBundle mainBundle] pathForResource: profileConfName
																		ofType: @"conf"
																   inDirectory: @"Configurations"];
			
			BXEmulatorConfiguration *profileConf = [BXEmulatorConfiguration configurationWithContentsOfFile: profileConfPath];
			if (profileConf) [gameboxConf excludeDuplicateSettingsFromConfiguration: profileConf];
		}
		
		[gameboxConf writeToFile: filePath error: NULL];
	}
}

- (void) _cleanup
{
	//Delete the temporary folder, if one was created
	if (temporaryFolderPath)
	{
		NSFileManager *manager = [NSFileManager defaultManager];
		[manager removeItemAtPath: temporaryFolderPath error: NULL];
	}
	
	//Cancel any in-progress drive imports and clear delegates
	[[importQueue operations] makeObjectsPerformSelector: @selector(setDelegate:) withObject: nil];
	[importQueue cancelAllOperations];
	[importQueue waitUntilAllOperationsAreFinished];
}


#pragma mark -
#pragma mark Pause-state handling

- (void) setPaused: (BOOL)flag
{
	if (paused != flag)
	{
		paused = flag;
		[self _syncSuspendedState];
	}
}

- (void) setInterrupted: (BOOL)flag
{
	if (interrupted != flag)
	{
		interrupted = flag;
		[self _syncSuspendedState];
	}
}

- (void) setAutoPaused: (BOOL)flag
{
	if (autoPaused != flag)
	{
		autoPaused = flag;
		[self _syncSuspendedState];
	}
}

- (void) setSuspended: (BOOL)flag
{
	if (suspended != flag)
	{
		suspended = flag;

		//Tell the emulator to prepare for being suspended or to resume after we unpause.
		if (suspended)
		{
			[emulator willPause];
		}
		else
		{
			[emulator didResume];
		}
		
		//Update the title to reflect that we’ve paused/resumed
		[DOSWindowController synchronizeWindowTitleWithDocumentName];
	}
}

- (void) _syncSuspendedState
{
	[self setSuspended: (interrupted || paused || autoPaused)];
}

- (void) _syncAutoPausedState
{
	[self setAutoPaused: [self _shouldAutoPause]];
}

- (BOOL) _shouldAutoPause
{
	//Don't auto-pause if the emulator hasn't finished starting up yet
	if (![self isEmulating]) return NO;
	
	//Only auto-pause if the mode is enabled in the user's settings
	if (![[NSUserDefaults standardUserDefaults] boolForKey: @"pauseWhileInactive"]) return NO;
	
	//Auto-pause if Boxer is in the background
	if (![NSApp isActive]) return YES;
	
	//Auto-pause if the DOS window is miniaturized
	//IMPLEMENTATION NOTE: we used to toggle this when the DOS window was hidden (not visible),
	//but that gave rise to corner cases if shouldAutoPause was called just before the window was to appear.
	if ([[DOSWindowController activeWindow] isMiniaturized]) return YES;
	
	return NO;
}

- (void) _interruptionWillBegin: (NSNotification *)notification
{
	[self setInterrupted: YES];
}

- (void) _interruptionDidFinish: (NSNotification *)notification
{
	[self setInterrupted: NO];
}


- (void) _registerForPauseNotifications
{
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	
	[center addObserver: self
			   selector: @selector(_syncAutoPausedState)
				   name: NSWindowDidMiniaturizeNotification
				 object: [DOSWindowController window]];
	
	[center addObserver: self
			   selector: @selector(_syncAutoPausedState)
				   name: NSWindowDidDeminiaturizeNotification
				 object: [DOSWindowController window]];
	
	[center addObserver: self
			   selector: @selector(_syncAutoPausedState)
				   name: NSApplicationDidResignActiveNotification
				 object: NSApp];
	
	[center addObserver: self
			   selector: @selector(_syncAutoPausedState)
				   name: NSApplicationDidBecomeActiveNotification
				 object: NSApp];
	
	
	[center addObserver: self
			   selector: @selector(_interruptionWillBegin:)
				   name: NSMenuDidBeginTrackingNotification
				 object: nil];
	
	[center addObserver: self
			   selector: @selector(_interruptionDidFinish:)
				   name: NSMenuDidEndTrackingNotification
				 object: nil];
	
	[center addObserver: self
			   selector: @selector(_interruptionWillBegin:)
				   name: BXWillBeginInterruptionNotification
				 object: nil];
	
	[center addObserver: self
			   selector: @selector(_interruptionDidFinish:)
				   name: BXDidFinishInterruptionNotification
				 object: nil];
}
	 
- (void) _deregisterForPauseNotifications
{
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	
	[center removeObserver: self name: NSWindowWillMiniaturizeNotification object: nil];
	[center removeObserver: self name: NSWindowDidDeminiaturizeNotification object: nil];
	
	[center removeObserver: self name: NSApplicationWillResignActiveNotification object: nil];
	[center removeObserver: self name: NSApplicationDidBecomeActiveNotification object: nil];
	
	[center removeObserver: self name: BXWillBeginInterruptionNotification object: nil];
	[center removeObserver: self name: BXDidFinishInterruptionNotification object: nil];
}


@end
