/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXImport.h"
#import "BXSessionPrivate.h"

#import "BXImportDOSWindowController.h"
#import "BXDOSWindowController+BXRenderController.h"
#import "BXImportWindowController.h"

#import "BXAppController+BXGamesFolder.h"
#import "BXGameProfile.h"
#import "BXImportError.h"
#import "BXPackage.h"
#import "BXDrive.h"
#import "BXEmulator.h"
#import "BXCloseAlert.h"

#import "BXDriveImport.h"

#import "BXImport+BXImportPolicies.h"
#import "BXSession+BXFileManager.h"

#import "NSWorkspace+BXFileTypes.h"
#import "NSWorkspace+BXMountedVolumes.h"
#import "NSWorkspace+BXExecutableTypes.h"
#import "NSString+BXPaths.h"

#import "BXPathEnumerator.h"


#pragma mark -
#pragma mark Private method declarations

@interface BXImport ()
@property (readwrite, retain, nonatomic) NSArray *installerPaths;
@property (readwrite, copy, nonatomic) NSString *sourcePath;
@property (readwrite, copy, nonatomic) NSString *preferredInstallerPath;

@property (readwrite, assign, nonatomic) BXImportStage importStage;
@property (readwrite, assign, nonatomic) BXOperationProgress stageProgress;
@property (readwrite, retain, nonatomic) BXFileTransfer *transferOperation;

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
@synthesize importStage, stageProgress, transferOperation;


#pragma mark -
#pragma mark Initialization and deallocation

