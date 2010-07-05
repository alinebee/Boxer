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


#pragma mark -
#pragma mark Private method declarations

@interface BXSession ()

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

@end


#pragma mark -
#pragma mark Implementation

@implementation BXSession

@synthesize mainWindowController;
@synthesize gamePackage;
@synthesize emulator;
@synthesize targetPath;
@synthesize activeProgramPath;
@synthesize gameProfile;


#pragma mark -
#pragma mark Initialization and cleanup

- (id) init
{
	if ((self = [super init]))
	{
		//[self setEmulator: [[[BXEmulator alloc] init] autorelease]];
	}
	return self;
}

- (void) dealloc
{
	[self setMainWindowController: nil],[mainWindowController release];
	[self setEmulator: nil],			[emulator release];
	[self setGamePackage: nil],			[gamePackage release];
	[self setGameProfile: nil],			[gameProfile release];
	[self setTargetPath: nil],			[targetPath release];
	[self setActiveProgramPath: nil],	[activeProgramPath release];
	
	[super dealloc];
}

//We make this a no-op to avoid creating an NSFileWrapper - we don't ever actually read any data off disk,
//so we don't need to construct a representation of the filesystem, and trying to do so for large documents
//(e.g. root folders) can cause memory allocation crashes.
- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
	return YES;
}

- (void) makeWindowControllers
{
	id controller = [[BXSessionWindowController alloc] initWithWindowNibName: @"DOSWindow"];
	[self addWindowController:		controller];
	[self setMainWindowController:	controller];	
	[controller setShouldCloseDocument: YES];
	
	[controller release];
}

- (void) showWindows
{
	[super showWindows];
	
	//Start the emulator as soon as our windows appear
	[self start];
}

- (void) setEmulator: (BXEmulator *)newEmulator
{
	[self willChangeValueForKey: @"emulator"];
	
	if (newEmulator != emulator)
	{
		if (emulator)
		{
			[emulator setDelegate: nil];
			[emulator unbind: @"gameProfile"];
			[self _deregisterForFilesystemNotifications];
		}
		
		[emulator release];
		emulator = [newEmulator retain];
	
		if (newEmulator)
		{
			[newEmulator setDelegate: self];
			[emulator bind: @"gameProfile" toObject: self withKeyPath: @"gameProfile" options: nil];
			[self _registerForFilesystemNotifications];
		}
	}
	
	[self didChangeValueForKey: @"emulator"];
}

- (BOOL) isEmulating
{
	return hasConfigured;
}

//Create our DOSBox emulator and add it to the operations queue
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

//Cancel the DOSBox emulator thread
- (void)cancel	{ [[self emulator] cancel]; }

//Tell the emulator to close itself down when the document closes
- (void) close
{
	[self cancel];
	[super close];
}


#pragma mark -
#pragma mark Describing the document/process

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


#pragma mark -
#pragma mark Introspecting the gamebox

- (void) setFileURL: (NSURL *)fileURL
{	
	NSWorkspace *workspace	= [NSWorkspace sharedWorkspace];
	NSString *filePath		= [[fileURL path] stringByStandardizingPath];
	
	//Check if this file path is located inside a gamebox
	NSString *packagePath	= [workspace parentOfFile: filePath
										matchingTypes: [NSArray arrayWithObject: @"net.washboardabs.boxer-game-package"]];
	
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
	[[self mainWindowController] updateWithFrame: frame];
}

- (NSSize) maxFrameSize
{
	return [[self mainWindowController] maxFrameSize];
}

- (NSSize) viewportSize
{
	return [[self mainWindowController] viewportSize];
}


#pragma mark -
#pragma mark Notifications

- (void) programWillStart: (NSNotification *)notification
{	
	//Don't set the active program if we already have one
	//This way, we keep track of when a user launches a batch file, and don't immediately discard it
	if (![self activeProgramPath])
	{
		[self setActiveProgramPath: [[notification userInfo] objectForKey: @"localPath"]];
		[mainWindowController synchronizeWindowTitleWithDocumentName];
		
		//Hide the program picker after launching the default program 
		if ([[self activeProgramPath] isEqualToString: [gamePackage targetPath]])
		{
			[[self mainWindowController] setProgramPanelShown: NO];
		}
	}
}

