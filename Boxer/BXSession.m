/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXSession.h"
#import "BXPackage.h"
#import "BXAppController.h"
#import "BXInspectorController.h"
#import "BXSessionWindowController+BXRenderController.h"

#import "BXSession+BXFileManager.h"
#import "BXDrive.h"
#import "BXEmulator+BXDOSFileSystem.h"
#import "BXEmulator+BXShell.h"
#import "BXSessionWindow.h"
#import "NSWorkspace+BXFileTypes.h"


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
	if (![self hasStarted]) [self start];
}


//Close down the active DOSBox emulator and free the document
- (void) close
{
	//This closes down the whole application as soon as the current session closes.
	//Historically we did this because DOSBox stores state in global variables it
	//doesn't bother resetting, which means a second DOSBox session could not be
	//started after the first as it would inherit an invalid state.
	
	//However, quitting-on-close now also covers a clutch of really bad amateur bugs
	//in Boxer itself whereby various components will fail to cope when other bits
	//are suddenly not there. Leaving this quit-on-close in place is now only a
	//bandaid workaround to prevent crashes until I've fix these bugs properly.
	
	[NSApp terminate: self];
	
	//These lines are currently never reached.
	[self cancel];
	[super close];
}


- (void) dealloc
{
	[[self emulator] setDelegate: nil];
	[self setEmulator: nil],			[emulator release];
	[self setGamePackage: nil],			[gamePackage release];
	[self setTargetPath: nil],			[targetPath release];
	[self setActiveProgramPath: nil],	[activeProgramPath release];
	[super dealloc];
}


- (IBAction) toggleInspectorPanel: (id)sender
{
	BXInspectorController *inspector = [BXInspectorController controller];
	
	//Hide the inspector if it is already visible
	if ([inspector isWindowLoaded] && [[inspector window] isVisible])
	{
		[[inspector window] orderOut: sender];
	}
	else
	{
		//Escape from fullscreen when showing the inspector
		[[self mainWindowController] exitFullScreen: sender];
		[inspector showWindow: sender];
	}
}


