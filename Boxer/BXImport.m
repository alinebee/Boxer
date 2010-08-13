/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXImport.h"
#import "BXSessionPrivate.h"

#import "BXImportDOSWindowController.h"
#import "BXImportWindowController.h"

#import "BXAppController.h"
#import "BXGameProfile.h"
#import "BXImportError.h"
#import "BXPackage.h"

#import "BXImport+BXImportPolicies.h"
#import "BXSession+BXFileManager.h"

#import "NSWorkspace+BXFileTypes.h"
#import "NSWorkspace+BXMountedVolumes.h"
#import "NSWorkspace+BXExecutableTypes.h"
#import "NSString+BXPaths.h"


#pragma mark -
#pragma mark Private method declarations

@interface BXImport ()
@property (readwrite, retain, nonatomic) NSArray *installerPaths;
@property (readwrite, copy, nonatomic) NSString *sourcePath;
@property (readwrite, copy, nonatomic) NSString *preferredInstallerPath;

@property (readwrite, assign, nonatomic) BXImportStage importStage;
@property (readwrite, assign, nonatomic) BXOperationProgress stageProgress;

//Only defined for internal use
@property (copy, nonatomic) NSString *rootDrivePath;


//Create a new empty game package for our source path.
- (BOOL) _generateGameboxWithError: (NSError **)error;

//Used after running an installer to check if the installer has installed files to the gamebox.
//Determines how (and whether) we import the source path into the gamebox.
- (BOOL) _gameDidInstall;

@end


#pragma mark -
#pragma mark Actual implementation

@implementation BXImport
@synthesize importWindowController;
@synthesize sourcePath, rootDrivePath;
@synthesize installerPaths, preferredInstallerPath;
@synthesize importStage, stageProgress;

#pragma mark -
#pragma mark Initialization and deallocation

- (void) dealloc
{
	[self setSourcePath: nil],				[sourcePath release];
	[self setRootDrivePath: nil],			[rootDrivePath release];
	[self setImportWindowController: nil],	[importWindowController release];
	[self setInstallerPaths: nil],			[installerPaths release];
	[self setPreferredInstallerPath: nil],	[preferredInstallerPath release];
	[super dealloc];
}

- (id)initWithContentsOfURL: (NSURL *)absoluteURL
					 ofType: (NSString *)typeName
					  error: (NSError **)outError
{
	if ((self = [super initWithContentsOfURL: absoluteURL ofType: typeName error: outError]))
	{
		[self setFileURL: [NSURL fileURLWithPath: [self sourcePath]]];
		
		if ([self gameNeedsInstalling])
			[self setImportStage: BXImportWaitingForInstaller];
		else
			[self setImportStage: BXImportReadyToFinalize];
	}
	return self;
}