- (void) dealloc
{
	[self setSourcePath: nil],				[sourcePath release];
	[self setRootDrivePath: nil],			[rootDrivePath release];
	[self setImportWindowController: nil],	[importWindowController release];
	[self setInstallerPaths: nil],			[installerPaths release];
	[self setPreferredInstallerPath: nil],	[preferredInstallerPath release];
	
	[self setTransferOperation: nil],		[transferOperation release];
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
	BOOL didMountVolume;		
	NSString *filePath = [[self class] preferredSourcePathForPath: [absoluteURL path]
												   didMountVolume: &didMountVolume
															error: outError];
	
	//Bail out if we could not determine a suitable source path
	//(in which case the error will have been populated)
	if (!filePath) return NO;
	
	//Now, autodetect the game from the source path
	BXGameProfile *detectedProfile = [BXGameProfile detectedProfileForPath: filePath searchSubfolders: YES];
	
	//Now, scan the source path for installers and installed-game telltales
	NSMutableArray *detectedInstallers = [NSMutableArray arrayWithCapacity: 10];
	NSString *preferredInstaller = nil;
	
	NSUInteger numExecutables = 0;
	NSUInteger numWindowsExecutables = 0;
	BOOL isAlreadyInstalledGame = NO;
	
	NSSet *executableTypes = [BXAppController executableTypes];
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	
	for (NSString *path in [BXPathEnumerator enumeratorAtPath: filePath])
	{
		//If we find an indication that this is an already-installed game, then we won't bother using any installers.
		//However, we'll still keep looking for executables: but only so that we can make sure the user really is
		//importing a proper DOS game (and not a Windows-only game.)
		if ([[self class] isPlayableGameTelltaleAtPath: path])
		{
			[detectedInstallers removeAllObjects];
			preferredInstaller = nil;
			isAlreadyInstalledGame = YES;
		}
		
		if ([workspace file: path matchesTypes: executableTypes])
		{
			numExecutables++;
			
			//Exclude windows-only programs, but note how many we've found
			if ([workspace isWindowsOnlyExecutableAtPath: path])
			{
				numWindowsExecutables++;
				continue;
			}
			
			//As described above, only bother recording installers if the game isn't already installed
			if (!isAlreadyInstalledGame)
			{
				//If this was the designated installer for this game profile, add it to the installer list
				if (!preferredInstaller && [detectedProfile isDesignatedInstallerAtPath: path])
				{
					[detectedInstallers addObject: path];
					preferredInstaller = path;
				}
				
				//Otherwise if it looks like an installer to us, add it to the installer list
				else if ([[self class] isInstallerAtPath: path])
				{
					[detectedInstallers addObject: path];
				}			
			}
		}
	}
	
	if (numExecutables)
	{
		if ([detectedInstallers count])
		{
			//Sort the installers by depth to determine the preferred one
			[detectedInstallers sortUsingSelector: @selector(pathDepthCompare:)];
			
			//If we didn't already find the game profile's own preferred installer,
			//detect one from the list now
			if (!preferredInstaller)
			{
				preferredInstaller = [[self class] preferredInstallerFromPaths: detectedInstallers];
			}
		}
		
		//If no installers were found, check if all executables were Windows-only:
		//if they were, bail out with a custom error message.
		else if (numWindowsExecutables == numExecutables)
		{
			if (outError) *outError = [BXImportWindowsOnlyError errorWithSourcePath: filePath userInfo: nil];
			//Eject any volume that we mounted before we go
			if (didMountVolume) [workspace unmountAndEjectDeviceAtPath: sourcePath];
			return NO;
		}		
	}
	
	//If no executables at all were found, this indicates that the folder was empty or contains something other than a DOS game; bail out with a custom error message.
	else
	{
		if (outError) *outError = [BXImportNoExecutablesError errorWithSourcePath: filePath userInfo: nil];
		//Eject any volume we mounted before we go
		if (didMountVolume) [workspace unmountAndEjectDeviceAtPath: sourcePath];
		return NO;
	}
	
	//If we got this far, then there were no errors and we have a fair idea what to do with this game
	[self setSourcePath: filePath];
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
- (BOOL) shouldCloseOnEmulatorExit { return NO; }

//We are considered to have unsaved changes if we have a not-yet-finalized gamebox
- (BOOL) isDocumentEdited	{ return [self gamePackage] != nil && [self importStage] < BXImportFinished; }

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
	
	//If we have a gamebox and haven't finished finalizing it, show a stop importing/cancel prompt
	if ([self isDocumentEdited])
	{
		BXCloseAlert *alert = [BXCloseAlert closeAlertWhileImportingGame: self];
		
		//Show our custom close alert, passing it the callback so we can complete
		//our response down in _closeAlertDidEnd:returnCode:contextInfo:
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
	
	BOOL shouldClose = NO;
	
	//If the alert has three buttons it means it's a save/don't save confirmation instead of
	//a close/cancel confirmation
	//TODO: for god's sake this is idiotic, we should detect this with contextinfo or alert class
	if ([[alert buttons] count] == 3)
	{
		//Cancel button
		switch (returnCode) {
			case NSAlertFirstButtonReturn:	//Finish importing
				[self finishInstaller];
				shouldClose = NO;
				break;
				
			case NSAlertSecondButtonReturn:	//Cancel
				shouldClose = NO;
				break;
				
			case NSAlertThirdButtonReturn:	//Stop importing
				shouldClose = YES;
				break;
		}
	}
	else
	{
		shouldClose = (returnCode == NSAlertFirstButtonReturn);
	}
	
	[callback setArgument: &shouldClose atIndex: 3];
	[callback invoke];
	
	//Release the previously-retained callback
	[callback release];	
}


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
	return ([[self installerPaths] count] > 0);
}


- (BOOL) isRunningInstaller
{
	NSArray *installers = [[self installerPaths] arrayByAddingObject: [self targetPath]];
	return [installers containsObject: [self activeProgramPath]];
}


//Overridden to reset the progress whenver we change the stage
- (void) setImportStage: (BXImportStage)stage
{
	if (stage != importStage)
	{
		importStage = stage;
		[self setStageProgress: 0.0f];		
	}
}

+ (NSSet *) keyPathsForValuesAffectingGameboxName	{ return [NSSet setWithObject: @"gamePackage"]; }

- (NSString *)gameboxName
{
	return [[self gamePackage] gameName]; 
}

- (void) setGameboxName: (NSString *)newName
{
	if ([self gamePackage] && [newName length] && ![newName isEqualToString: [self gameboxName]])
	{
		NSString *fullName = [newName lastPathComponent];
		if (![[[newName pathExtension] lowercaseString] isEqualToString: @"boxer"])
			fullName = [newName stringByAppendingPathExtension: @"boxer"];
		
		NSString *packagePath = [[self gamePackage] bundlePath];
		NSString *basePath = [packagePath stringByDeletingLastPathComponent];
		NSString *newPath = [basePath stringByAppendingPathComponent: fullName];
		
		NSFileManager *manager = [NSFileManager defaultManager];
		BOOL moved = [manager moveItemAtPath: packagePath toPath: newPath error: nil];
		if (moved)
		{
			BXPackage *movedPackage = [BXPackage bundleWithPath: newPath];
			[self setGamePackage: movedPackage];
			
			if ([[[self fileURL] path] isEqualToString: packagePath])
				[self setFileURL: [NSURL fileURLWithPath: [movedPackage bundlePath]]];
			
			//While we're at it, generate a new icon for the new gamebox name
			if (hasAutoGeneratedIcon) [self generateBootlegIcon];
		}
	}
}

