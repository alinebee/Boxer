/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//IMPLEMENTATION NOTE: this class is currently a conceptual mess, and needs serious restructuring:
//- The UI is responsible for ensuring that the import workflow is handled correctly and that
//  steps are performed in the correct order. Instead of saying "OK, continue with the next
//  logical step of the operation", the UI says "OK, now run this specific step." Bad.
//- The import process cannot currently be done unattended as it relies on UI confirmation.
//  This prevents it being easily scriptable.
//- Despite being an NSDocument subclass, BXImport instances cannot be loaded from an existing URL:
//  they have to go through the importFromSourcePath: mechanism.
//- The import process relies on BXOperations but overloads the standard operationDidFinish notification
//  handler with switching functionality, instead of providing custom callbacks for different types
//  of operation. This makes the callback code messy and prone to bugs.


#import "BXImport.h"
#import "BXSessionPrivate.h"

#import "BXImportDOSWindowController.h"
#import "BXDOSWindowController.h"
#import "BXImportWindowController.h"

#import "BXAppController+BXGamesFolder.h"
#import "BXInspectorController.h"
#import "BXGameProfile.h"
#import "BXImportError.h"
#import "BXPackage.h"
#import "BXDrive.h"
#import "BXEmulator.h"
#import "BXCloseAlert.h"

#import "BXSingleFileTransfer.h"
#import "BXSimpleDriveImport.h"

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
@property (readwrite, assign, nonatomic) BOOL stageProgressIndeterminate;
@property (readwrite, retain, nonatomic) BXOperation *transferOperation;

//Only defined for internal use
@property (copy, nonatomic) NSString *rootDrivePath;


//Create a new empty game package for our source path.
- (BOOL) _generateGameboxWithError: (NSError **)error;

//Return the path to which the current gamebox will be moved if renamed with the specified name.
- (NSString *) _destinationPathForGameboxName: (NSString *)newName;

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
@synthesize importStage, stageProgress, stageProgressIndeterminate, transferOperation;


#pragma mark -
#pragma mark Initialization and deallocation