//Reads in a source path and determines how best to install it
- (BOOL) readFromURL: (NSURL *)absoluteURL
			  ofType: (NSString *)typeName
			   error: (NSError **)outError
{
	NSString *path = [absoluteURL path];
	
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	BXGameProfile *detectedProfile = nil;
	
	NSMutableArray *detectedInstallers	= nil;
	NSArray *executables				= nil;
	NSString *preferredInstaller		= nil;
	NSString *mountedVolumePath			= nil;
	
	//If the chosen path was a disk image, mount it and use the mounted volume as our source
	if ([workspace file: path matchesTypes: [NSSet setWithObject: @"public.disk-image"]])
	{
		mountedVolumePath = [workspace mountImageAtPath: path error: outError];
		
		if (mountedVolumePath) path = mountedVolumePath;
		//If the mount failed, bail out immediately
		else return NO;
	}
	
	//If the chosen path was an audio CD, check if it has a corresponding data path	
	//(If not, then we'll throw an error later on when we can't find any executables on it)
	else if ([[workspace volumeTypeForPath: path] isEqualToString: audioCDVolumeType])
	{
		NSString *dataVolumePath = [workspace dataVolumeOfAudioCD: path];
		if (dataVolumePath) path = dataVolumePath;
	}
	
	//Now, autodetect the game and installers from the selected path
	detectedProfile	= [BXGameProfile detectedProfileForPath: path searchSubfolders: YES];
	executables		= [[self class] executablesAtPath: path recurse: YES];
	
	if ([executables count])
	{
		//Scan the list of executables for installers
		detectedInstallers = [NSMutableArray arrayWithCapacity: 10];
		NSUInteger numWindowsExecutables = 0;
		
		for (NSString *executablePath in executables)
		{
			//Exclude windows-only programs, but note how many we've found
			if ([workspace isWindowsOnlyExecutableAtPath: executablePath])
			{
				numWindowsExecutables++;
				continue;
			}
			
			//If this was the designated installer for this game profile,
			//add it to the list automatically
			if (!preferredInstaller && [detectedProfile isDesignatedInstallerAtPath: executablePath])
			{
				[detectedInstallers addObject: executablePath];
				preferredInstaller = executablePath;
			}
			
			//Otherwise if it looks like an installer to us, add it to the list
			else if ([[self class] isInstallerAtPath: executablePath])
			{
				[detectedInstallers addObject: executablePath];
			}
		}
		
		if ([detectedInstallers count])
		{
			//Sort the installers by depth to determine the preferred one
			[detectedInstallers sortUsingSelector: @selector(pathDepthCompare:)];
			
			//If we didn't already find the game profile's own preferred installer, detect one from the list now
			if (!preferredInstaller)
			{
				preferredInstaller = [[self class] preferredInstallerFromPaths: detectedInstallers];
			}
		}
		
		//If no installers were found, check if this was a windows-only game
		else if (numWindowsExecutables == [executables count])
		{
			if (outError) *outError = [BXImportWindowsOnlyError errorWithSourcePath: path userInfo: nil];
			//Eject any volume that we mounted before we go
			if (mountedVolumePath) [workspace unmountAndEjectDeviceAtPath: mountedVolumePath];
			return NO;
		}
	}
	else
	{
		//No executables were found: this indicates that the folder was empty or contains something other than a DOS game
		if (outError) *outError = [BXImportNoExecutablesError errorWithSourcePath: path userInfo: nil];
		//Eject any volume we mounted before we go
		if (mountedVolumePath) [workspace unmountAndEjectDeviceAtPath: mountedVolumePath];
		return NO;
	}
	
	//If we got this far, then there were no errors and we have a fair idea what to do with this game
	[self setSourcePath: path];
	[self setGameProfile: detectedProfile];
	
	//FIXME: we have to set the preferred installer first because BXInstallerPanelController is listening
	//for when we set the installer paths, and relies on knowing the preferred installer in advance.
	//TODO: move the preferred installer detection off to BXInstallerPanelController instead, since it's
	//the only place that uses it?
	[self setPreferredInstallerPath: preferredInstaller];
	[self setInstallerPaths: detectedInstallers];
	
	return YES;
}


#pragma mark -
#pragma mark Window management

- (void) makeWindowControllers
{	
	[self setDOSWindowController:	[[BXImportDOSWindowController alloc] initWithWindowNibName: @"DOSWindow"]];
	[self setImportWindowController:[[BXImportWindowController alloc] initWithWindowNibName: @"ImportWindow"]];
	
	[self addWindowController: [self DOSWindowController]];
	[self addWindowController: [self importWindowController]];
	[[self DOSWindowController] setShouldCloseDocument: YES];
	[[self importWindowController] setShouldCloseDocument: YES];
	
	[[self DOSWindowController] release];
	[[self importWindowController] release];
}

- (void) removeWindowController: (NSWindowController *)windowController
{
	if (windowController == [self importWindowController])
	{
		[self setImportWindowController: nil];
	}
	[super removeWindowController: windowController];
}

- (void) showWindows
{
	if ([self importStage] == BXImportRunningInstaller)
	{
		[[self DOSWindowController] showWindow: self];
	}
	else
	{
		[[self importWindowController] showWindow: self];
	}
}

- (NSWindow *) windowForSheet
{
	NSWindow *dosWindow = (NSWindow *)[[self DOSWindowController] window];
	NSWindow *importWindow = [[self importWindowController] window];

	if		([dosWindow isVisible]) return dosWindow;
	else if	([importWindow isVisible]) return importWindow;
	else return nil;
}


#pragma mark -
#pragma mark Controlling shutdown

//We don't want to close the entire document after the emulated session is finished;
//instead we carry on and complete the installation process.
- (BOOL) closeOnEmulatorExit { return NO; }