- (void) setEmulator: (BXEmulator *)theEmulator
{
	[self willChangeValueForKey: @"emulator"];
	
	if (theEmulator != emulator)
	{
		[self _deregisterForProcessNotifications];
		[self _deregisterForFilesystemNotifications];
		//[emulator removeObserver: self forKeyPath: @"finished"];
		[emulator autorelease];
	
		emulator = [theEmulator retain];
	
		if (theEmulator)
		{
			[theEmulator setDelegate: self];
			[self _registerForFilesystemNotifications];
			[self _registerForProcessNotifications];
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
	[self setEmulator: [[BXEmulator new] autorelease]];
		
	//Avoid using the operation queue for now and just start the operation manually;
	//OS X 10.6 operation queues will run all NSOperations concurrently, so ours will
	//break until the multithreading code is working properly.
	
	//NSOperationQueue *queue = [[NSApp delegate] emulationQueue];
	//[queue addOperation: [self emulator]];
	

	NSString *preflightConfig	= [[NSBundle mainBundle] pathForResource: @"Preflight" ofType: @"conf"];
	[[self emulator] addConfigFile: preflightConfig];
	
	if ([self gamePackage])
	{
		NSString *packageConfig = [[self gamePackage] configurationPath];
		if (packageConfig) [[self emulator] addConfigFile: packageConfig];
	}
	
	NSString *launchConfig		= [[NSBundle mainBundle] pathForResource: @"Launch" ofType: @"conf"];
    [[self emulator] addConfigFile: launchConfig];
	
	[[self emulator] start];
	[self close];
}



//Cancel the DOSBox emulator thread
- (void)cancel	{ [[self emulator] cancel]; }

/*
//Close ourselves when we detect the emulator thread has terminated
- (void)observeValueForKeyPath: (NSString *)keyPath
					  ofObject: (id)object
						change: (NSDictionary *)change
					   context: (void *)context
{
	if (object == [self emulator])
	{
		if ([object isFinished]) [self close];
	}
}
*/

//Describing the active DOS process
//---------------------------------
- (NSString *) sessionDisplayName
{
	if (![self isGamePackage]) return [self processDisplayName];
	else return [[self displayName] stringByDeletingPathExtension];
}

- (NSString *) processDisplayName
{
	NSString *displayName;
	if ([emulator isRunningProcess] && ![emulator processIsInternal])
		displayName = [[emulator processName] capitalizedString];
	else
		displayName = NSLocalizedString(@"MS-DOS Prompt", @"The standard process name when the session is at the DOS prompt.");
	return displayName;
}
+ (NSSet *) keyPathsForValuesAffectingProcessDisplayName	{ return [NSSet setWithObject: @"emulator.processName"]; }
+ (NSSet *) keyPathsForValuesAffectingSessionDisplayName	{ return [NSSet setWithObject: @"self.processDisplayName"]; }



//Introspecting the game package itself
//-------------------------------------

- (void) setFileURL: (NSURL *)fileURL
{	
	NSWorkspace *workspace	= [NSWorkspace sharedWorkspace];
	NSString *filePath		= [[fileURL path] stringByStandardizingPath];
	NSString *packagePath	= [workspace parentOfFile: filePath matchingTypes: [NSArray arrayWithObject: @"net.washboardabs.boxer-game-package"]];
	
	[self setTargetPath: filePath];
	
	//If the fileURL is (or was located inside) a gamebox, we use the gamebox as the fileURL instead, and track the original
	//fileURL as our targetPath (which then gets called later in launchSession.) This way, the DOS window will show the
	//gamebox as the represented file and our Recent Documents list will likewise list the gamebox instead.
	if (packagePath)
	{
		BXPackage *package = (BXPackage *)[BXPackage bundleWithPath: packagePath];
		[self setGamePackage: package];

		fileURL = [NSURL fileURLWithPath: packagePath];
		
		//If we opened a package directly, check if it has a target of its own; if so, use that as our target path.
		if ([filePath isEqualToString: packagePath])
		{
			NSString *packageTarget = [package targetPath];
			if (packageTarget) [self setTargetPath: packageTarget];
		}
	}

	[super setFileURL: fileURL];
}

- (BOOL) isGamePackage	{ return ([self gamePackage] != nil); }

//Returns a unique identifier for the package 
- (NSString *) uniqueIdentifier
{
	if (![self isGamePackage]) return nil;
	//The path is too brittle, so instead we use the display name. This, in turn, is probably both too lenient and still too brittle. What we really ought to do is use an alias as the unique ID, but those are complicated to make and bulky to store.
	else return [self displayName];
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
	return [executables allValues];
}


- (NSArray *) documentation
{
	NSWorkspace *workspace		= [NSWorkspace sharedWorkspace];
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

- (void) _configureSession
{
	BXEmulator *theEmulator = [self emulator];
	
	BXPackage *package = [self gamePackage];
	if (package)
	{
		//Mount the game package as a new hard drive, at drive C
		BXDrive *packageDrive = [BXDrive hardDriveFromPath: [package gamePath] atLetter: @"C"];
		packageDrive = [theEmulator mountDrive: packageDrive];
		
		//Then, mount any extra volumes included in the game package
		NSMutableArray *packageVolumes = [NSMutableArray arrayWithCapacity: 10];
		[packageVolumes addObjectsFromArray: [package floppyVolumes]];
		[packageVolumes addObjectsFromArray: [package hddVolumes]];
		[packageVolumes addObjectsFromArray: [package cdVolumes]];
		
		for (NSString *volumePath in packageVolumes)
		{
			if ([self shouldMountDriveForPath: volumePath]) [self mountDriveForPath: volumePath];
		}
	}
	
	//Automount all currently mounted CD-ROM volumes
	[self mountCDVolumes];
	
	//Mount our internal DOS toolkit at the appropriate drive
	NSString *toolkitDriveLetter	= [[NSUserDefaults standardUserDefaults] stringForKey: @"toolkitDriveLetter"];
	NSString *toolkitFiles			= [[NSBundle mainBundle] pathForResource: @"DOS Toolkit" ofType: nil];
	BXDrive *toolkitDrive		= [BXDrive hardDriveFromPath: toolkitFiles atLetter: toolkitDriveLetter];
	
	[toolkitDrive setReadOnly: YES];
	[toolkitDrive setHidden: YES];
	toolkitDrive = [theEmulator mountDrive: toolkitDrive];
	
	//Point DOS to the correct paths if we've mounted the toolkit drive successfully
	//TODO: we should treat this as an error if it didn't mount!
	if (toolkitDrive)
	{
		NSString *dosPath	= [NSString stringWithFormat: @"%1$@:\\;%1$@:\\UTILS;Z:\\", [toolkitDrive letter], nil];
		NSString *ultraDir	= [NSString stringWithFormat: @"%@\\ULTRASND", [toolkitDrive letter], nil];
		
		[theEmulator setVariable: @"path"		to: dosPath		encoding: BXDirectStringEncoding];
		[theEmulator setVariable: @"ultradir"	to: ultraDir	encoding: BXDirectStringEncoding];
	}
	
	//Finally, make a mount for our represented file URL, if it's not already accessible
	if ([self fileURL])
	{
		NSString *filePath = [[self fileURL] path];
		if ([self shouldMountDriveForPath: filePath]) [self mountDriveForPath: filePath];
	}
	
	//Flag that we have completed our initial game configuration
	isConfigured = YES;
}

//After all preflight configuration has finished, go ahead and open whatever file we're pointing at
- (void) _launchSession
{
	NSString *target = [self targetPath];
	if (target)
	{
		//If the Option key was held down, don't launch the gamebox's target;
		//Instead, switch to its parent folder and show the program picker
		if ([[self class] isExecutable: target] && [[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask)
		{
			[self openFileAtPath: [target stringByDeletingLastPathComponent]];
		}
		else
		{
			[self openFileAtPath: target];
		}
	}
}


//Monitoring process changes in the emulator
//------------------------------------------

- (void) _registerForProcessNotifications
{
	BXEmulator *theEmulator			= [self emulator];
	NSNotificationCenter *center	= [NSNotificationCenter defaultCenter];
	
	[center addObserver:	self
			   selector:	@selector(processDidStart:)
				   name:	@"BXProcessDidStartNotification"
				 object:	theEmulator];
	
	[center addObserver:	self
			   selector:	@selector(processDidReturnToShell:)
				   name:	@"BXProcessDidReturnToShellNotification"
				 object:	theEmulator];
}

- (void) _deregisterForProcessNotifications
{
	BXEmulator *theEmulator	= [self emulator];
	NSNotificationCenter *center	= [NSNotificationCenter defaultCenter];
	
	[center removeObserver: self name: @"BXProcessDidStartNotification"			object: theEmulator];
	[center removeObserver: self name: @"BXProcessDidReturnToShellNotification"	object: theEmulator];
}

- (void) processDidStart: (NSNotification *)notification
{	
	//If we don't know the active program ahead of time, try to figure it out
	if (![self activeProgramPath] && ![emulator processIsInternal])
	{
		//DO SOMETHING CLEVER HERE TO DETECT THE PATH OF THE CURRENTLY EXECUTING PROGRAM
	}
}

- (void) processDidReturnToShell: (NSNotification *)notification
{
	BXEmulator *theEmulator = [self emulator];
	
	//Clear the active program
	[self setActiveProgramPath: nil];
	
	//Now that control has reverted to the shell, display the program chooser if appropriate
	//Note: only do this the first time we quit, not every time
	if ([self isGamePackage] && [[self executables] count])
	{
		[(BXSessionWindow *)[[self mainWindowController] window] setProgramPanelShown: YES];
	}
}

@end