- (void) programDidFinish: (NSNotification *)notification {}

- (void) didReturnToShell: (NSNotification *)notification
{
	BXEmulator *theEmulator = [self emulator];
	
	//Clear the active program
	[self setActiveProgramPath: nil];
	[mainWindowController synchronizeWindowTitleWithDocumentName];
	
	//Show the program chooser after returning to the DOS prompt
	if ([self isGamePackage] && [[self executables] count])
	{
		BOOL panelShown = [[self mainWindowController] programPanelShown];
		
		//Show only after a delay, so that the window has time to resize after quitting the game
		if (!panelShown) [[self mainWindowController] performSelector: @selector(toggleProgramPanelShown:)
														   withObject: self
														   afterDelay: 0.5];
	}
	
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey: @"startUpInFullScreen"])
	{
		//Drop out of fullscreen mode when we return to the prompt,
		//if we automatically switched into fullscreen at startup
		[[self mainWindowController] exitFullScreen: self];
	}
}

- (void) didStartGraphicalContext: (NSNotification *)notification
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey: @"startUpInFullScreen"])
	{
		//Switch to fullscreen mode automatically after a brief delay
		//This will be cancelled if the context exits within that time - see below
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
	//Create a new emulator instance for ourselves
	[self setEmulator: [[[BXEmulator alloc] init] autorelease]];
	
	
	//The configuration files we may be loading today
	NSString *preflightConf	= [[NSBundle mainBundle] pathForResource: @"Preflight" ofType: @"conf"];
	NSString *profileConf	= nil;
	NSString *packageConf	= nil;
	NSString *launchConf	= [[NSBundle mainBundle] pathForResource: @"Launch" ofType: @"conf"];
	
	
	//Which folder to look in to detect the game we’re running.
	//The preferred mount point is a convenient choice for this: it will choose any
	//gamebox, Boxer drive folder or floppy/CD volume in the file's path, falling
	//back on its containing folder otherwise.
	NSString *profileDetectionPath = nil;
	BOOL shouldRecurse = NO;
	if ([self targetPath])
	{
		profileDetectionPath = [self gameDetectionPointForPath: [self targetPath] 
										shouldSearchSubfolders: &shouldRecurse];
	}
	
	//Detect any appropriate game profile for this session
	if (profileDetectionPath)
	{
		//IMPLEMENTATION NOTE: we only scan subfolders of the detection path if it's a gamebox,
		//mountable folder or CD/floppy disk, since these will have a finite and manageable file
		//heirarchy to scan.
		//Otherwise, we restrict our search to just the base folder to avoids massive blowouts
		//if the user opens something big like their home folder or startup disk, and to avoid
		//false positives when opening the DOS Games folder.
		[self setGameProfile: [BXGameProfile detectedProfileForPath: profileDetectionPath
												   searchSubfolders: shouldRecurse]];
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
	if ([self gamePackage])
	{
		packageConf = [[self gamePackage] configurationFile];
		
		//If the gamebox had no configuration file, give it an empty generic configuration file.
		//(We don't bother loading it, since it's empty anyway)
		if (!packageConf)
		{
			NSString *genericConf = [[NSBundle mainBundle] pathForResource: @"Generic"
																	ofType: @"conf"
															   inDirectory: @"Configurations"];
			[[self gamePackage] setConfigurationFile: genericConf];
		}
	}
	
	//Load all our configuration files in order.
	[emulator applyConfigurationAtPath: preflightConf];
	if (profileConf) [emulator applyConfigurationAtPath: profileConf];
	if (packageConf) [emulator applyConfigurationAtPath: packageConf];
	[emulator applyConfigurationAtPath: launchConf];
	
	//Start up the emulator itself.
	[[self emulator] start];
	
	//Once the emulator exits, close the document also.
	[self close];
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
	[self willChangeValueForKey: @"isEmulating"];
	hasConfigured = YES;
	[self didChangeValueForKey: @"isEmulating"];
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
@end