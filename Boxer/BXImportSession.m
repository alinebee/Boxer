/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//IMPLEMENTATION NOTE: this class is currently a conceptual mess, and needs serious restructuring:
//- The UI is responsible for ensuring that the import workflow is handled correctly and that
//  steps are performed in the correct order. Instead of saying "OK, continue with the next
//  logical step of the operation", the UI says "OK, now run this specific step." Bad.
//- The import process cannot currently be done unattended as it relies on UI confirmation.
//  This prevents it being easily scriptable.
//- Despite being an NSDocument subclass, BXImportSession instances cannot be loaded from an existing URL:
//  they have to go through the importFromSourcePath: mechanism.


#import "BXImportSession.h"
#import "BXSessionPrivate.h"

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
#import "BXDriveImport.h"
#import "BXBinCueImageImport.h"

#import "BXImportSession+BXImportPolicies.h"
#import "BXSession+BXFileManager.h"

#import "NSWorkspace+BXFileTypes.h"
#import "NSWorkspace+BXMountedVolumes.h"
#import "NSWorkspace+BXExecutableTypes.h"
#import "NSString+BXPaths.h"

#import "BXPathEnumerator.h"


#pragma mark -
#pragma mark Private method declarations

@interface BXImportSession ()
@property (readwrite, retain, nonatomic) NSArray *installerPaths;
@property (readwrite, copy, nonatomic) NSString *sourcePath;
@property (readwrite, copy, nonatomic) NSString *preferredInstallerPath;

@property (readwrite, assign, nonatomic) BXImportStage importStage;
@property (readwrite, assign, nonatomic) BXOperationProgress stageProgress;
@property (readwrite, assign, nonatomic) BOOL stageProgressIndeterminate;
@property (readwrite, retain, nonatomic) BXOperation *sourceFileImportOperation;
@property (readwrite, assign, nonatomic) BXSourceFileImportType sourceFileImportType;
@property (readwrite, assign, nonatomic) BOOL sourceFileImportRequired;

//Only defined for internal use
@property (copy, nonatomic) NSString *rootDrivePath;


//Create a new empty game package for our source path.
- (BOOL) _generateGameboxWithError: (NSError **)error;

//Return the path to which the current gamebox will be moved if renamed with the specified name.
- (NSString *) _destinationPathForGameboxName: (NSString *)newName;

@end


#pragma mark -
#pragma mark Actual implementation

@implementation BXImportSession
@synthesize importWindowController;
@synthesize sourcePath, rootDrivePath;
@synthesize installerPaths, preferredInstallerPath;
@synthesize importStage, stageProgress, stageProgressIndeterminate;
@synthesize sourceFileImportOperation, sourceFileImportType, sourceFileImportRequired;


#pragma mark -
#pragma mark Initialization and deallocation

- (void) dealloc
{
	[self setImportWindowController: nil],	[importWindowController release];
	[self setSourcePath: nil],				[sourcePath release];
	[self setRootDrivePath: nil],			[rootDrivePath release];
	[self setInstallerPaths: nil],			[installerPaths release];
	[self setPreferredInstallerPath: nil],	[preferredInstallerPath release];
	
	[self setSourceFileImportOperation: nil], [sourceFileImportOperation release];
	[super dealloc];
}

