/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXSession.h"
#import "BXPackage.h"
#import "BXGameProfile.h"
#import "BXDrive.h"
#import "BXAppController.h"
#import "BXDOSWindowController+BXRenderController.h"
#import "BXSession+BXFileManager.h"
#import "BXEmulatorConfiguration.h"
#import "BXCloseAlert.h"

#import "BXEmulator+BXDOSFileSystem.h"
#import "BXEmulator+BXShell.h"
#import "NSWorkspace+BXFileTypes.h"
#import "NSString+BXPaths.h"
#import "NSFileManager+BXTemporaryFiles.h"


//How we will store our gamebox-specific settings in user defaults.
//%@ is the unique identifier for the gamebox.
NSString * const BXGameboxSettingsKeyFormat	= @"BXGameSettings: %@";
NSString * const BXGameboxSettingsNameKey	= @"BXGameName";


#pragma mark -
#pragma mark Private method declarations

@interface BXSession ()
@property (readwrite, retain, nonatomic) NSMutableDictionary *gameSettings;
@property (readwrite, copy, nonatomic) NSString *activeProgramPath;
@property (readwrite, retain, nonatomic) NSArray *drives;

@property (readwrite, assign, nonatomic, getter=isEmulating) BOOL emulating;

//Create our BXEmulator instance and starts its main loop.
//Called internally by [BXSession start], deferred to the end of the main thread's event loop to prevent
//DOSBox blocking cleanup code.
- (void) _startEmulator;

//Set up the emulator context with drive mounts and other configuration settings specific to this session.
//Called in response to the BXEmulatorWillLoadConfiguration event, once the emulator is initialised enough
//for us to configure it.
- (void) _configureEmulator;

//Start up the target program for this session (if any) and displays the program panel selector after this
//finishes. Called by runLaunchCommands, once the emulator has finished processing configuration files.
- (void) _launchTarget;

//Called once the session has exited to save any DOSBox settings we have changed to the gamebox conf.
- (void) _saveConfiguration: (BXEmulatorConfiguration *)configuration toFile: (NSString *)filePath;

//Cleans up temporary files after the session is closed.
- (void) _cleanup;

//Callback for close alert. Confirms document close when window is closed or application is shut down. 
- (void) _closeAlertDidEnd: (BXCloseAlert *)alert returnCode: (int)returnCode contextInfo: (NSInvocation *)callback;
@end


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
@synthesize drives;
@synthesize emulating;


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


#pragma mark -
#pragma mark Initialization and cleanup

- (id) init
{
	if ((self = [super init]))
	{
		NSString *defaultsPath			= [[NSBundle mainBundle] pathForResource: @"GameDefaults" ofType: @"plist"];
		NSMutableDictionary *defaults	= [NSMutableDictionary dictionaryWithContentsOfFile: defaultsPath];
		
		[self setDrives: [NSMutableArray arrayWithCapacity: 10]];
		[self setEmulator: [[[BXEmulator alloc] init] autorelease]];
		[self setGameSettings: defaults];
		
		importQueue = [[NSOperationQueue alloc] init];
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
		
	[temporaryFolderPath release], temporaryFolderPath = nil;
	
	[importQueue release], importQueue = nil;
	
	[super dealloc];
}

//We make this a no-op to avoid creating an NSFileWrapper - we don't ever actually read any data off disk,
//so we don't need to construct a representation of the filesystem, and trying to do so for large documents
//(e.g. root folders) can cause memory allocation crashes.
- (BOOL) readFromURL: (NSURL *)absoluteURL
			  ofType: (NSString *)typeName
			   error: (NSError **)outError
{
	return YES;
}

#pragma mark -
#pragma mark Window controller management

- (void) makeWindowControllers
{
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


- (void) setFileURL: (NSURL *)fileURL
{	
	NSWorkspace *workspace	= [NSWorkspace sharedWorkspace];
	NSString *filePath		= [[fileURL path] stringByStandardizingPath];
	
	//Set our target launch path to point to this file, if we don't have a target already
	if (![self targetPath]) [self setTargetPath: filePath];

	//Check if the chosen file path is located inside a gamebox
	NSString *packagePath	= [workspace parentOfFile: filePath
										matchingTypes: [NSSet setWithObject: @"net.washboardabs.boxer-game-package"]];
	
	//If the fileURL is located inside a gamebox, we use the gamebox itself as the fileURL.
	//This way, the DOS window will show the gamebox as the represented file, and our Recent Documents
	//list will likewise show the gamebox instead.
	if (packagePath)
	{
		fileURL = [NSURL fileURLWithPath: packagePath];
		
		BXPackage *package = [[BXPackage alloc] initWithPath: packagePath];
		[self setGamePackage: package];
		
		//If we opened a package directly, check if it has a target of its own; if so, use that as our target path instead.
		if ([[self targetPath] isEqualToString: packagePath])
		{
			NSString *packageTarget = [package targetPath];
			if (packageTarget) [self setTargetPath: packageTarget];
		}
		[package release];
	}
	
	[super setFileURL: fileURL];
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
		}
	}
}