#pragma mark -
#pragma mark Import helpers

+ (NSSet *)acceptedSourceTypes
{
	static NSSet *acceptedTypes = nil;
	if (!acceptedTypes)
	{
		//A subset of our usual mountable types: we only accept regular folders and disk image
		//formats which can be mounted by hdiutil (so that we can inspect their filesystems)
		acceptedTypes = [[NSSet alloc] initWithObjects:
						 @"public.folder",
						 @"public.iso-image",
						 @"com-apple.disk-image-cdr",
						 nil];
	}
	return acceptedTypes;
}

- (BOOL) canImportFromSourcePath: (NSString *)path
{
	return [[NSWorkspace sharedWorkspace] file: path
								  matchesTypes: [[self class] acceptedSourceTypes]];
}

- (BOOL) gameNeedsInstalling
{
	return [[self installerPaths] count] > 0;
}

#pragma mark -
#pragma mark Import steps

- (void) importFromSourcePath: (NSString *)path
{
	//Sanity checks: if these fail then there is a programming error.
	NSAssert(path != nil, @"Nil path passed to BXImport importFromSourcePath:");
	NSAssert([self importStage] <= BXImportWaitingForInstaller, @"Cannot call importFromSourcePath after game import has already started.");
	
	NSURL *sourceURL = [NSURL fileURLWithPath: [path stringByStandardizingPath]];
	
	NSError *readError = nil;

	[self setFileURL: sourceURL];

	[self setImportStage: BXImportLoadingSourcePath];
	BOOL readSucceeded = [self readFromURL: sourceURL
									ofType: nil
									 error: &readError];

	if (readSucceeded)
	{
		[self setFileURL: [NSURL fileURLWithPath: [self sourcePath]]];
		
		if ([self gameNeedsInstalling])
		{
			[self setImportStage: BXImportWaitingForInstaller];
		}
		else
		{
			[self skipInstaller];
		}
	}
	else if (readError)
	{
		[self setFileURL: nil];
		[self setImportStage: BXImportWaitingForSourcePath];
		
		//If we failed, then display the error as a sheet
		[self presentError: readError
			modalForWindow: [self windowForSheet]
		 		  delegate: nil
		didPresentSelector: NULL
			   contextInfo: NULL];
	}
}

- (void) cancelSourcePath
{
	//Sanity checks: if these fail then there is a programming error.
	NSAssert([self importStage] <= BXImportWaitingForInstaller, @"Cannot call cancelSourcePath after game import has already started.");
	
	[self setSourcePath: nil];
	[self setInstallerPaths: nil];
	[self setPreferredInstallerPath: nil];
	[self setFileURL: nil];
	
	[self setImportStage: BXImportWaitingForSourcePath];
}

- (void) launchInstaller: (NSString *)path
{
	//Sanity checks: if these fail then there is a programming error.
	NSAssert(path != nil, @"No targetPath specified when BXImport launchInstaller: was called.");
	NSAssert([self sourcePath] != nil, @"No sourcePath specified when BXImport launchInstaller: was called.");
	
	//If we don't yet have a game package (and we shouldn't), generate one now
	if (![self gamePackage])
	{
		[self _generateGameboxWithError: NULL];
	}
	
	[self setImportStage: BXImportRunningInstaller];
	
	[[self importWindowController] setShouldCloseDocument: NO];
	[[self DOSWindowController] setShouldCloseDocument: YES];
	[[self importWindowController] handOffToController: [self DOSWindowController]];
	
	//Set the installer as the target executable for this session
	[self setTargetPath: path];
	[self start];
}

- (void) skipInstaller
{
	[self setTargetPath: nil];
	[self setImportStage: BXImportReadyToFinalize];
	
	[self importSourceFiles];
}


- (void) finishInstaller
{
	//Stop the installer process, and hand control back to the import window
	[self cancel];
	
	[[self importWindowController] pickUpFromController: [self DOSWindowController]];
	
	[self setImportStage: BXImportReadyToFinalize];
	
	[self importSourceFiles];
}