- (id)initWithContentsOfURL: (NSURL *)absoluteURL
					 ofType: (NSString *)typeName
					  error: (NSError **)outError
{
	if ((self = [super initWithContentsOfURL: absoluteURL ofType: typeName error: outError]))
	{
        //Override the -defined
		[self setFileURL: [NSURL fileURLWithPath: [self sourcePath]]];
		
		if ([self gameNeedsInstalling])
			[self setImportStage: BXImportSessionWaitingForInstaller];
		else
			[self setImportStage: BXImportSessionReadyToFinalize];
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
	[super makeWindowControllers];
	
	BXImportWindowController *importController	= [[BXImportWindowController alloc] initWithWindowNibName: @"ImportWindow"];
	
	[self addWindowController: importController];
	[self setImportWindowController: importController];
	
	[importController setShouldCloseDocument: YES];

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
	if ([self importStage] == BXImportSessionRunningInstaller)
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

//We are considered to have unsaved changes if we have a not-yet-finalized gamebox
- (BOOL) isDocumentEdited	{ return [self gamePackage] != nil && [self importStage] < BXImportSessionFinished; }

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
	static NSSet *types = nil;
    
    //A subset of our usual mountable types: we only accept regular folders and disk image
    //formats which can be mounted by hdiutil (so that we can inspect their filesystems)
	if (!types) types = [[[BXAppController OSXMountableImageTypes] setByAddingObject: @"public.folder"] retain];
    
    return types;
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
	
	if ([installers containsObject: [self activeProgramPath]]) return YES;
	if ([[self class] isInstallerAtPath: [self activeProgramPath]]) return YES;
	
	return NO;
}


//Synthesized setter is overridden to reset the progress whenever we change the stage
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
	NSAssert(path != nil, @"Nil path passed to BXImportSession importFromSourcePath:");
	NSAssert([self importStage] <= BXImportSessionWaitingForInstaller, @"Cannot call importFromSourcePath after game import has already started.");
	
	NSURL *sourceURL = [NSURL fileURLWithPath: [path stringByStandardizingPath]];
	
	NSError *readError = nil;

	[self setFileURL: sourceURL];

	[self setImportStage: BXImportSessionLoadingSourcePath];
	
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
			[self setImportStage: BXImportSessionWaitingForInstaller];
		}
		else
		{
			[self skipInstaller];
		}
	}
	else if (readError)
	{
		[self setFileURL: nil];
		[self setImportStage: BXImportSessionWaitingForSourcePath];
		
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
	NSAssert([self importStage] <= BXImportSessionWaitingForInstaller, @"Cannot call cancelSourcePath after game import has already started.");

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
	
	[self setImportStage: BXImportSessionWaitingForSourcePath];
}

- (void) launchInstaller: (NSString *)path
{
	//Sanity checks: if these fail then there is a programming error.
	NSAssert(path != nil, @"No targetPath specified when BXImportSession launchInstaller: was called.");
	NSAssert([self sourcePath] != nil, @"No sourcePath specified when BXImportSession launchInstaller: was called.");
	
	//If we don't yet have a game package (and we shouldn't), generate one now
	if (![self gamePackage])
	{
		[self _generateGameboxWithError: NULL];
	}
	
	[self setImportStage: BXImportSessionRunningInstaller];
	
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
	[self setImportStage: BXImportSessionReadyToFinalize];
	
	[self importSourceFiles];
}

- (void) finishInstaller
{	
	//Tweak: disable any Growl drive notifications beyond this point.
	//It will take time for the emulator to shut down fully, during which
	//our import process may mount/unmount additional disks whose notifications
	//we don't want to appear.
	showDriveNotifications = NO;
	
	//Stop the installer process
	[self cancel];
	
	//Close the program panel before handoff, otherwise it scales weirdly
	[[self DOSWindowController] setProgramPanelShown: NO];
	
	//Close the inspector panel also
	[[BXInspectorController controller] setPanelShown: NO];
	
	//Clear the DOS frame
	[[self DOSWindowController] updateWithFrame: nil];
	
	//Switch to the next stage before handing off, so that the correct panel is visible as soon as we do
	[self setImportStage: BXImportSessionReadyToFinalize];
	
	//Finally, hand off to the import window
	[[self importWindowController] pickUpFromController: [self DOSWindowController]];
	
	//Aaaaand start in on the next stage immediately
	[self importSourceFiles];
}


#pragma mark -
#pragma mark Finalizing the import