//Keep our emulator's profile and our own profile in sync
//IMPLEMENTATION NOTE: we could do this with bindings,
//but I want to avoid circular-retains and bindings hell
- (void) setGameProfile: (BXGameProfile *)profile
{
	if (profile != gameProfile)
	{
		[gameProfile release];
		gameProfile = [profile retain];
		[[self emulator] setGameProfile: gameProfile];
	}
}

//Overridden solely so that NSDocumentController will call canCloseDocumentWithDelegate:
//in the first place. This otherwise should have no effect and should not show up in the UI.
- (BOOL) isDocumentEdited	{ return [[self emulator] isRunningProcess]; }

- (void) _closeAlertDidEnd: (BXCloseAlert *)alert returnCode: (int)returnCode contextInfo: (NSInvocation *)callback
{
	if ([alert showsSuppressionButton] && [[alert suppressionButton] state] == NSOnState)
		[[NSUserDefaults standardUserDefaults] setBool: YES forKey: @"suppressCloseAlert"];
	
	BOOL shouldClose = (returnCode == NSAlertFirstButtonReturn);
	[callback setArgument: &shouldClose atIndex: 3];
	[callback invoke];
	
	//Release the previously-retained callback
	[callback release];
}

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

//Tell the emulator to close itself down when the document closes
- (void) close
{
	//Ensure that the document close procedure only happens once, no matter how many times we g
	if (!isClosing)
	{
		isClosing = YES;
		[self cancel];
		
		[self synchronizeSettings];
		[self _cleanup];
		
		[super close];
	}
}

- (BOOL) closeOnEmulatorExit	{ return YES; }