- (void) dealloc
{
	[self setImportWindowController: nil],	[importWindowController release];
	[self setSourcePath: nil],				[sourcePath release];
	[self setRootDrivePath: nil],			[rootDrivePath release];
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
	didMountSourceVolume = NO;
	
	NSString *filePath = [[self class] preferredSourcePathForPath: [absoluteURL path]
												   didMountVolume: &didMountSourceVolume
															error: outError];
	
	//Bail out if we could not determine a suitable source path
	//(in which case the error will have been populated)
	if (!filePath) return NO;
	
	//Now, autodetect the game from the source path
	BXGameProfile *detectedProfile = [BXGameProfile detectedProfileForPath: filePath searchSubfolders: YES];
	
	//Now, scan the source path for installers and installed-game telltales
	NSMutableArray *installers = [NSMutableArray arrayWithCapacity: 10];
	NSString *preferredInstaller = nil;
	
	NSUInteger numExecutables = 0;
	NSUInteger numWindowsExecutables = 0;
	BOOL isAlreadyInstalledGame = NO;
	
	NSSet *executableTypes = [BXAppController executableTypes];
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	
	BXPathEnumerator *enumerator = [BXPathEnumerator enumeratorAtPath: filePath];
	
	//TODO: move this installer detection work off to an NSOperation,
	//so that we don't block the UI while scanning
	for (NSString *path in enumerator)
	{
		BOOL isWindowsExecutable = NO;
		
		//Grab the relative path to use for heuristic filename-pattern checks,
		//so that the base path doesn't get involved in the heuristic.
		NSString *relativePath = [enumerator relativePath];
	
		//Skip the file altogether if we know it's irrelevant (see [BXImportPolicies +ignoredFilePatterns])
		if ([[self class] isIgnoredFileAtPath: relativePath]) continue;
		
		//If we find an indication that this is an already-installed game, then we won't bother using any installers.
		//However, we'll still keep looking for executables: but only so that we can make sure the user really is
		//importing a proper DOS game and not a Windows-only game.
		if ([[self class] isPlayableGameTelltaleAtPath: relativePath])
		{
			[installers removeAllObjects];
			preferredInstaller = nil;
			isAlreadyInstalledGame = YES;
		}
		
		if ([workspace file: path matchesTypes: executableTypes])
		{
			numExecutables++;
			
			//Exclude windows-only programs, but note how many we've found
			if (![workspace isCompatibleExecutableAtPath: path])
			{
				isWindowsExecutable = YES;
				numWindowsExecutables++;
			}
			
			//As described above, only bother recording installers if the game isn't already installed
			//Also ignore non-DOS executables, even if they look like installers
			if (!isWindowsExecutable && !isAlreadyInstalledGame)
			{
				//If this was the designated installer for this game profile, add it to the installer list
				if (!preferredInstaller && [detectedProfile isDesignatedInstallerAtPath: relativePath])
				{
					[installers addObject: path];
					preferredInstaller = path;
				}
				
				//Otherwise if it looks like an installer to us, add it to the installer list
				else if ([[self class] isInstallerAtPath: relativePath])
				{
					[installers addObject: path];
				}
			}
		}
	}
	
	BOOL succeeded = YES;
	
	if (!numExecutables)
	{
		//If no executables at all were found, this indicates that the folder was empty
		//or contains something other than a DOS game; bail out with an appropriate error.
		
		succeeded = NO;
		if (outError) *outError = [BXImportNoExecutablesError errorWithSourcePath: filePath userInfo: nil];
		
	}
	
	else if (numWindowsExecutables == numExecutables)
	{
		succeeded = NO;
		if (outError) *outError = [BXImportWindowsOnlyError errorWithSourcePath: filePath userInfo: nil];
	}
	
	if (succeeded)
	{
		if ([installers count])
		{
			//Sort the installers by depth to present them and to determine a preferred one
			[installers sortUsingSelector: @selector(pathDepthCompare:)];
			
			//If we didn't already find the game profile's own preferred installer,
			//detect one from the list now
			if (!preferredInstaller)
			{
				preferredInstaller = [[self class] preferredInstallerFromPaths: installers];
			}
		}
		//Otherwise, the source path contains DOS executables but no installers,
		//and we'll import it directly.
		
		
		//If we got this far, then there were no errors and we have a fair idea what to do with this game
		[self setSourcePath: filePath];
		[self setGameProfile: detectedProfile];
		
		//FIXME: we have to set the preferred installer first because BXImportWindowController is listening
		//for when we set the installer paths, and relies on knowing the preferred installer in advance.
		[self setPreferredInstallerPath: preferredInstaller];
		[self setInstallerPaths: installers];		
		
		return YES;
	}
	else
	{
		//Eject any volume we mounted before we go
		if (didMountSourceVolume)
		{
			[workspace unmountAndEjectDeviceAtPath: filePath];
			didMountSourceVolume = NO;
		}
		return NO;
	}
}


#pragma mark -
#pragma mark Window management

- (void) makeWindowControllers
{	
	BXImportDOSWindowController *DOSController	= [[BXImportDOSWindowController alloc] initWithWindowNibName: @"DOSWindow"];
	BXImportWindowController *importController	= [[BXImportWindowController alloc] initWithWindowNibName: @"ImportWindow"];
	
	[self addWindowController: DOSController];
	[self addWindowController: importController];
	
	[self setDOSWindowController: DOSController];
	[self setImportWindowController: importController];
	
	[DOSController setShouldCloseDocument: YES];
	[importController setShouldCloseDocument: YES];
	
	[DOSController release];
	[importController release];
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
	NSWindow *importWindow = [[self importWindowController] window];

	if	([importWindow isVisible]) return importWindow;
	else return [super windowForSheet];
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
						 @"com.apple.disk-image-cdr",
						 @"com.winimage.raw-disk-image",
						 nil];
	}
	return acceptedTypes;
}