- (void) importSourceFiles
{
	//Sanity checks: if these fail then there is a programming error.
	//The fact that we're even checking this shit is proof that this class needs refactoring big-time
	NSAssert([self importStage] == BXImportSessionReadyToFinalize, @"BXImportSession importSourceFiles: was called before we are ready to finalize.");
	NSAssert([self sourcePath] != nil, @"No sourcePath specified when BXImportSession importSourceFiles: was called.");
	
	
	NSFileManager *manager = [NSFileManager defaultManager];
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSSet *bundleableTypes = [[BXAppController mountableFolderTypes] setByAddingObjectsFromSet: [BXAppController mountableImageTypes]];
	
	//If we don't have a source folder yet, generate one now before continuing
	//(This will happen if there were no installers, or the user skipped the installer)
	if (![self gamePackage])
	{
		[self _generateGameboxWithError: NULL];
	}
	
	//At this point, wait for any already-in-progress operations to finish
	//(In case the user started importing volumes via the Drives panel during installation)
	[importQueue waitUntilAllOperationsAreFinished];
	
	
	//Determine how we should import the source files
	//-----------------------------------------------

	//If the source path no longer exists, it means the user probably ejected the disk and we can't import it.
	//FIXME: make this properly handle the case where the source path was a mounted volume for a disc image.
	if (![manager fileExistsAtPath: [self sourcePath]])
	{
		//Skip straight to cleanup
		[self cleanGamebox];
		return;
	}
	
	//If there are already drives in the gamebox other than C, it means the user did their own importing
	//and we shouldn't interfere with their work
	NSArray *alreadyBundledVolumes = [[self gamePackage] volumesOfTypes: bundleableTypes];
	if ([alreadyBundledVolumes count] > 1) //There will always be a volume for the C drive
	{
		//Skip straight to cleanup
		[self cleanGamebox];
		return;
	}
	
	
	//At this point, all the edge cases are out of the way and we know we'll need to import something.
	//Now we need to decide exactly what we're importing, and how we should import it.
	
	BXDrive *driveToImport = nil;
	BXOperation *importOperation = nil;
	BXSourceFileImportType importType = BXImportTypeUnknown;
	
	BOOL didInstallFiles = [self gameDidInstall];
	BOOL isMountableImage = [workspace file: [self sourcePath] matchesTypes: [BXAppController mountableImageTypes]];
	BOOL isMountableFolder = !isMountableImage && [workspace file: [self sourcePath] matchesTypes: [BXAppController mountableFolderTypes]];
	
	//If the source path is directly bundleable (it is an image or a mountable folder)
	//then import it as a new drive into the gamebox.
	if (isMountableImage || isMountableFolder)
	{
		driveToImport = [BXDrive driveFromPath: [self sourcePath] atLetter: nil];
		
		//If the drive is marked as being for drive C, then check what we need to do with our original C drive
		if ([[driveToImport letter] isEqualToString: @"C"])
		{	
			//If any files were installed to the original C drive, then reset the import drive letter
			//so that the drive will be imported alongside the existing C drive.
			if (didInstallFiles)
			{
				[driveToImport setLetter: nil];
			}
			//Otherwise, delete the original empty C drive so we can replace it with this one
			else
			{
				[manager removeItemAtPath: [self rootDrivePath] error: nil];
			}
		}
		
		//Mark what kind of import we're doing based on what the autodetected drive type is
		switch ([driveToImport type])
		{
			case BXDriveCDROM:
				importType = (isMountableImage) ? BXImportFromCDImage : BXImportFromFolderToCD; break;
			case BXDriveFloppyDisk:
				importType = (isMountableImage) ? BXImportFromFloppyImage : BXImportFromFolderToFloppy; break;
			default:
				importType = (isMountableImage) ? BXImportFromHardDiskImage : BXImportFromFolderToHardDisk; break;
		}
		importOperation = [self importOperationForDrive: driveToImport startImmediately: NO];
	}
	else
	{
		NSString *volumePath = [workspace volumeForPath: [self sourcePath]];
		NSString *volumeType = [workspace volumeTypeForPath: volumePath];
		
		BOOL isRealCDROM = [volumeType isEqualToString: dataCDVolumeType];
		BOOL isRealFloppy = !isRealCDROM && [volumeType isEqualToString: FATVolumeType] && [workspace isFloppySizedVolumeAtPath: volumePath];
		
		//If the installer copied files to our C drive, or the source files are on a CDROM/floppy volume,
		//then the source files should be imported as a new CD-ROM/floppy disk.
		if (didInstallFiles || isRealCDROM || isRealFloppy)
		{
			NSString *pathToImport = [self sourcePath];
			NSString *sourceImagePath = [workspace sourceImageForVolume: [self sourcePath]];
			BOOL isDiskImage = NO;
		
			//If the source path is on a DOSBox-compatible disk image, then import the image directly.
			if (sourceImagePath && [workspace file: sourceImagePath matchesTypes: [BXAppController mountableImageTypes]])
			{
				isDiskImage = YES;
				pathToImport = sourceImagePath;
			}
			
			//If the source is an actual floppy disk, or this game expects to be installed off floppies,
			//then import the source files as a floppy disk.
			if (isRealFloppy || [[self gameProfile] installMedium] == BXDriveFloppyDisk)
			{
				if (isDiskImage)		importType = BXImportFromFloppyImage;
				else if (isRealFloppy)	importType = BXImportFromFloppyVolume;
				else					importType = BXImportFromFolderToFloppy;
				
				driveToImport = [BXDrive floppyDriveFromPath: pathToImport atLetter: @"A"];
			}
			//In all other cases, import the source files as a CD-ROM drive.
			else
			{
				if (isDiskImage)		importType = BXImportFromCDImage;
				else if (isRealCDROM)	importType = BXImportFromCDVolume;
				else					importType = BXImportFromFolderToCD;
			
				driveToImport = [BXDrive CDROMFromPath: pathToImport atLetter: @"D"];
			}
			
			importOperation = [self importOperationForDrive: driveToImport startImmediately: NO];
		}
		
		//If the game didn't install anything and we're not importing a CD or floppy disk,
		//then assume that the source files represent an already-installed game, and copy
		//the source files directly into the gamebox's C drive.
		else
		{
			importType = BXImportFromPreInstalledGame;
			
			//Guess whether the game files expect to be located in the root of drive C (GOG games, Steam games etc.)
			//or in a subfolder within drive C (almost everything else)
			BOOL needsSubfolder = [[self class] shouldUseSubfolderForSourceFilesAtPath: [self sourcePath]];
			
			if (needsSubfolder)
			{
				//If we need to copy the source path into a subfolder of drive C,
				//then do this as a regular file copy rather than a drive import.
				
				NSString *subfolderName	= [[self sourcePath] lastPathComponent];
				//Ensure the destination name will be DOSBox-compatible
				NSString *safeName = [[self class] validDOSNameFromName: subfolderName];
				
				NSString *destination = [[self rootDrivePath] stringByAppendingPathComponent: safeName];
				
				importOperation = [BXSingleFileTransfer transferFromPath: [self sourcePath]
																  toPath: destination
															   copyFiles: YES];
			}
			else
			{
				[manager removeItemAtPath: [self rootDrivePath] error: nil];
				driveToImport	= [BXDrive hardDriveFromPath: [self sourcePath] atLetter: @"C"];
				importOperation	= [self importOperationForDrive: driveToImport startImmediately: NO];
			}
		}
	}
	
	//Set up the import operation and start it running.
	[self setSourceFileImportType: importType];
	[self setSourceFileImportOperation: importOperation];
	//If the gamebox is empty, then we need to import the source files for it to work at all;
	//so make cancelling the drive import cancel the rest of the import as well.
	[self setSourceFileImportRequired: !didInstallFiles];
	[self setImportStage: BXImportSessionImportingSourceFiles];
	
	[importQueue addOperation: importOperation];
}