//Overridden to display our own custom confirmation alert instead of the standard NSDocument one.
- (void) canCloseDocumentWithDelegate: (id)delegate
				  shouldCloseSelector: (SEL)shouldCloseSelector
						  contextInfo: (void *)contextInfo
{
	//Define an invocation for the callback, which has the signature:
	//- (void)document:(NSDocument *)document shouldClose:(BOOL)shouldClose contextInfo:(void *)contextInfo;
	NSInvocation *callback = [NSInvocation invocationWithMethodSignature: [delegate methodSignatureForSelector:shouldCloseSelector]];
	[callback setSelector: shouldCloseSelector];
	[callback setTarget: delegate];
	[callback setSelector: shouldCloseSelector];
	[callback setArgument: &self atIndex: 2];
	[callback setArgument: &contextInfo atIndex: 4]; // contextInfo:	
	
	BOOL hasActiveImports = NO;
	for (BXDriveImport *import in [importQueue operations])
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
			alert = [BXCloseAlert closeAlertWhileImportIsActive: self];
		else
			alert = [BXCloseAlert closeAlertWhileSessionIsActive: self];
		
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



//Save our configuration changes to disk before exiting
- (void) synchronizeSettings
{
	if ([self isGamePackage])
	{
		//Go through the settings working out which ones we should store in user defaults,
		//and which ones in the gamebox's configuration file.
		BXEmulatorConfiguration *gameboxConf = [BXEmulatorConfiguration configuration];
		
		//These are the settings we want to keep in the configuration file
		NSNumber *fixedSpeed	= [gameSettings objectForKey: @"fixedSpeed"];
		NSNumber *isAutoSpeed	= [gameSettings objectForKey: @"autoSpeed"];
		NSNumber *coreMode		= [gameSettings objectForKey: @"coreMode"];
		
		if (coreMode)
		{
			NSString *coreString = [BXEmulator configStringForCoreMode: [coreMode integerValue]];
			[gameboxConf setValue: coreString forKey: @"core" inSection: @"cpu"];
		}
		
		if (fixedSpeed || isAutoSpeed)
		{
			NSString *cyclesString = [BXEmulator configStringForFixedSpeed: [fixedSpeed integerValue]
																	isAuto: [isAutoSpeed boolValue]];
			
			[gameboxConf setValue: cyclesString forKey: @"cycles" inSection: @"cpu"];
		}
		
		//Strip out these settings once we're done, so we won't preserve them in user defaults
		[gameSettings removeObjectsForKeys: [NSArray arrayWithObjects: @"fixedSpeed", @"autoSpeed", @"coreMode", nil]];

		
		//Persist the gamebox-specific configuration into the gamebox's configuration file.
		NSString *configPath = [[self gamePackage] configurationFilePath];
		[self _saveConfiguration: gameboxConf toFile: configPath];
		
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
	if ([self isGamePackage]) return [[self gamePackage] gameName];
	else return [self processDisplayName];
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
	if ([self isGamePackage]) return [[self gamePackage] coverArt];
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

- (NSArray *) executables
{
	NSWorkspace *workspace		= [NSWorkspace sharedWorkspace];
	BXPackage *thePackage		= [self gamePackage];
	
	NSString *defaultTarget		= [[thePackage targetPath] stringByStandardizingPath];
	NSArray *executablePaths	= [[thePackage executables] sortedArrayUsingSelector: @selector(pathDepthCompare:)];
	NSMutableDictionary *executables = [NSMutableDictionary dictionaryWithCapacity: [executablePaths count]];
	
	for (NSString *path in executablePaths)
	{
		path = [path stringByStandardizingPath];
		NSString *fileName	= [path lastPathComponent];
		
		//If we already have an executable with this name, skip it so we don't offer ambiguous choices
		//TODO: this filtering should be done downstream in the UI controller, it's not our call
		if (![executables objectForKey: fileName])
		{
			NSImage *icon		= [workspace iconForFile: path];
			BOOL isDefault		= [path isEqualToString: defaultTarget];
			
			NSDictionary *data	= [NSDictionary dictionaryWithObjectsAndKeys:
				path,	@"path",
				icon,	@"icon",
				[NSNumber numberWithBool: isDefault], @"isDefault",
			nil];
			
			[executables setObject: data forKey: fileName];
		}
	}
	NSArray *filteredExecutables = [executables allValues];
	
	
	NSSortDescriptor *sortDefaultFirst = [[NSSortDescriptor alloc] initWithKey: @"isDefault" ascending: NO];
	
	NSSortDescriptor *sortByFilename = [[NSSortDescriptor alloc] initWithKey: @"path.lastPathComponent"
																   ascending: YES
																	selector: @selector(caseInsensitiveCompare:)];
	
	NSArray *sortDescriptors = [NSArray arrayWithObjects:
								[sortDefaultFirst autorelease],
								[sortByFilename autorelease],
								nil];
	
	return [filteredExecutables sortedArrayUsingDescriptors: sortDescriptors];
}


- (NSArray *) documentation
{
	NSWorkspace *workspace	= [NSWorkspace sharedWorkspace];
	BXPackage *thePackage	= [self gamePackage];
	
	NSArray *docPaths = [[thePackage documentation] sortedArrayUsingSelector: @selector(pathDepthCompare:)];
	NSMutableDictionary *documentation = [NSMutableDictionary dictionaryWithCapacity: [docPaths count]];
	
	for (NSString *path in docPaths)
	{
		path = [path stringByStandardizingPath];
		NSString *fileName	= [path lastPathComponent];
		
		//If we already have a document with this name, skip it so we don't offer ambiguous choices
		//TODO: this filtering should be done downstream in the UI controller, it's not our call
		if (![documentation objectForKey: fileName])
		{
			NSImage *icon		= [workspace iconForFile: path];
			NSDictionary *data	= [NSDictionary dictionaryWithObjectsAndKeys:
				path,	@"path",
				icon,	@"icon",
			nil];
			
			[documentation setObject: data forKey: fileName];
		}
	}
	return [documentation allValues];
}

+ (NSSet *) keyPathsForValuesAffectingIsGamePackage		{ return [NSSet setWithObject: @"gamePackage"]; }
+ (NSSet *) keyPathsForValuesAffectingRepresentedIcon	{ return [NSSet setWithObject: @"gamePackage.coverArt"]; }
+ (NSSet *) keyPathsForValuesAffectingDocumentation		{ return [NSSet setWithObject: @"gamePackage.documentation"]; }
+ (NSSet *) keyPathsForValuesAffectingExecutables
{
	return [NSSet setWithObjects: @"gamePackage.executables", @"gamePackage.targetPath", nil];
}


#pragma mark -
#pragma mark Delegate methods

//If we have not already performed our own configuration, do so now
- (void) runPreflightCommands
{
	if (!hasConfigured) [self _configureEmulator];
}

//If we have not already launched our default target, do so now (and then display the program picker)
- (void) runLaunchCommands
{	
	if (!hasLaunched)
	{
		[self _launchTarget];
	}
}

- (void) frameComplete: (BXFrameBuffer *)frame
{
	[[self DOSWindowController] updateWithFrame: frame];
}

- (NSSize) maxFrameSize
{
	return [[self DOSWindowController] maxFrameSize];
}

- (NSSize) viewportSize
{
	return [[self DOSWindowController] viewportSize];
}


#pragma mark -
#pragma mark Notifications

- (void) programWillStart: (NSNotification *)notification
{	
	//Don't set the active program if we already have one
	//This way, we keep track of when a user launches a batch file and don't immediately discard
	//it in favour of the next program the batch-file runs
	if (![self activeProgramPath])
	{
		[self setActiveProgramPath: [[notification userInfo] objectForKey: @"localPath"]];
		[DOSWindowController synchronizeWindowTitleWithDocumentName];
		
		//Hide the program picker after launching the default program 
		if ([[self activeProgramPath] isEqualToString: [gamePackage targetPath]])
		{
			[[self DOSWindowController] setProgramPanelShown: NO];
		}
	}
}

- (void) programDidFinish: (NSNotification *)notification
{
	//Clear the active program after every program has run during initial startup
	//This way, we don't 'hang onto' startup commands in programWillStart:
	//Once the default target has launched, we only reset the active program when
	//we return to the DOS prompt.
	if (!hasLaunched)
	{
		[self setActiveProgramPath: nil];		
	}
}

- (void) willRunStartupCommands: (NSNotification *)notification {}
- (void) didRunStartupCommands: (NSNotification *)notification {}

- (void) didReturnToShell: (NSNotification *)notification
{	
	//Clear the active program
	[self setActiveProgramPath: nil];
	[DOSWindowController synchronizeWindowTitleWithDocumentName];
	
	//Show the program chooser after returning to the DOS prompt
	if ([self isGamePackage] && [[self executables] count])
	{
		BOOL panelShown = [[self DOSWindowController] programPanelShown];
		
		//Show only after a delay, so that the window has time to resize after quitting the game
		if (!panelShown) [[self DOSWindowController] performSelector: @selector(toggleProgramPanelShown:)
														   withObject: self
														   afterDelay: 0.5];
	}
	
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey: @"startUpInFullScreen"])
	{
		//Drop out of fullscreen mode when we return to the prompt,
		//if we automatically switched into fullscreen at startup
		[[self DOSWindowController] exitFullScreen: self];
	}
}

- (void) didStartGraphicalContext: (NSNotification *)notification
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey: @"startUpInFullScreen"])
	{
		//Switch to fullscreen mode automatically after a brief delay
		//This will be cancelled if the context exits within that time - see below
		[[self DOSWindowController] performSelector: @selector(toggleFullScreenWithZoom:) 
										  withObject: [NSNumber numberWithBool: YES] 
										  afterDelay: 0.5];
	}
}

