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
#import "BXSessionWindowController+BXRenderController.h"

#import "BXSession+BXFileManager.h"
#import "BXEmulator+BXDOSFileSystem.h"
#import "BXEmulator+BXShell.h"
#import "NSWorkspace+BXFileTypes.h"
#import "NSString+BXPaths.h"


@implementation BXSession

@synthesize mainWindowController;
@synthesize gamePackage;
@synthesize emulator;
@synthesize targetPath;
@synthesize activeProgramPath;


//Get the current (and only) DOS session, presented as a singleton
+ (id) mainSession	{ return [[NSApp delegate] currentSession]; }


//Initialization and cleanup methods
//----------------------------------

- (void) dealloc
{
	[self setEmulator: nil],			[emulator release];
	[self setGamePackage: nil],			[gamePackage release];
	[self setTargetPath: nil],			[targetPath release];
	[self setActiveProgramPath: nil],	[activeProgramPath release];
	[super dealloc];
}

//We only implement this to keep drag-drop opening happy - we don't ever actually read any data off disk.
- (BOOL)readFromFileWrapper:(NSFileWrapper *)fileWrapper ofType:(NSString *)typeName error:(NSError **)outError
{
	return YES;
}

- (void) makeWindowControllers
{
	id mainWindow = [[[BXSessionWindowController alloc] initWithWindowNibName: @"DOSWindow"] autorelease];
	[self addWindowController:		mainWindow];
	[self setMainWindowController:	mainWindow];	
	[mainWindow setShouldCloseDocument: YES];
}

- (void) showWindows
{
	[super showWindows];
	//Start the emulator as soon as our windows appear
	if (![self hasStarted]) [self start];
}

- (void) setEmulator: (BXEmulator *)theEmulator
{
	[self willChangeValueForKey: @"emulator"];
	
	if (theEmulator != emulator)
	{
		if (emulator)
		{
			[self _deregisterForFilesystemNotifications];
			[emulator setDelegate: nil];
			[emulator cancel];
			[emulator autorelease];
		}
		
		emulator = [theEmulator retain];
	
		if (theEmulator)
		{
			[theEmulator setDelegate: self];
			[self _registerForFilesystemNotifications];
		}
	}
	
	[self didChangeValueForKey: @"emulator"];
}

- (BOOL) hasStarted
{
	return [self emulator] != nil; 
}

//Create our DOSBox emulator and add it to the operations queue
- (void) start
{
	//We schedule our internal _startEmulator method to be called separately on the main thread,
	//so that it doesn't block completion of whatever UI event led to this being called.
	//This prevents menu highlights from getting 'stuck' because of DOSBox's main loop blocking
	//the thread.
	
	[self performSelector: @selector(_startEmulator) withObject: nil afterDelay: 0];  
}

//Cancel the DOSBox emulator thread
- (void)cancel	{ [[self emulator] cancel]; }


//Close down the emulator and free the document
- (void) close
{
	//This closes down the whole application as soon as the current session closes.
	//Historically we did this because DOSBox stores state in global variables which 
	//don't get reset when it 'quits', which means a second DOSBox session cannot be
	//successfully started after the first since it inherits an invalid state.
	
	//However, quitting-on-close now also conceals a clutch of really bad amateur bugs
	//in Boxer itself whereby various components will fail to cope when other bits
	//are suddenly not there. Leaving this quit-on-close in place is now only a
	//bandaid workaround to prevent crashes until I've fixed these bugs properly.
	
	[self cancel];
	[super close];

	[NSApp terminate: self];
}


//Describing the active DOS process
//---------------------------------

- (NSString *) displayName
{
	if ([self isGamePackage]) return [self gameDisplayName];
	else return [self processDisplayName];
}

- (NSString *) gameDisplayName
{
	NSString *gameName = [super displayName];
	if ([[[gameName pathExtension] lowercaseString] isEqualToString: @"boxer"])
		gameName = [gameName stringByDeletingPathExtension];
	return gameName;
}

- (NSString *) processDisplayName
{
	NSString *processName = nil;
	if ([emulator isRunningProcess])
		//Use the active program name where possible;
		//Failing that, fall back on the original process name
		if ([self activeProgramPath]) processName = [[self activeProgramPath] lastPathComponent];
		else processName = [emulator processName];
		
	return processName;
}
+ (NSSet *) keyPathsForValuesAffectingProcessDisplayName
{
	return [NSSet setWithObjects: @"activeProgramPath", @"emulator.processName", nil];
}