//TODO: should we be handling this with NSFormatter validation instead?
- (BOOL) validateGameboxName: (id *)ioValue error: (NSError **)outError
{
	//Ensure the gamebox name only contains valid characters
	*ioValue = [[self class] validGameboxNameFromName: *ioValue];

	//If the string is now completely empty, treat it as an invalid filename
	if (![*ioValue length])
	{
		if (outError)
		{
			*outError = [NSError errorWithDomain: NSCocoaErrorDomain
											code: NSFileWriteInvalidFileNameError
										userInfo: nil];
		}
		return NO;
	}
	
	return YES;
}


- (void) setRepresentedIcon: (NSImage *)icon
{
	hasAutoGeneratedIcon = NO;
	[super setRepresentedIcon: icon];
}

- (void) generateBootlegIcon
{
	BXGameEra era = [[self gameProfile] gameEra];
	
	//If the game profile doesn't have an era, then autodetect it
	if (era == BXUnknownEra)
	{
		//We prefer the original source path for autodetection,
		//but fall back on the game package if the source path has been removed.
		if ([self sourcePath] && [[NSFileManager defaultManager] isReadableFileAtPath: [self sourcePath]])
			era = [BXGameProfile eraOfGameAtPath: [self sourcePath]];
		else if ([self gamePackage])
			era = [BXGameProfile eraOfGameAtPath: [[self gamePackage] bundlePath]];
		
		//Record the autodetected era so we don't have to scan the filesystem next time.
		[[self gameProfile] setGameEra: era];
	}
	
	NSImage *icon = [[self class] bootlegCoverArtForGamePackage: [self gamePackage] withEra: era];
	[[self gamePackage] setCoverArt: icon];
	hasAutoGeneratedIcon = YES;
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
	[self setStageProgress: BXOperationProgressIndeterminate];
	BOOL readSucceeded = [self readFromURL: sourceURL
									ofType: nil
									 error: &readError];
	
	if (readSucceeded)
	{
		[self setFileURL: [NSURL fileURLWithPath: [self sourcePath]]];
		
		if ([self gameNeedsInstalling])
		{
			//Bounce to notify the user that we need their input
			[NSApp requestUserAttention: NSInformationalRequest];
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

//FIXME: the lone IBAction called directly from the UI. Move this to BXProgramPanelController or something.
- (IBAction) finishImporting: (id)sender
{
	[self finishInstaller];
}

- (void) finishInstaller
{	
	//Stop the installer process, and hand control back to the import window
	[self cancel];
	
	//Close the program panel before handoff, otherwise it scales weirdly
	[[self DOSWindowController] setProgramPanelShown: NO];
	
	//Clear the DOS frame
	[[self DOSWindowController] updateWithFrame: nil];
	
	[[self importWindowController] pickUpFromController: [self DOSWindowController]];
	
	[self setImportStage: BXImportReadyToFinalize];
	
	[self importSourceFiles];
}

- (void) importSourceFiles
{
	//Sanity checks: if these fail then there is a programming error.
	NSAssert([self importStage] == BXImportReadyToFinalize, @"BXImport importSourceFiles: was called before we are ready to finalize.");
	NSAssert([self sourcePath] != nil, @"No sourcePath specified when BXImport importSourceFiles: was called.");
	
	NSFileManager *manager = [NSFileManager defaultManager];
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	
	
	[self setImportStage: BXImportCopyingSourceFiles];
	[self setStageProgress: BXOperationProgressIndeterminate];
	
	//If we don't have a source folder yet, generate one now before continuing
	//(This will happen if there were no installers, or the user skipped the installer)
	if (![self gamePackage])
	{
		[self _generateGameboxWithError: NULL];
	}
	
	//At this point, wait for any already-in-progress imports to finish
	[importQueue waitUntilAllOperationsAreFinished];
	
	
	//Determine how we should import the source files
	//-----------------------------------------------

	//If the source path no longer exists, it means the user probably ejected the disk and we can't import
	if (![manager fileExistsAtPath: [self sourcePath]])
	{
		//Skip straight to cleanup
		[self cleanGamebox];
		return;
	}
	
	//If there are already drives in the gamebox other than C, it means the user did their own importing
	//and we shouldn't interfere with their work
	NSSet *bundledTypes = [[BXAppController mountableFolderTypes] setByAddingObjectsFromSet: [BXAppController mountableImageTypes]];
	
	NSArray *alreadyBundledVolumes = [[self gamePackage] volumesOfTypes: bundledTypes];
	if ([alreadyBundledVolumes count] > 1)
	{
		//Skip straight to cleanup
		[self cleanGamebox];
		return;
	}
	
	
	NSString *volumePath = [workspace volumeForPath: [self sourcePath]];
	NSString *volumeType = [workspace volumeTypeForPath: volumePath];
	
	BOOL isRealCDROM = [volumeType isEqualToString: dataCDVolumeType];
	BOOL isRealFloppy = !isRealCDROM && [volumeType isEqualToString: FATVolumeType] && [workspace isFloppySizedVolumeAtPath: volumePath];
	
	//If the installer copied files to our C drive, or the source files are on an actual CDROM/floppy,
	//then import the source files as a fake CD-ROM/floppy drive
	if (isRealCDROM || isRealFloppy || [self _gameDidInstall])
	{
		BXDrive *importDrive = nil;
		
		//If the source is an actual floppy disk, or this game needs to be installed off floppies,
		//then import the source files as a floppy disk
		if (isRealFloppy || [[self gameProfile] installMedium] == BXDriveFloppyDisk)
		{
			importDrive = [BXDrive floppyDriveFromPath: [self sourcePath] atLetter: @"A"];
		}
		//Otherwise, import the source files as a CD-ROM drive
		else
		{
			importDrive = [BXDrive CDROMFromPath: [self sourcePath] atLetter: @"D"];
		}
		
		[self setTransferOperation: [self beginImportForDrive: importDrive]];
	}
	
	//Otherwise, assume that the source files were the already-installed game:
	//copy the source files themselves to drive C
	else
	{
		//We need to copy the source path into a subfolder of drive C: do this as a regular file copy
		if ([[self class] shouldUseSubfolderForSourceFilesAtPath: [self sourcePath]])
		{
			NSString *subfolderName	= [[self sourcePath] lastPathComponent];
			NSString *destination	= [[self rootDrivePath] stringByAppendingPathComponent: subfolderName];
			
			BXFileTransfer *transfer = [BXFileTransfer transferFromPath: [self sourcePath] toPath: destination copyFiles: YES];
			[transfer setDelegate: self];
			[self setTransferOperation: transfer];
			[importQueue addOperation: transfer];
		}
		//Otherwise, replace the old drive C completely by importing the source path
		//(This is easier than constructing a file transfer operation for every individual file)
		else
		{
			[manager removeItemAtPath: [self rootDrivePath] error: nil];
			BXDrive *importDrive = [BXDrive hardDriveFromPath: [self sourcePath] atLetter: @"C"];
			[self setTransferOperation: [self beginImportForDrive: importDrive]];
		}
	}
}

- (void) cleanGamebox
{
	[self setImportStage: BXImportCleaningGamebox];
	[self setStageProgress: BXOperationProgressIndeterminate];
	
	NSString *packagePath = [[self gamePackage] bundlePath];
	NSFileManager *manager = [NSFileManager defaultManager];
	BXPathEnumerator *enumerator = [BXPathEnumerator enumeratorAtPath: packagePath];
	[enumerator setSkipHiddenFiles: NO];
	
	for (NSString *path in enumerator)
	{
		if ([[self class] isJunkFileAtPath: path]) [manager removeItemAtPath: path error: nil];
	}
	
	//Clear our file URL, so that we don't appear as representing this gamebox when the user tries to open it
	[self setFileURL: nil];
	
	//That's all folks!
	[self setImportStage: BXImportFinished];
	
	//Bounce to notify the user that we're done
	[NSApp requestUserAttention: NSInformationalRequest];
}


#pragma mark BXOperation delegate methods

- (void) operationInProgress: (NSNotification *)notification
{
	BXOperation *operation = [notification object];
	if ([self importStage] == BXImportCopyingSourceFiles && operation == [self transferOperation])
	{
		//Update our progress to match the operation's progress
		
		[self setStageProgress: [operation currentProgress]];
	}
	else return [super operationInProgress: notification];
}

- (void) operationDidFinish: (NSNotification *)notification
{
	BXOperation *operation = [notification object];
	if ([self importStage] == BXImportCopyingSourceFiles && operation == [self transferOperation])
	{
		//Yay! We finished copying files
		[self setTransferOperation: nil];
		[self cleanGamebox];
	}
	else return [super operationDidFinish: notification];
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


#pragma mark -
#pragma mark Private internal methods

- (void) _startEmulator
{
	[super _startEmulator];
	
	//Once the emulation session finishes, continue importing (if we're not doing so already)
	//Also hide the Inspector panel if it was open
	if (![emulator isCancelled] && [self importStage] == BXImportRunningInstaller)
	{
		[[NSApp delegate] setInspectorPanelShown: NO];
		[self finishInstaller];
	}
}

//This uses a different (and simpler) mount behaviour than BXSession to prioritise the
//source path ahead of other drives.
- (void) _mountDrivesForSession
{
	//Mount our new empty gamebox as drive C
	BXDrive *destinationDrive = [BXDrive hardDriveFromPath: [self rootDrivePath] atLetter: @"C"];
	[self mountDrive: destinationDrive];
	
	//Determine what type of media this game expects to be installed from
	//(This will be BXDriveAutodetect if it doesn't care)
	BXDriveType installMedium = [[self gameProfile] installMedium];
	
	//Then, create a drive of the appropriate type from the source files and mount away
	BXDrive *sourceDrive = [BXDrive driveFromPath: [self sourcePath] atLetter: nil withType: installMedium];
	[self mountDrive: sourceDrive];
	
	//Automount all currently mounted floppy and CD-ROM volumes
	[self mountFloppyVolumes];
	[self mountCDVolumes];
	
	//Mount our internal DOS toolkit and temporary drives
	[self mountToolkitDrive];
	[self mountTempDrive];
}

- (BOOL) _generateGameboxWithError: (NSError **)outError
{	
	NSAssert([self sourcePath] != nil, @"_generateGameboxWithError: called before source path was set.");

	NSFileManager *manager = [NSFileManager defaultManager];

	NSString *gameName		= [[self gameProfile] gameName];
	if (!gameName) gameName	= [[self class] nameForGameAtPath: [self sourcePath]];
	
	NSString *gamesFolder	= [[NSApp delegate] gamesFolderPath];
	//If the games folder is missing or not set, then fall back on a path we know does exist (the Desktop)
	if (!gamesFolder || ![manager fileExistsAtPath: gamesFolder]) gamesFolder = [[NSApp delegate] fallbackGamesFolderPath];
	
	NSString *gameboxPath	= [[gamesFolder stringByAppendingPathComponent: gameName] stringByAppendingPathExtension: @"boxer"];
	
	BXPackage *gamebox = [[self class] createGameboxAtPath: gameboxPath error: outError];
	if (gamebox)
	{
		//Try to find a suitable cover-art icon from the source path
		NSImage *icon = [[self class] boxArtForGameAtPath: [self sourcePath]];
		if (icon) [gamebox setCoverArt: icon];
		
		//Prep the gamebox further by creating an empty C drive in it
		NSString *cPath = [[gamebox resourcePath] stringByAppendingPathComponent: @"C.harddisk"];
		
		BOOL success = [manager createDirectoryAtPath: cPath
						  withIntermediateDirectories: NO
										   attributes: nil
												error: outError];
		
		if (success)
		{
			[self setGamePackage: gamebox];
			[self setFileURL: [NSURL fileURLWithPath: [gamebox bundlePath]]];
			[self setRootDrivePath: cPath];
			if (!icon) [self generateBootlegIcon];
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
	BXPathEnumerator *enumerator = [BXPathEnumerator enumeratorAtPath: [self rootDrivePath]];
	while ([enumerator nextObject])
	{
		NSDictionary *attrs = [enumerator fileAttributes];
		//If any actual files were created, then assume the game installed
		//IMPLEMENTATION NOTE: We'd like to be more rigorous and check for
		//executables, but some CD-ROM games only store configuration files
		//on the hard drive
		if ([[attrs fileType] isEqualToString: NSFileTypeRegular]) return YES;
	}
	return NO;
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

@end