- (void) didEndGraphicalContext: (NSNotification *)notification
{
	[NSObject cancelPreviousPerformRequestsWithTarget: [self DOSWindowController]
											 selector: @selector(toggleFullScreenWithZoom:)
											   object: [NSNumber numberWithBool: YES]];
}

- (void) didChangeEmulationState: (NSNotification *)notification
{
	//These reside in BXEmulatorController, as should this function, but so be it
	[self willChangeValueForKey: @"sliderSpeed"];
	[self didChangeValueForKey: @"sliderSpeed"];
	
	[self willChangeValueForKey: @"frameskip"];
	[self didChangeValueForKey: @"frameskip"];
	
	[self willChangeValueForKey: @"dynamic"];
	[self didChangeValueForKey: @"dynamic"];	
}


#pragma mark -
#pragma mark Private methods

- (void) _startEmulator
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
	
	//Start up the emulator itself.
	[[self emulator] start];
	
	//Flag that we're no longer emulating.
	//(This will have been set to YES in _configureEmulator)
	[self setEmulating: NO];
	
	//Close the document once we're done.
	if ([self closeOnEmulatorExit]) [self close];
}


- (void) _configureEmulator
{
	BXEmulator *theEmulator	= [self emulator];
	BXPackage *package		= [self gamePackage];
	
	if (package)
	{
		//Mount the game package as a new hard drive, at drive C
		//(This may get replaced below by a custom bundled C volume)
		BXDrive *packageDrive = [BXDrive hardDriveFromPath: [package gamePath] atLetter: @"C"];
		packageDrive = [theEmulator mountDrive: packageDrive];
		
		//Then, mount any extra volumes included in the game package
		NSMutableArray *packageVolumes = [NSMutableArray arrayWithCapacity: 10];
		[packageVolumes addObjectsFromArray: [package floppyVolumes]];
		[packageVolumes addObjectsFromArray: [package hddVolumes]];
		[packageVolumes addObjectsFromArray: [package cdVolumes]];
		
		BXDrive *bundledDrive;
		for (NSString *volumePath in packageVolumes)
		{
			bundledDrive = [BXDrive driveFromPath: volumePath atLetter: nil];
			//The bundled drive was explicitly set to drive C, override our existing C package-drive with it
			if ([[bundledDrive letter] isEqualToString: @"C"])
			{
				[[self emulator] unmountDriveAtLetter: @"C"];
				packageDrive = bundledDrive;
				//Rewrite the target to point to the new C drive, if it was pointing to the old one
				if ([[self targetPath] isEqualToString: [packageDrive path]]) [self setTargetPath: volumePath]; 
			}
			[[self emulator] mountDrive: bundledDrive];
		}
	}
	//TODO: if we're not loading a package, then C should be the DOS Games folder instead
	
	//Automount all currently mounted floppy and CD-ROM volumes
	[self mountFloppyVolumes];
	[self mountCDVolumes];
	
	//Mount our internal DOS toolkit at the appropriate drive
	NSString *toolkitDriveLetter	= [[NSUserDefaults standardUserDefaults] stringForKey: @"toolkitDriveLetter"];
	NSString *toolkitFiles			= [[NSBundle mainBundle] pathForResource: @"DOS Toolkit" ofType: nil];
	BXDrive *toolkitDrive			= [BXDrive hardDriveFromPath: toolkitFiles atLetter: toolkitDriveLetter];
	
	//Hide and lock the toolkit drive so that it will not appear in the drive manager UI
	[toolkitDrive setLocked: YES];
	[toolkitDrive setReadOnly: YES];
	[toolkitDrive setHidden: YES];
	toolkitDrive = [theEmulator mountDrive: toolkitDrive];
	
	//Point DOS to the correct paths if we've mounted the toolkit drive successfully
	//TODO: we should treat this as an error if it didn't mount!
	if (toolkitDrive)
	{
		//Todo: the DOS path should include the root folder of every drive, not just Y and Z.
		NSString *dosPath	= [NSString stringWithFormat: @"%1$@:\\;%1$@:\\UTILS;Z:\\", [toolkitDrive letter], nil];
		NSString *ultraDir	= [NSString stringWithFormat: @"%@:\\ULTRASND", [toolkitDrive letter], nil];
		
		[theEmulator setVariable: @"path"		to: dosPath		encoding: BXDirectStringEncoding];
		[theEmulator setVariable: @"ultradir"	to: ultraDir	encoding: BXDirectStringEncoding];
	}
	
	
	//Mount a temporary folder at the appropriate drive
	NSFileManager *manager		= [NSFileManager defaultManager];
	NSString *tempDriveLetter	= [[NSUserDefaults standardUserDefaults] stringForKey: @"temporaryDriveLetter"];
	NSString *tempDrivePath		= [manager createTemporaryDirectoryWithPrefix: @"Boxer" error: NULL];
	
	if (tempDrivePath)
	{
		temporaryFolderPath = [tempDrivePath retain];
		
		BXDrive *tempDrive = [BXDrive hardDriveFromPath: tempDrivePath atLetter: tempDriveLetter];
		[tempDrive setLocked: YES];
		[tempDrive setHidden: YES];
		
		tempDrive = [theEmulator mountDrive: tempDrive];
		
		if (tempDrive)
		{
			NSString *tempPath = [NSString stringWithFormat: @"%@:\\", [tempDrive letter], nil];
			[theEmulator setVariable: @"temp"	to: tempPath		encoding: BXDirectStringEncoding];
			[theEmulator setVariable: @"tmp"	to: tempPath		encoding: BXDirectStringEncoding];
		}		
	}
	
	
	//Once all regular drives are in place, make a mount point allowing access to our target program/folder,
	//if it's not already accessible in DOS.
	if ([self targetPath])
	{
		if ([self shouldMountDriveForPath: targetPath]) [self mountDriveForPath: targetPath];
	}
	
	//Flag that we have completed our initial game configuration.
	hasConfigured = YES;
	[self setEmulating: YES];
	
	//From here on out, it's OK to show drive notifications.
	showDriveNotifications = YES;
}