- (void) importSourceFiles
{
	//Sanity checks: if these fail then there is a programming error.
	NSAssert([self importStage] == BXImportReadyToFinalize, @"BXImport importSourceFiles: was called before we are ready to finalize.");
	NSAssert([self sourcePath] != nil, @"No sourcePath specified when BXImport importSourceFiles: was called.");
	
	//If we don't have a source folder yet, generate one now before continuing
	if (![self gamePackage])
	{
		[self _generateGameboxWithError: NULL];
	}
	
	[self setImportStage: BXImportFinalizing];
	
	//TODO: import the game data here
	
	[self setImportStage: BXImportFinished];
}


- (IBAction) finishImporting: (id)sender
{
	[self finishInstaller];
}

#pragma mark -
#pragma mark Private internal methods

- (BOOL) _generateGameboxWithError: (NSError **)outError
{	
	NSAssert([self sourcePath] != nil, @"_generateGameboxWithError: called before source path was set.");
	
	NSString *gameName		= [[self gameProfile] gameName];
	if (!gameName) gameName	= [[self class] nameForGameAtPath: [self sourcePath]];
	
	NSString *gamesFolder	= [[NSApp delegate] gamesFolderPath];
	
	NSString *gameboxPath	= [[gamesFolder stringByAppendingPathComponent: gameName] stringByAppendingPathExtension: @"boxer"];
	
	BXPackage *gamebox = [[self class] createGameboxAtPath: gameboxPath error: outError];
	if (gamebox)
	{
		//Prep the gamebox further by creating an empty C drive in it
		NSString *cPath = [[gamebox resourcePath] stringByAppendingPathComponent: @"C.harddisk"];
		
		NSFileManager *manager = [NSFileManager defaultManager];
		BOOL success = [manager createDirectoryAtPath: cPath
						  withIntermediateDirectories: NO
										   attributes: nil
												error: outError];
		
		if (success)
		{
			[self setGamePackage: gamebox];
			[self setFileURL: [NSURL fileURLWithPath: [gamebox bundlePath]]];
			[self setRootDrivePath: cPath];
			return YES;
		}
		//If the C-drive creation failed for some reason, bail out and delete the new gamebox
		else
		{
			[manager removeItemAtPath: [gamebox bundlePath] error: NULL];
			return NO;
		}
	}
	else return NO;
}

- (BOOL) _gameDidInstall
{
	if (![self rootDrivePath]) return NO;
	
	//Check if any files were copied to the root drive
	NSFileManager *manager = [NSFileManager defaultManager];
	NSDirectoryEnumerator *enumerator = [manager enumeratorAtPath: [self rootDrivePath]];
	
	return ([enumerator nextObject] != nil);
}


//Delete our newly-minted gamebox if we didn't finish importing it before we were closed.
- (void) _cleanup
{
	[super _cleanup];
	
	if ([self importStage] != BXImportFinished)
	{
		NSFileManager *manager = [NSFileManager defaultManager];
		[manager removeItemAtPath: [[self gamePackage] bundlePath] error: NULL];	
	}
}


#pragma mark -
#pragma mark Responses to BXEmulator events

- (void) programWillStart: (NSNotification *)notification
{	
	//Don't set the active program if we already have one
	//This way, we keep track of when a user launches a batch file and don't immediately discard
	//it in favour of the next program the batch-file runs
	if (![self activeProgramPath])
	{
		[self setActiveProgramPath: [[notification userInfo] objectForKey: @"localPath"]];
		[DOSWindowController synchronizeWindowTitleWithDocumentName];
	
		//Always show the program panel when installing
		//(Show only after a delay, so that the installer time to start up)
		[[self DOSWindowController] performSelector: @selector(showProgramPanel:)
										 withObject: self
										 afterDelay: 1.0];
	}
}

- (void) didReturnToShell: (NSNotification *)notification
{
	//Clear the active program
	[self setActiveProgramPath: nil];
	[DOSWindowController synchronizeWindowTitleWithDocumentName];
	
	//Show the program chooser after returning to the DOS prompt
	//(Show only after a delay, so that the window has time to resize after quitting the game)
	[[self DOSWindowController] performSelector: @selector(showProgramPanel:)
													  withObject: self
													  afterDelay: 1.0];
	
	//Always drop out of fullscreen mode when we return to the prompt,
	//so that users can see the "finish importing" option
	[[self DOSWindowController] exitFullScreen: self];
}

@end