//Introspecting the game package itself
//-------------------------------------

- (void) setFileURL: (NSURL *)fileURL
{	
	NSWorkspace *workspace	= [NSWorkspace sharedWorkspace];
	NSString *filePath		= [[fileURL path] stringByStandardizingPath];
	NSString *packagePath	= [workspace parentOfFile: filePath matchingTypes: [NSArray arrayWithObject: @"net.washboardabs.boxer-game-package"]];
	
	[self setTargetPath: filePath];
	
	//If the fileURL is located inside a gamebox, we use the gamebox itself as the fileURL
	//and track the original fileURL as our targetPath (which gets used later in _launchTarget.)
	//This way, the DOS window will show the gamebox as the represented file and our Recent Documents
	//list will likewise show the gamebox instead.
	if (packagePath)
	{
		BXPackage *package = [[BXPackage alloc] initWithPath: packagePath];
		[self setGamePackage: package];

		fileURL = [NSURL fileURLWithPath: packagePath];
		
		//If we opened a package directly, check if it has a target of its own; if so, use that as our target path.
		if ([filePath isEqualToString: packagePath])
		{
			NSString *packageTarget = [package targetPath];
			if (packageTarget) [self setTargetPath: packageTarget];
		}
		[package release];
	}

	[super setFileURL: fileURL];
}

- (BOOL) isGamePackage	{ return ([self gamePackage] != nil); }

//Returns a unique identifier for the package 
- (NSString *) uniqueIdentifier
{
	if (![self isGamePackage]) return nil;
	//The path is too brittle, so instead we use the display name. This, in turn, is probably both too lenient and still too brittle. What we really ought to do is use an alias as the unique ID, but those are complicated to make and bulky to store.
	else return [self gameDisplayName];
}

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
		[self willChangeValueForKey: @"representedIcon"];
		
		[thePackage setCoverArt: icon];
				
		//Force our file URL to appear to change, which will update icons elsewhere in the app 
		[self setFileURL: [self fileURL]];
		
		[self didChangeValueForKey: @"representedIcon"];
	}
}
+ (NSSet *) keyPathsForValuesAffectingRepresentedIcon	{ return [NSSet setWithObject: @"gamePackage.coverArt"]; }


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
			BOOL isDefault		= [path isEqualToString: targetPath];
			
			NSDictionary *data	= [NSDictionary dictionaryWithObjectsAndKeys:
				path,	@"path",
				icon,	@"icon",
				[NSNumber numberWithBool: isDefault], @"isDefault",
			nil];
			
			[executables setObject: data forKey: fileName];
		}
	}
	NSArray *filteredExecutables = [executables allValues];
	
	NSSortDescriptor *sortByFilename = [[[NSSortDescriptor alloc] initWithKey: @"path.lastPathComponent"
																	ascending: YES
																	 selector: @selector(caseInsensitiveCompare:)] autorelease];
	
	return [filteredExecutables sortedArrayUsingDescriptors: [NSArray arrayWithObject: sortByFilename]];
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
@end


@implementation BXSession (BXSessionInternals)


//Emulator initialisation
//-----------------------

- (void) _startEmulator
{
	[self setEmulator: [[BXEmulator new] autorelease]];
	
	NSMutableArray *configFiles = [[self emulator] configFiles];
	
	NSString *preflightConfig = [[NSBundle mainBundle] pathForResource: @"Preflight" ofType: @"conf"];
	[configFiles addObject: preflightConfig];
	
	BXPackage *thePackage = [self gamePackage];
	if (thePackage)
	{
		NSString *detectedConfig = nil;
		NSString *packageConfig = nil;
		
		//First, autodetect and load our own configuration file for this gamebox
		NSDictionary *gameProfile = [BXGameProfile detectedProfileForPath: [thePackage gamePath]];
		if (gameProfile)
		{
			NSString *configName = [gameProfile objectForKey: @"BXProfileConf"];
			detectedConfig = [[NSBundle mainBundle] pathForResource: configName
															 ofType: @"conf"
														inDirectory: @"Configurations"];
			
			if (detectedConfig) [configFiles addObject: detectedConfig];
		}
		//Then, load the gamebox's own configuration file, if it has one
		packageConfig = [thePackage configurationFile];
		if (packageConfig) [configFiles addObject: packageConfig];
		else
		{
			//If the gamebox doesn't already have its own configuration file,
			//copy the autodetected configuration into it
			if (detectedConfig)
			{
				[thePackage setConfigurationFile: detectedConfig];
			}
			else
			{
				//If no configuration was detected, copy the empty generic configuration file instead
				NSString *genericConfig = [[NSBundle mainBundle] pathForResource: @"Generic"
																		  ofType: @"conf"
																	 inDirectory: @"Configurations"];
				[thePackage setConfigurationFile: genericConfig];
			}
		}
	}
	
	NSString *launchConfig = [[NSBundle mainBundle] pathForResource: @"Launch" ofType: @"conf"];
	[configFiles addObject: launchConfig];
	
	
	[[self emulator] start];
	//If the emulator ever quits of its own accord, close the document also.
	//This will happen if the user types "exit" at the command prompt.
	[self close];
}