+ (BOOL) canImportFromSourcePath: (NSString *)path
{
	return [[NSWorkspace sharedWorkspace] file: path
								  matchesTypes: [self acceptedSourceTypes]];
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


//Overridden to reset the progress whenever we change the stage
- (void) setImportStage: (BXImportStage)stage
{
	if (stage != importStage)
	{
		importStage = stage;
		[self setStageProgress: 0.0f];
		[self setStageProgressIndeterminate: YES];
	}
}


#pragma mark -
#pragma mark Gamebox renaming

- (NSString *) _destinationPathForGameboxName: (NSString *)newName
{
	NSString *fullName = [newName lastPathComponent];
	if (![[[newName pathExtension] lowercaseString] isEqualToString: @"boxer"])
		fullName = [newName stringByAppendingPathExtension: @"boxer"];
	
	NSString *currentPath = [[self gamePackage] bundlePath];
	NSString *basePath = [currentPath stringByDeletingLastPathComponent];
	NSString *newPath = [basePath stringByAppendingPathComponent: fullName];
	return newPath;
}

+ (NSSet *) keyPathsForValuesAffectingGameboxName	{ return [NSSet setWithObject: @"gamePackage"]; }

- (NSString *) gameboxName
{
	return [[self gamePackage] gameName]; 
}

- (void) setGameboxName: (NSString *)newName
{
	NSString *originalName = [self gameboxName];
	if ([self gamePackage] && [newName length] && ![newName isEqualToString: originalName])
	{
		NSString *newPath = [self _destinationPathForGameboxName: newName];
		NSString *currentPath = [[self gamePackage] bundlePath];
		
		NSFileManager *manager = [NSFileManager defaultManager];
		
		NSError *moveError;
		BOOL moved;
		
		//Special case: if the user is just changing the case of the filename, then a regular
		//move operation may cause a file-already-exists error on case-insensitive filesystems.
		//So we first rename the file to a temporary name, then back to the final name.
		if ([[newName lowercaseString] isEqualToString: [originalName lowercaseString]])
		{
			NSString *tempPath = [currentPath stringByAppendingPathExtension: @"-renaming"];
			
			moved = [manager moveItemAtPath: currentPath toPath: tempPath error: &moveError];
			if (moved)
			{
				moved = [manager moveItemAtPath: tempPath toPath: newPath error: &moveError];
				//If the second step of the rename failed, then put the file back to its original name
				if (!moved) [manager moveItemAtPath: tempPath toPath: currentPath error: nil];
			}
		}
		else
		{
			moved = [manager moveItemAtPath: currentPath toPath: newPath error: &moveError];
		}
		
		if (moved)
		{
			BXPackage *movedPackage = [BXPackage bundleWithPath: newPath];
			[self setGamePackage: movedPackage];
			
			if ([[[self fileURL] path] isEqualToString: currentPath])
				[self setFileURL: [NSURL fileURLWithPath: [movedPackage bundlePath]]];
			
			//While we're at it, generate a new icon for the new gamebox name
			if (hasAutoGeneratedIcon) [self generateBootlegIcon];
		}
		else
		{
			[self presentError: moveError
				modalForWindow: [self windowForSheet]
					  delegate: nil
			didPresentSelector: nil
				   contextInfo: NULL];
		}
	}
}

//TODO: should we be handling this with NSFormatter validation instead?
- (BOOL) validateGameboxName: (id *)ioValue error: (NSError **)outError
{
	//Ensure the gamebox name only contains valid characters
	NSString *sanitisedName = [[self class] validGameboxNameFromName: *ioValue];

	//If the string is now completely empty, treat it as an invalid filename
	if (![sanitisedName length])
	{
		if (outError)
		{
			*outError = [NSError errorWithDomain: NSCocoaErrorDomain
											code: NSFileWriteInvalidFileNameError
										userInfo: nil];
		}
		return NO;
	}
	
	//Check if a different gamebox already exists with the specified name at the intended destination
	//(Lowercase comparison avoids an error if the user is just changing the case of the original name)
	if (![[sanitisedName lowercaseString] isEqualToString: [[self gameboxName] lowercaseString]])
	{
		NSString *intendedPath = [self _destinationPathForGameboxName: sanitisedName];
		
		NSFileManager *manager = [NSFileManager defaultManager];
		if ([manager fileExistsAtPath: intendedPath])
		{
			if (outError)
			{
				//Customise the error message to match Finder's behaviour
				NSString *messageFormat = NSLocalizedString(@"The name “%1$@” is already taken. Please choose another.",
															@"Error shown when user renames a gamebox to a name that already exists. %1$@ is the intended filename.");
				
				NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
										  [NSString stringWithFormat: messageFormat, sanitisedName, nil], NSLocalizedDescriptionKey,
										  intendedPath, NSFilePathErrorKey,
										  nil];
				
				*outError = [NSError errorWithDomain: NSCocoaErrorDomain
												code: NSFileWriteInvalidFileNameError
											userInfo: userInfo];
			}
			return NO;
		}
	}
	
	//If the new sanitised name checked out, use that as the value and keep on going.
	*ioValue = sanitisedName;
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

	if (didMountSourceVolume)
	{
		NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
		[workspace unmountAndEjectDeviceAtPath: [self sourcePath]];
		didMountSourceVolume = NO;
	}
	
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
	
	//Close the inspector panel also
	[[BXInspectorController controller] setPanelShown: NO];
	
	//Clear the DOS frame
	[[self DOSWindowController] updateWithFrame: nil];
	
	[self setImportStage: BXImportReadyToFinalize];
	
	[[self importWindowController] pickUpFromController: [self DOSWindowController]];
	
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
	[self setStageProgressIndeterminate: YES];
	
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
	//FIXME: make this properly handle the case where the sourcepath is a mounted volume for a disc image
	if (![manager fileExistsAtPath: [self sourcePath]])
	{
		//Skip straight to cleanup
		[self cleanGamebox];
		return;
	}
	
	//If there are already drives in the gamebox other than C, it means the user did their own importing
	//and we shouldn't interfere with their work
	NSSet *bundleableTypes = [[BXAppController mountableFolderTypes] setByAddingObjectsFromSet: [BXAppController mountableImageTypes]];
	
	NSArray *alreadyBundledVolumes = [[self gamePackage] volumesOfTypes: bundleableTypes];
	if ([alreadyBundledVolumes count] > 1)
	{
		//Skip straight to cleanup
		[self cleanGamebox];
		return;
	}
	
	
	//At this point, all the edge cases are out of the way and we know we'll need to import something.
	
	BXDrive *importDrive = nil;
	BXOperation *importOperation = nil;
	
	//If the source path is directly bundleable (it is an image or a mountable folder)
	//then import it into the new gamebox as-is
	if ([workspace file: [self sourcePath] matchesTypes: bundleableTypes])
	{
		//If this file is a mountable type, move it into the gamebox's root folder where we can find it 
		importDrive = [BXDrive driveFromPath: [self sourcePath] atLetter: nil];
		
		//If this drive is marked as being for drive C, then check what we need to do with our original C drive
		if ([[importDrive letter] isEqualToString: @"C"])
		{	
			//if any files were installed to the original C drive, then reset the import drive letter
			//so that the drive imports alongside the existing C drive.
			if ([self _gameDidInstall])
			{
				[importDrive setLetter: nil];
			}
			//Otherwise, delete the original empty C drive so we can replace it with this one
			else
			{
				[manager removeItemAtPath: [self rootDrivePath] error: nil];
			}
		}
		importOperation = [self importForDrive: importDrive startImmediately: NO];
	}
	
	else
	{
		//Otherwise, check if the source path is a real floppy disk/CD-ROM,
		//and thus will always need to be imported as-is
		
		NSString *volumePath = [workspace volumeForPath: [self sourcePath]];
		NSString *volumeType = [workspace volumeTypeForPath: volumePath];
		
		BOOL isRealCDROM = [volumeType isEqualToString: dataCDVolumeType];
		BOOL isRealFloppy = !isRealCDROM && [volumeType isEqualToString: FATVolumeType] && [workspace isFloppySizedVolumeAtPath: volumePath];
		
		//If the installer copied files to our C drive, or the source files are on an actual CDROM/floppy,
		//then import the source files as a fake CD-ROM/floppy drive
		if (isRealCDROM || isRealFloppy || [self _gameDidInstall])
		{
			//If the source path is on a disk image, then import the image instead
			NSString *importPath = [self sourcePath];
			NSString *sourceImagePath = [workspace sourceImageForVolume: [self sourcePath]];
			
			if (sourceImagePath && [workspace file: sourceImagePath matchesTypes: [BXAppController mountableImageTypes]])
				importPath = sourceImagePath;
			
			//If the source is an actual floppy disk, or this game needs to be installed off floppies,
			//then import the source files as a floppy disk
			if (isRealFloppy || [[self gameProfile] installMedium] == BXDriveFloppyDisk)
			{
				importDrive = [BXDrive floppyDriveFromPath: importPath atLetter: @"A"];
			}
			//Otherwise, import the source files as a CD-ROM drive
			else
			{
				importDrive = [BXDrive CDROMFromPath: importPath atLetter: @"D"];
			}
			
			importOperation = [self importForDrive: importDrive startImmediately: NO];
		}
		
		//Otherwise, assume that the source files are an already-installed game:
		//copy the source files themselves directly into the gamebox
		
		//We need to copy the source path into a subfolder of drive C: do this as a regular file copy
		else if ([[self class] shouldUseSubfolderForSourceFilesAtPath: [self sourcePath]])
		{
			NSString *subfolderName	= [[self sourcePath] lastPathComponent];
			//Ensure the destination name will be DOSBox-compatible
			NSString *safeName = [[self class] validDOSNameFromName: subfolderName];
			
			NSString *destination = [[self rootDrivePath] stringByAppendingPathComponent: safeName];
			
			importOperation = [BXSingleFileTransfer transferFromPath: [self sourcePath]
															  toPath: destination
														   copyFiles: YES];
			
			[importOperation setDelegate: self];
		}
		
		//Otherwise, replace the old drive C with the source path by importing it as a new drive
		else
		{
			[manager removeItemAtPath: [self rootDrivePath] error: nil];
			importDrive = [BXDrive hardDriveFromPath: [self sourcePath] atLetter: @"C"];
			
			importOperation = [self importForDrive: importDrive startImmediately: NO];
		}
	}
	
	//Set up the import operation and start it running
	[self setTransferOperation: importOperation];
	[importQueue addOperation: importOperation];
}