- (BOOL) sourceFileImportRequired
{
	//TWEAK: we require source files to be imported in all cases except when importing from physical CD.
	//This is because that's the only situation that doesn't suck to recover from, if it turns
	//out the game needs the CD (because you can just keep it in the drive and it's happy.)
	//TODO: make this decision more formal and/or move it up into importSourceFiles.
	return sourceFileImportRequired || (sourceFileImportType != BXImportFromCDVolume);
	//return sourceFileImportRequired || (sourceFileImportType == BXImportTypeUnknown);
}

- (void) cancelSourceFileImport
{
	NSOperation *operation = [self sourceFileImportOperation];
	
	if (operation && ![operation isFinished] && [self importStage] == BXImportSessionImportingSourceFiles)
	{
		[operation cancel];
		[self setImportStage: BXImportSessionCancellingSourceFileImport];
	}
}


#pragma mark BXOperation delegate methods

- (void) setSourceFileImportOperation: (BXOperation *)operation
{
	if (operation != [self sourceFileImportOperation])
	{
		[sourceFileImportOperation release];
		sourceFileImportOperation = [operation retain];
		
		//Set up our source file import operation with custom callbacks
		if (operation)
		{
			[operation setDelegate: self];
			[operation setInProgressSelector: @selector(sourceFileImportInProgress:)];
			[operation setDidFinishSelector: @selector(sourceFileImportDidFinish:)];
		}
	}
}