- (void) _configureEmulator
{
	BXEmulator *theEmulator	= [self emulator];
	BXPackage *package		= [self gamePackage];
	
	if (package)
	{
		//Mount the game package as a new hard drive, at drive C
		//(This may be replaced below by a custom bundled C volume)
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
				if ([[self targetPath] isEqualToString: [package gamePath]]) [self setTargetPath: volumePath]; 
			}
			[[self emulator] mountDrive: bundledDrive];
		}
	}
	
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
	
	//Finally, make a mount point allowing access to our target program/folder, if it's not already accessible in DOS.
	if ([self targetPath])
	{
		if ([self shouldMountDriveForPath: targetPath]) [self mountDriveForPath: targetPath];
	}
	
	//Flag that we have completed our initial game configuration.
	hasConfigured = YES;
}

//After all preflight configuration has finished, go ahead and open whatever file we're pointing at
- (void) _launchTarget
{
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
	
	//Flag that we have started up properly
	hasLaunched = YES;
}


//Monitoring process changes in the emulator
//------------------------------------------


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
		showProgramPanelOnReturnToShell = YES;
		[self _launchTarget];
	}
}

- (void) programWillStart: (NSNotification *)notification
{	
	//Don't set the active program if we already have one
	//This way, we keep track of when a user launches a batch file, and don't immediately discard it
	if (![self activeProgramPath])
	{
		[self setActiveProgramPath: [[notification userInfo] objectForKey: @"localPath"]];
	}
}

- (void) programDidFinish: (NSNotification *)notification {}

- (void) didReturnToShell: (NSNotification *)notification
{
	BXEmulator *theEmulator = [self emulator];
	
	//Clear the active program
	[self setActiveProgramPath: nil];
	
	//Show the program chooser, if that was queued up
	if (showProgramPanelOnReturnToShell)
	{
		if ([self isGamePackage] && [[self executables] count])
		{
			BOOL panelShown = [[self mainWindowController] programPanelShown];
			
			//Show only after a delay, so that the window has time to resize after quitting the game
			if (!panelShown) [[self mainWindowController] performSelector: @selector(toggleProgramPanelShown:)
															   withObject: self
															   afterDelay: 0.5];
		}
		showProgramPanelOnReturnToShell = NO;
	}
	
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey: @"startUpInFullScreen"])
	{
		//Dump out of fullscreen mode when we return to the prompt,
		//if we automatically switch into fullscreen at startup
		[[self mainWindowController] exitFullScreen: self];
	}
}

- (void) didStartGraphicalContext: (NSNotification *)notification
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey: @"startUpInFullScreen"])
	{
		//Switch to fullscreen mode automatically after a brief delay
		//This will be cancelled if the context exits within that time, see below
		[[self mainWindowController] performSelector: @selector(toggleFullScreenWithZoom:) 
										  withObject: [NSNumber numberWithBool: YES] 
										  afterDelay: 0.5];
	}
}

- (void) didEndGraphicalContext: (NSNotification *)notification
{
	[NSObject cancelPreviousPerformRequestsWithTarget: [self mainWindowController]
											 selector: @selector(toggleFullScreenWithZoom:)
											   object: [NSNumber numberWithBool: YES]];
}

- (void) frameComplete: (BXFrameBuffer *)frame
{
	[[self mainWindowController] drawFrame: frame];
}
@end