- (void) cleanGamebox
{	
	[self setImportStage: BXImportCleaningGamebox];

	NSSet *bundleableTypes = [[BXAppController mountableFolderTypes] setByAddingObjectsFromSet: [BXAppController mountableImageTypes]];
	//Special case to catch GOG's standalone .GOG images (which are just renamed ISOs)
	NSSet *gogImageTypes = [NSSet setWithObject:@"com.gog.gog-disk-image"];
	
	NSFileManager *manager	= [NSFileManager defaultManager];
	NSWorkspace *workspace	= [NSWorkspace sharedWorkspace];
	
	NSString *pathToClean	= [self rootDrivePath];
	NSString *pathForDrives	= [[self gamePackage] resourcePath];
	
	BXPathEnumerator *enumerator = [BXPathEnumerator enumeratorAtPath: pathToClean];
	[enumerator setSkipHiddenFiles: NO];
	
	for (NSString *path in enumerator)
	{
		//Grab the relative path to use for heuristic filename-pattern checks,
		//so that the base folder doesn't get involved in the heuristic.
		NSString *relativePath = [enumerator relativePath];
		if ([[self class] isJunkFileAtPath: relativePath])
		{
			[manager removeItemAtPath: path error: nil];
			continue;
		}
		
		BOOL isBundleable = [workspace file: path matchesTypes: bundleableTypes];
		BOOL isGOGImage = !isBundleable && [workspace file: path matchesTypes: gogImageTypes];
		
		//If this file is a mountable type, move it into the gamebox's root folder where we can find it
		if (isBundleable || isGOGImage)
		{
			//Rename standalone .GOG images to .ISO when importing, to make everyone's lives that little bit more obvious.
			if (isGOGImage)
			{
				NSString *basePath = [path stringByDeletingPathExtension];
				NSArray *cuePaths = [NSArray arrayWithObjects: 
									 [basePath stringByAppendingPathExtension: @"inst"],
									 [basePath stringByAppendingPathExtension: @"INST"],
									 nil];
				NSString *newPath = [basePath stringByAppendingPathExtension: @"iso"];
				
				//Check that this really is a standalone .GOG file: if it's paired with a matching .INST,
				//then we will import that later instead (and that will bring the .GOG along for the ride anyway.)
				BOOL hasCue = NO;
				for (NSString *cuePath in cuePaths) if ([manager fileExistsAtPath: cuePath])
				{
					hasCue = YES;
					break;
				}
				
				//If it's standalone, and we rename it successfully, then continue importing it from the new name
				if (!hasCue && [manager moveItemAtPath: path toPath: newPath error: nil]) path = newPath;
				//Otherwise, skip the file and get on with the next one
				else continue;
			}
				 
			BXDrive *drive = [BXDrive driveFromPath: path atLetter: nil];
			
			BXOperation <BXDriveImport> *importOperation = [BXDriveImport importForDrive: drive
																		   toDestination: pathForDrives
																			   copyFiles: NO];
			
			[importQueue addOperation: importOperation];
		}
	}
	
	//Any import operations we do in this stage would be moves within the same volume,
	//so they should be done already, but let's wait anyway.
	[importQueue waitUntilAllOperationsAreFinished];
	
	//That's all folks!
	[self setImportStage: BXImportFinished];
	
	//Add to the recent documents list
	[[NSDocumentController sharedDocumentController] noteNewRecentDocument: self];
	
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
		[self setStageProgressIndeterminate: [operation isIndeterminate]];
	}
	else return [super operationInProgress: notification];
}