- (void) sourceFileImportInProgress: (NSNotification *)notification
{
	id operation = [notification object];
	//Update our own progress to match the operation's progress

	[self setStageProgressIndeterminate: [operation isIndeterminate]];
	[self setStageProgress: [operation currentProgress]];
}

- (void) sourceFileImportDidFinish: (NSNotification *)notification
{
	id operation = [notification object];
	
	//Some source-file copies can be simple file transfers
	BOOL isImport = [operation conformsToProtocol: @protocol(BXDriveImport)];
	
	//If the operation succeeded or was cancelled by the user,
	//then proceed with the next stage of the import (cleanup.)
	if ([operation succeeded] || [operation isCancelled])
	{
		//If the operation was cancelled, then clean up any leftover files
		if ([operation isCancelled])
		{
			if ([operation respondsToSelector: @selector(undoTransfer)]) [operation undoTransfer];
		}
		
		//Otherwise, if the imported drive is replacing our original C drive,
		//then update the root drive path accordingly so that cleanGamebox
		//will clean up the right place
		else if (isImport && [[[operation drive] letter] isEqualToString: @"C"])
		{
			[self setRootDrivePath: [operation importedDrivePath]];
		}
		
		[self setSourceFileImportOperation: nil];
		[self cleanGamebox];
	}
	
	//If the operation failed with an error, then determine if we can retry
	//with a safer import method, or skip to the next stage if not.
	else
	{
		BXOperation <BXDriveImport> *fallbackImport = nil;
		
		if ([operation respondsToSelector: @selector(undoTransfer)]) [operation undoTransfer];
		
		//Check if we can retry the operation...
		if (isImport && (fallbackImport = [BXDriveImport fallbackForFailedImport: operation]))
		{
			[self setSourceFileImportOperation: fallbackImport];
			
			//IMPLEMENTATION NOTE: we add a short delay before retrying from BIN/CUE imports,
			//to allow time for the original volume to remount fully.
			if ([operation isKindOfClass: [BXBinCueImageImport class]])
			{
				[importQueue performSelector: @selector(addOperation:) withObject: fallbackImport afterDelay: 2.0];
			}
			else [importQueue addOperation: fallbackImport];
		}
		
		//..and if not, skip the import altogether and pretend everything's OK.
		//TODO: analyze whether this failure will have resulted in an unusable gamebox,
		//then warn the user and offer to try importing again.
		else
		{
			[self setSourceFileImportOperation: nil];
			[self cleanGamebox];
		}
	}
}