- (void) _launchTarget
{
	hasLaunched = YES;
	
	//Do any just-in-time configuration, which should override all previous startup stuff
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
		NSUInteger optionKeyDown = [[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask;
		if (optionKeyDown != 0 && [[self class] isExecutable: target])
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
			if (profileConf)
			{
				//First go through the settings, checking if any are the same as the profile config's.
				for (NSString *sectionName in [gameboxConf settings])
				{
					NSDictionary *section = [gameboxConf settingsForSection: sectionName];
					for (NSString *settingName in [section allKeys])
					{
						NSString *gameboxValue = [gameboxConf valueForKey: settingName inSection: sectionName];
						NSString *profileValue = [profileConf valueForKey: settingName inSection: sectionName];
						
						//If the value we'd be persisting is the same as the profile's value,
						//remove it from the persisted configuration file.
						if ([gameboxValue isEqualToString: profileValue])
							[gameboxConf removeValueForKey: settingName inSection: sectionName];
					}
				}
				
				//Now, eliminate duplicate startup commands too.
				//IMPLEMENTATION NOTE: for now we leave the startup commands alone unless the two sets
				//have exactly the same commands in the same order. There's too many risks involved 
				//for us to remove partial sets of duplicate startup commands.
				NSArray *profileCommands = [profileConf startupCommands];
				NSArray *gameboxCommands = [gameboxConf startupCommands];
				
				if ([gameboxCommands isEqualToArray: profileCommands])
					[gameboxConf removeStartupCommands];
			}
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

@end