- (void) operationDidFinish: (NSNotification *)notification
{
	BXOperation *operation = [notification object];
	if ([self importStage] == BXImportCopyingSourceFiles &&
		operation == [self transferOperation])
	{
		//Yay! We finished copying files (or failed copying files but want to get done with this anyway)
		//TODO: add proper error checking and display, as a failure during drive import will probably
		//mean an unusable gamebox.
		[self setTransferOperation: nil];
		
		//If the imported drive is replacing our original C drive, then update the root drive path accordingly
		//(This is used immediately after in cleanGamebox)
		if ([operation conformsToProtocol: @protocol(BXDriveImport)] &&
			[[[(id)operation drive] letter] isEqualToString: @"C"])
		{
			[self setRootDrivePath: [(id)operation importedDrivePath]];
		}
		
		[self cleanGamebox];
	}
	//Only perform the regular post-import behaviour (drive-swapping, notifications etc.)
	//if we're actually in a DOS session
	else if ([self importStage] == BXImportRunningInstaller)
	{
		return [super operationDidFinish: notification];
	}
}


#pragma mark -
#pragma mark Responses to BXEmulator events

- (void) emulatorWillStartProgram: (NSNotification *)notification
{	
	//Don't set the active program if we already have one
	//This way, we keep track of when a user launches a batch file and don't immediately discard
	//it in favour of the next program the batch-file runs
	if (![self activeProgramPath])
	{
		[self setActiveProgramPath: [[notification userInfo] objectForKey: @"localPath"]];
		[DOSWindowController synchronizeWindowTitleWithDocumentName];
	
		//Always show the program panel when installing
		//(Show only after a delay, so that the installer has time to start up)
		[[self DOSWindowController] performSelector: @selector(showProgramPanel)
										 withObject: nil
										 afterDelay: 1.0];
	}
}