- (void) cleanGamebox
{	
	[self setImportStage: BXImportSessionCleaningGamebox];

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
			
			BXOperation <BXDriveImport> *importOperation = [BXDriveImport importOperationForDrive: drive
																					toDestination: pathForDrives
																						copyFiles: NO];
			
			//Note: we don't set ourselves as a delegate for this import operation
			//because we don't care about success or failure notifications.
			[importQueue addOperation: importOperation];
		}
	}
	
	//Any import operations we do in this stage would be moves within the same volume,
	//so they should be done already, but let's wait anyway.
	[importQueue waitUntilAllOperationsAreFinished];
	
	//That's all folks!
	[self setImportStage: BXImportSessionFinished];
	
	//Add to the recent documents list
	[[NSDocumentController sharedDocumentController] noteNewRecentDocument: self];
	
	//Bounce to notify the user that we're done
	[NSApp requestUserAttention: NSInformationalRequest];
	
}


#pragma mark -
#pragma mark Responses to BXEmulator events

- (void) emulatorWillStartProgram: (NSNotification *)notification
{	
	//Don't set the active program if we already have one
	//This way, we keep track of when a user launches a batch file and don't immediately discard
	//it in favour of the next program the batch-file runs
	if (![self lastExecutedProgramPath])
	{
        NSString *programPath = [[notification userInfo] objectForKey: @"localPath"];
        if (programPath)
        {
            [self setLastExecutedProgramPath: programPath];
        }
        
		//Always show the program panel when installing
		//(Show only after a delay, so that the installer has time to start up)
		[[self DOSWindowController] performSelector: @selector(showProgramPanel:)
										 withObject: self
										 afterDelay: 1.0];
	}
}

- (void) emulatorDidReturnToShell: (NSNotification *)notification
{
	//Clear the active program
	[self setLastExecutedProgramPath: nil];
    [self setLastLaunchedProgramPath: nil];
	
	//Show the program chooser after returning to the DOS prompt
	//(Show only after a delay, so that the window has time to resize after quitting the game)
	[[self DOSWindowController] performSelector: @selector(showProgramPanel:)
									 withObject: self
									 afterDelay: 1.0];
	
	//Always drop out of fullscreen mode when we return to the prompt,
	//so that users can see the "finish importing" option
	[[self DOSWindowController] exitFullScreen: self];
}

- (void) emulatorDidFinish: (NSNotification *)notification
{
	[super emulatorDidFinish: notification];
	
	//Once the emulation session finishes, continue importing (if we're not doing so already)
	if (![emulator isCancelled] && [self importStage] == BXImportSessionRunningInstaller)
	{
		[self finishInstaller];
	}
}

#pragma mark -
#pragma mark Private internal methods

- (BOOL) _shouldSuppressDisplaySleep
{
    //Always allow the display to go to sleep when it wants, on the assumption
    //that the emulation isn't doing anything particularly interesting during installation.
    return NO;
}

- (BOOL) _shouldAutoPause
{
	//Don't auto-pause the emulation while importing, even if the preference is on:
	//this allows lengthy copy operations to continue in the background.
	return NO;
}

//We don't want to close the entire document after the emulated session is finished;
//instead we carry on and complete the installation process.
- (BOOL) _shouldCloseOnEmulatorExit { return NO; }

//We also don't want to start emulating as soon as the import session is created.
- (BOOL) _shouldStartImmediately { return NO; }

//And we DEFINITELY don't want to close when returning to the DOS prompt in any case.
- (BOOL) _shouldCloseOnProgramExit	{ return NO; }


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

- (BOOL) gameDidInstall
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
	if ([self importStage] != BXImportSessionFinished && [self gamePackage])
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