- (void) emulatorDidReturnToShell: (NSNotification *)notification
{
	//Clear the active program
	[self setActiveProgramPath: nil];
	[DOSWindowController synchronizeWindowTitleWithDocumentName];
	
	//Show the program chooser after returning to the DOS prompt
	//(Show only after a delay, so that the window has time to resize after quitting the game)
	[[self DOSWindowController] performSelector: @selector(showProgramPanel)
									 withObject: nil
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
		[self finishInstaller];
	}
}

- (BOOL) _shouldAutoPause
{
	//Don't auto-pause the emulation while importing, even if the preference is on:
	//this allows lengthy copy operations to continue in the background.
	return NO;
}

//This uses a different (and simpler) mount behaviour than BXSession to prioritise the
//source path ahead of other drives.
- (void) _mountDrivesForSession
{
	//Determine what type of media this game expects to be installed from,
	//and how much free space to allow for it
	BXDriveType installMedium = BXDriveAutodetect;
	if ([self gameProfile])
		installMedium = [[self gameProfile] installMedium];
	
	if (installMedium == BXDriveAutodetect)
		installMedium = [BXDrive preferredTypeForPath: [self sourcePath]];
	
	NSInteger freeSpace = BXDefaultFreeSpace;
	
	if ([self gameProfile])
		freeSpace = [[self gameProfile] requiredDiskSpace];
	
	if (freeSpace == BXDefaultFreeSpace && (installMedium == BXDriveCDROM || [[self class] isCDROMSizedGameAtPath: [self sourcePath]]))
		freeSpace = BXFreeSpaceForCDROMInstall;
	
	
	//Mount our new empty gamebox as drive C
	BXDrive *destinationDrive = [BXDrive hardDriveFromPath: [self rootDrivePath] atLetter: @"C"];
	[destinationDrive setFreeSpace: freeSpace];
	[self mountDrive: destinationDrive];
	
	//Then, create a drive of the appropriate type from the source files and mount away
	BXDrive *sourceDrive = [BXDrive driveFromPath: [self sourcePath] atLetter: nil withType: installMedium];
	[self mountDrive: sourceDrive];
	
	//Automount all currently mounted floppy and CD-ROM volumes
	[self mountFloppyVolumes];
	[self mountCDVolumes];
	
	//Mount our internal DOS toolkit and temporary drives unless the profile says otherwise
	if (![self gameProfile] || [[self gameProfile] mountHelperDrivesDuringImport])
	{
		[self mountToolkitDrive];
		[self mountTempDrive];
	}
}

- (BOOL) _generateGameboxWithError: (NSError **)outError
{	
	NSAssert([self sourcePath] != nil, @"_generateGameboxWithError: called before source path was set.");

	NSFileManager *manager = [NSFileManager defaultManager];

	NSString *gameName		= [[self gameProfile] gameName];
	if (!gameName) gameName	= [[self class] nameForGameAtPath: [self sourcePath]];
	
	NSString *gamesFolder	= [[NSApp delegate] gamesFolderPath];
	//If the games folder is missing or not set, then fall back on a path we know does exist (the Desktop)
	if (!gamesFolder || ![manager fileExistsAtPath: gamesFolder])
		gamesFolder = [[NSApp delegate] fallbackGamesFolderPath];
	
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


- (void) _cleanup
{
	[super _cleanup];
	
	//Delete our newly-minted gamebox if we didn't finish importing it before we were closed
	if ([self importStage] != BXImportFinished && [self gamePackage])
	{
		NSString *path = [[self gamePackage] bundlePath];
		if (path)
		{
			NSFileManager *manager = [NSFileManager defaultManager];
			[manager removeItemAtPath: path error: NULL];	
		}
	}
	
	//Unmount any source volume that we mounted in the course of importing
	if (didMountSourceVolume)
	{
		NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
		[workspace unmountAndEjectDeviceAtPath: [self sourcePath]];
		didMountSourceVolume = NO;
	}
}

@end