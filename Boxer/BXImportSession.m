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
//- The life cycle of this class goes against the grain of Cocoa's document architecture:
//  'blank' documents are created in order to show the what-do-you-want-to-import picker,
//  and then populated after that with a file URL once the user has chosen a source.
//  Instead, the initial source picker (which is conceptually identical to an Open File dialog)
//  should be handled by a separate class that creates fully prepared import sessions to continue
//  the import process.

#import "BXImportSession.h"
#import "BXSessionPrivate.h"
#import "BXEmulator+BXDOSFileSystem.h"

#import "BXDOSWindowControllerLion.h"
#import "BXImportWindowController.h"
#import "BXDOSWindow.h"

#import "BXAppController+BXGamesFolder.h"
#import "BXInspectorController.h"
#import "BXGameProfile.h"
#import "BXPackage.h"
#import "BXDrive.h"
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

#import "BXInstallerScan.h"
#import "BXEmulatorConfiguration.h"

#import "BXPathEnumerator.h"


#pragma mark -
#pragma mark Private method declarations

@interface BXImportSession ()
@property (readwrite, retain, nonatomic) NSArray *installerPaths;
@property (readwrite, copy, nonatomic) NSString *sourcePath;

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
@synthesize installerPaths;
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
	
	[self setSourceFileImportOperation: nil], [sourceFileImportOperation release];
	[super dealloc];
}

- (id) initWithContentsOfURL: (NSURL *)absoluteURL
					  ofType: (NSString *)typeName
					   error: (NSError **)outError
{
	if ((self = [super initWithContentsOfURL: absoluteURL ofType: typeName error: outError]))
	{
        [self setImportStage: BXImportSessionLoadingSourcePath];
        //Override the Appkit-defined file URL determination, in case our
        //final source path differs from the provided URL.
		[self setFileURL: [NSURL fileURLWithPath: [self sourcePath]]];
	}
	return self;
}


- (BOOL) readFromURL: (NSURL *)absoluteURL
			  ofType: (NSString *)typeName
			   error: (NSError **)outError
{
	didMountSourceVolume = NO;
	
	NSString *filePath = [[self class] preferredSourcePathForPath: [absoluteURL path]
															error: outError];
	
	//Bail out if we could not determine a suitable source path
	//(in which case the error will have been populated)
	if (!filePath) return NO;
    [self setSourcePath: filePath];
                          
    //Create an installer scan operation to perform the actual 'loading' of the URL
    //(scanning it for installer executables, game profile etc.)
    //The didFinish callback will continue the actual import process from this point.
    BXInstallerScan *scan = [BXInstallerScan scanWithBasePath: filePath];
    [scan setDelegate: self];
    [scan setDidFinishSelector: @selector(installerScanDidFinish:)];
    
    //Don't automatically eject any image that the scan had to mount: instead
    //we'll use the mounted volume ourselves for later operations, and eject
    //it at the end of importing.
    [scan setEjectAfterScanning: BXFileScanNeverEject];
    
    [scanQueue addOperation: scan];
		
    return YES;
}

- (void) installerScanDidFinish: (NSNotification *)notification
{
    BXInstallerScan *scan = [notification object];
    
    if ([scan succeeded])
    {
        [self setGameProfile: [scan detectedProfile]];
        
        //If we were scanning an image, then use the mounted image volume
        //as our source path instead.
        if ([scan mountedVolumePath])
        {
            [self setSourcePath: [scan mountedVolumePath]];
            didMountSourceVolume = [scan didMountVolume];
        }
        else
        {
            [self setSourcePath: [scan basePath]];
        }
        
        [self setFileURL: [NSURL fileURLWithPath: [self sourcePath]]];
        [self setInstallerPaths: [[self sourcePath] stringsByAppendingPaths: [scan matchingPaths]]];
        
        //If the scan found installers, and doesn't otherwise think
        //the game is already installed, then we'll ask the user to
        //choose which installer to use.
		if (![scan isAlreadyInstalled] && [[self installerPaths] count])
        {
			[self setImportStage: BXImportSessionWaitingForInstaller];
            [NSApp requestUserAttention: NSInformationalRequest];
        }
        //Otherwise, we'll get on with finalizing the import directly.
		else
        {
			[self skipInstaller];
        }
    }
    else
    {
        [self setSourcePath: nil];
        [self setInstallerPaths: nil];
        [self setFileURL: nil];
		[self setImportStage: BXImportSessionWaitingForSourcePath];
		
        //Eject any disk that was mounted as a result of the scan
        if ([scan didMountVolume])
        {
            NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
            [workspace unmountAndEjectDeviceAtPath: [scan mountedVolumePath]];
            didMountSourceVolume = NO;
        }
        
        //If there was an error that wasn't just that the operation was cancelled,
        //display it to the user now.
        NSError *error = [scan error];
        if (error && !([[error domain] isEqualToString: NSCocoaErrorDomain] &&
                       [error code] == NSUserCancelledError))
        {
            //If we failed, then display the error as a sheet
            [self presentError: error
                modalForWindow: [self windowForSheet]
                      delegate: nil
            didPresentSelector: NULL
                   contextInfo: NULL];
        }
    }
}


#pragma mark -
#pragma mark Window management

- (void) makeWindowControllers
{
    BXDOSWindowController *controller;
	if ([BXAppController isRunningOnLionOrAbove])
	{
		controller = [[BXDOSWindowControllerLion alloc] initWithWindowNibName: @"DOSImportWindow"];
	}
	else
	{
		controller = [[BXDOSWindowController alloc] initWithWindowNibName: @"DOSImportWindow"];
	}
	
	[self addWindowController:		controller];
	[self setDOSWindowController:	controller];
	
	[controller setShouldCloseDocument: YES];
    [controller release];
    
	
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
	//FIXME: for god's sake this is idiotic, we should detect this with contextinfo or alert class
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

+ (NSSet *) keyPathsForValuesAffectingPreferredInstallerPath
{
    return [NSSet setWithObject: @"installerPaths"];
}

- (NSString *) preferredInstallerPath
{
    if ([[self installerPaths] count])
        return [[self installerPaths] objectAtIndex: 0];
    else return nil;
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
	BXReleaseMedium medium = [[self gameProfile] coverArtMedium];
	
	//If the game profile doesn't have an era, then autodetect it
	if (medium == BXUnknownMedium)
	{
		//We prefer the original source path for autodetection,
		//but fall back on the contents of the game package if the source path has been removed.
		if ([self sourcePath] && [[NSFileManager defaultManager] isReadableFileAtPath: [self sourcePath]])
        {
            //TODO: detect here whether the source path is original media (floppy disk, CD-ROM, ISO/IMG)
            //and if so match the era to the kind of media used. This should be handled in eraOfGameAtPath:.
			medium = [BXGameProfile mediumOfGameAtPath: [self sourcePath]];
        }
		else if ([self gamePackage])
        {
			medium = [BXGameProfile mediumOfGameAtPath: [[self gamePackage] bundlePath]];
        }
		
		//Record the autodetected era so we don't have to scan the filesystem next time.
		[[self gameProfile] setCoverArtMedium: medium];
	}
	
	NSImage *icon = [[self class] bootlegCoverArtForGamePackage: [self gamePackage] withMedium: medium];
	[[self gamePackage] setCoverArt: icon];
	hasAutoGeneratedIcon = YES;
}


#pragma mark -
#pragma mark Import steps

//IMPLEMENTATION NOTE: this is essentially a reimplementation of initWithContentsOfURL:fileType:withError:
//designed to be called programmatically after the document has been created, to 'fill in the gaps'.
//The actual work of this method is mostly done by readFromURL:ofType:error:, and this method just
//displays any error from that method.
//(This is going against the grain of how Cocoa documents are meant to work, and indicates that our
//'drop what you want to import here' stage of the import process should not be managed by a blank
//BXImportSession at all: but by a separate class that creates import sessions itself.)
- (void) importFromSourcePath: (NSString *)path
{
	//Sanity checks: if these fail then there is a programming error.
	NSAssert(path != nil, @"Nil path passed to BXImportSession importFromSourcePath:");
	NSAssert([self importStage] <= BXImportSessionWaitingForInstaller, @"Cannot call importFromSourcePath after game import has already started.");
	
	NSURL *sourceURL = [NSURL fileURLWithPath: [path stringByStandardizingPath]];
	
	NSError *readError = nil;
    
	BOOL readSucceeded = [self readFromURL: sourceURL
									ofType: nil
									 error: &readError];
    
    if (readSucceeded)
    {
        [self setImportStage: BXImportSessionLoadingSourcePath];
        [self setFileURL: [NSURL fileURLWithPath: [self sourcePath]]];
    }
	else
    {
		[self setFileURL: nil];
		[self setImportStage: BXImportSessionWaitingForSourcePath];
        
        if (readError)
        {
            //If we failed, then display the error as a sheet
            [self presentError: readError
                modalForWindow: [self windowForSheet]
                      delegate: nil
            didPresentSelector: NULL
                   contextInfo: NULL];
        }
	}
}

- (void) cancelInstallerScan
{
	//Sanity checks: if these fail then there is a programming error.
	NSAssert([self importStage] <= BXImportSessionLoadingSourcePath, @"Cannot call cancelInstallerScan after scan is finished.");
    
    [scanQueue cancelAllOperations];
    
    //Our installerScanDidFinish: callback will take care of resetting
    //the import state back to how it should be.
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
	[self setFileURL: nil];
	
	[self setImportStage: BXImportSessionWaitingForSourcePath];
}

- (void) launchInstaller: (NSString *)path
{
	//Sanity checks: if these fail then there is a programming error.
	NSAssert(path != nil, @"No targetPath specified when BXImportSession launchInstaller: was called.");
	NSAssert([self sourcePath] != nil, @"No sourcePath specified when BXImportSession launchInstaller: was called.");
	
	//Generate a new gamebox for us to import into.
    [self _generateGameboxWithError: NULL];
	
	[self setImportStage: BXImportSessionRunningInstaller];
	
	[[self importWindowController] setShouldCloseDocument: NO];
	[[self DOSWindowController] setShouldCloseDocument: YES];
	[[self importWindowController] handOffToController: [self DOSWindowController]];
	
	//Set the installer as the target executable for this session
	[self setTargetPath: path];
    //Aaaand start emulating!
	[self start];
}

- (void) skipInstaller
{
	[self setTargetPath: nil];
	[self setImportStage: BXImportSessionReadyToFinalize];
    
    //Create a new gamebox for us to import into.
    [self _generateGameboxWithError: NULL];
	
	[self importSourceFiles];
}

- (void) finishInstaller
{	
	//Stop the emulation process
	[self cancel];
	
	//Close the program panel before handoff, otherwise it scales weirdly
	[[self DOSWindowController] hideProgramPanel: self];
	
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


//FIXME: this is a massive function, and a lot of its work could be split up.
- (void) importSourceFiles
{
	//Sanity checks: if these fail then there is a programming error.
	//The fact that we're even checking this shit is proof that this class needs refactoring big-time
	NSAssert([self importStage] == BXImportSessionReadyToFinalize, @"BXImportSession importSourceFiles: was called before we are ready to finalize.");
	NSAssert([self sourcePath] != nil, @"No sourcePath specified when BXImportSession importSourceFiles: was called.");
	
    
    //Before we begin, wait for any already-in-progress operations to finish
	//(In case the user started importing volumes via the Drives panel during installation)
	[importQueue waitUntilAllOperationsAreFinished];
	
    
	NSFileManager *manager = [NSFileManager defaultManager];
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSSet *bundleableTypes = [[BXAppController mountableFolderTypes] setByAddingObjectsFromSet: [BXAppController mountableImageTypes]];
    
	
	//Determine how we should import the source files
	//-----------------------------------------------
    
	//If the source path no longer exists, it means the user probably
    //ejected the disk and we can't import it.
	//FIXME: make this properly handle the case where the source path
    //was a mounted volume for a disc image.
	if (![manager fileExistsAtPath: [self sourcePath]])
	{
		//Skip straight to cleanup
		[self finalizeGamebox];
		return;
	}
	
	//If there are already drives in the gamebox other than C,
    //it means the user did their own importing and we shouldn't
    //interfere with their work
	NSArray *alreadyBundledVolumes = [[self gamePackage] volumesOfTypes: bundleableTypes];
	if ([alreadyBundledVolumes count] > 1) //There will always be a volume for the C drive
	{
		//Skip straight to cleanup
		[self finalizeGamebox];
		return;
	}
	
	
	//At this point, all the edge cases are out of the way
    //and we know we'll need to import something.
	//Now we need to decide exactly what we're importing,
    //and how we should import it.
	
	BXDrive *driveToImport = nil;
	BXOperation *importOperation = nil;
	BXSourceFileImportType importType = BXImportTypeUnknown;
	
	BOOL didInstallFiles = [self gameDidInstall];
	BOOL isMountableImage = [workspace file: [self sourcePath]
                               matchesTypes: [BXAppController mountableImageTypes]];
	BOOL isMountableFolder = !isMountableImage && [workspace file: [self sourcePath]
                                                     matchesTypes: [BXAppController mountableFolderTypes]];
	
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
    
    //Otherwise, we need to decide if the source path represents an already-installed
    //game folder (which should be imported directly to the C drive) or whether it
    //represents the original install media (which should be imported as a separate
    //CD-ROM/floppy disk.)
	else
	{
		NSString *volumePath = [workspace volumeForPath: [self sourcePath]];
		NSString *volumeType = [workspace volumeTypeForPath: volumePath];
		
		BOOL isRealCDROM = [volumeType isEqualToString: dataCDVolumeType];
		BOOL isRealFloppy = !isRealCDROM && [volumeType isEqualToString: FATVolumeType] && [workspace isFloppySizedVolumeAtPath: volumePath];
		
		//If the installer copied files to our C drive, or the source files are on
        //a CDROM/floppy volume, then the source files presumably represent the original
        //install media and should be imported as a new CD-ROM/floppy disk.
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
			if (isRealFloppy || [[self gameProfile] sourceDriveType] == BXDriveFloppyDisk)
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
			
			//Guess whether the game files expect to be located in the root of drive C
            //(GOG games, Steam games etc.) or in a subfolder within drive C
            //(almost everything else)
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
                //Otherwise, remove the old empty C drive we created and import
                //the source path as a new C drive in its place.
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
	//We require source files to be imported in all cases except when importing from physical CD.
	//This is because that's the only situation that doesn't suck to recover from, if it turns
	//out the game needs the CD (because you can just keep it in the drive and Boxer's happy.)
	//TODO: make this decision more formal and/or move it upstairs into importSourceFiles.
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
		if (![operation isCancelled])
		{
            //If the imported drive is replacing our original C drive, then
            //update the root drive path accordingly so that cleanGamebox
            //will clean up the right place.
            if (isImport && [[[operation drive] letter] isEqualToString: @"C"])
            {
                [self setRootDrivePath: [operation importedDrivePath]];
            }
        }
		
		[self setSourceFileImportOperation: nil];
		[self finalizeGamebox];
	}
	
	//If the operation failed with an error, then determine if we can retry
	//with a safer import method, or skip to the next stage if not.
	else
	{
		BXOperation <BXDriveImport> *fallbackImport = nil;
		
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
			[self finalizeGamebox];
		}
	}
}

- (void) finalizeGamebox
{
	[self setImportStage: BXImportSessionCleaningGamebox];

	NSSet *bundleableTypes = [[BXAppController mountableFolderTypes] setByAddingObjectsFromSet: [BXAppController mountableImageTypes]];
	
	NSFileManager *manager	= [NSFileManager defaultManager];
	NSWorkspace *workspace	= [NSWorkspace sharedWorkspace];
	
	NSString *pathToClean	= [self rootDrivePath];
	NSString *pathForDrives	= [[self gamePackage] resourcePath];
    
    
    //Import any bundled DOSBox configuration: converting any mount commands
    //into drive imports, and any launch commands into a launcher batch file.
    
    NSString *bundledConfigPath = [[self class] preferredConfigurationFileFromPath: [self rootDrivePath]
                                                                             error: nil];
    
    if (bundledConfigPath)
    {
        BXEmulatorConfiguration *bundledConfig = [BXEmulatorConfiguration configurationWithContentsOfFile: bundledConfigPath error: nil];
        
        if (bundledConfig)
        {
            //Strip out all the junk we don't care about from the original game configuration.
            BXEmulatorConfiguration *sanitizedConfig = [[self class] sanitizedVersionOfConfiguration: bundledConfig];
            
            //Import any drives that were mounted in the (original) autoexec.
            NSArray *mountCommands = [[self class] mountCommandsFromConfiguration: bundledConfig];
            
            //TWEAK: use the config's own dir as the base path for drive mounts instead
            //of the root C drive, just in case there's a funny folder structure going on.
            NSString *basePath = [bundledConfigPath stringByDeletingLastPathComponent];
            
            for (NSString *mountCommand in mountCommands)
            {
                BXDrive *drive = [BXEmulator driveFromMountCommand: mountCommand
                                                          basePath: basePath
                                                             error: nil];
                
                
                //TWEAK: ignore drive C mounts, as we already have our drive C.
                //(And if we fucked it up, then it's a bit late to change now.)
                if (drive && ![[drive letter] isEqualToString: @"C"])
                {
                    //TWEAK: Copy the drive files if they lie outside the gamebox,
                    //otherwise move them.
                    BOOL copy = ![[drive path] isRootedInPath: [self rootDrivePath]];
                    BXOperation <BXDriveImport> *importOperation = [BXDriveImport importOperationForDrive: drive
                                                                                            toDestination: pathForDrives
                                                                                                copyFiles: copy];
                    
                    [importQueue addOperation: importOperation];
                }
            }
            
            //If the original autoexec contained any launch commands, convert those
            //into a launcher batchfile in the root drive: we then assign that as
            //the default program to launch.
            NSArray *launchCommands = [[self class] launchCommandsFromConfiguration: bundledConfig];
            
            if ([launchCommands count])
            {
                NSString *launchPath = [[self rootDrivePath] stringByAppendingPathComponent: @"bxlaunch.bat"];
                NSString *startupCommandString = [launchCommands componentsJoinedByString: @"\r\n"];
                
                BOOL createdLauncher = [startupCommandString writeToFile: launchPath
                                                              atomically: NO
                                                                encoding: BXDisplayStringEncoding
                                                                   error: nil];
                
                if (createdLauncher) [[self gamePackage] setTargetPath: launchPath];
            }
            
            //Finally, save the sanitized configuration into the gamebox.
            NSString *configPath = [[self gamePackage] configurationFilePath];
            [self _saveConfiguration: sanitizedConfig toFile: configPath];
        }
    }
    
    
    //After picking up any bundled configuration, scan the imported contents
    //to strip out unnecessary files and migrate any remaining disc images.
    
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
        
        //TWEAK: exclude .img images from the bundleable types, because it is much more
        //likely that these are regular resource files for a DOS game, not actual images.
        //TODO: validate whether each found image is actually a proper image, regardless
        //of file extension.
        if (isBundleable && [[[path pathExtension] lowercaseString] isEqualToString: @"img"])
            isBundleable = NO;
        
        
        //If this file is a mountable type, move it into the gamebox's root folder where we can find it.
		if (isBundleable)
		{
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
	//Don't set the active program if we already have one: this way, we keep track of when a user launches
    //a batch file, and don't immediately discard it in favour of the next program the batch-file runs
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
	[[[self DOSWindowController] window] exitFullScreen: self];
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

- (BOOL) _shouldPersistGameProfile: (BXGameProfile *)profile
{
    //Not all files may be available at this point, potentially causing game
    //detection to fail: so only persist the game profile if we got a positive
    //match on a particular game.
    return profile && ![[profile identifier] isEqualToString: BXGenericProfileIdentifier];
}

- (BOOL) _shouldSuppressDisplaySleep
{
    //Always allow the display to go to sleep when it wants, on the assumption that
    //the emulation isn't doing anything particularly interesting during installation.
    return NO;
}

- (BOOL) _shouldAutoPause
{
	//Don't auto-pause the emulation while importing, even if the preference is on:
	//this allows lengthy copy operations to continue in the background.
    if (![[self emulator] isAtPrompt]) return NO;
    
    else return [super _shouldAutoPause];
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
	BXDriveType sourceDriveType = BXDriveAutodetect;
	if ([self gameProfile])
		sourceDriveType = [[self gameProfile] sourceDriveType];
	
	if (sourceDriveType == BXDriveAutodetect)
		sourceDriveType = [BXDrive preferredTypeForPath: [self sourcePath]];
	
	NSInteger freeSpace = BXDefaultFreeSpace;
	
	if ([self gameProfile])
		freeSpace = [[self gameProfile] requiredDiskSpace];
	
	if (freeSpace == BXDefaultFreeSpace && (sourceDriveType == BXDriveCDROM || [[self class] isCDROMSizedGameAtPath: [self sourcePath]]))
		freeSpace = BXFreeSpaceForCDROMInstall;
	
	
	//Mount our new empty gamebox as drive C
    
    //TODO: actually perform any error-handling with this error object
    NSError *mountError = nil;
    
	BXDrive *destinationDrive = [BXDrive hardDriveFromPath: [self rootDrivePath] atLetter: @"C"];
    [destinationDrive setTitle: NSLocalizedString(@"Destination Drive", @"The display title for the gamebox’s C drive when importing a game.")];
    
	[destinationDrive setFreeSpace: freeSpace];
	[self mountDrive: destinationDrive
            ifExists: BXDriveReplace
             options: BXBundledDriveMountOptions
               error: &mountError];
	
	//Then, create a drive of the appropriate type from the source files and mount away
	BXDrive *sourceDrive = [BXDrive driveFromPath: [self sourcePath] atLetter: nil withType: sourceDriveType];
	[sourceDrive setTitle: NSLocalizedString(@"Source Drive", @"The display title for the source drive when importing.")];
    
    [self mountDrive: sourceDrive
            ifExists: BXDriveReplace
             options: BXImportSourceMountOptions
               error: &mountError];
	
	//Automount all currently mounted floppy and CD-ROM volumes
	[self mountFloppyVolumesWithError: &mountError];
	[self mountCDVolumesWithError: &mountError];
	
	//Mount our internal DOS toolkit and temporary drives unless the profile says otherwise
	if (![self gameProfile] || [[self gameProfile] mountHelperDrivesDuringImport])
	{
		[self mountToolkitDriveWithError: &mountError];
		[self mountTempDriveWithError: &mountError];
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
		//Prep the gamebox by creating an empty C drive in it
		NSString *cPath = [[gamebox resourcePath] stringByAppendingPathComponent: @"C.harddisk"];
		
		BOOL success = [manager createDirectoryAtPath: cPath
						  withIntermediateDirectories: NO
										   attributes: nil
												error: outError];
		
		if (success)
		{
            //Assign this as the gamebox for this session
			[self setGamePackage: gamebox];
			[self setFileURL: [NSURL fileURLWithPath: [gamebox bundlePath]]];
			[self setRootDrivePath: cPath];
            
            //Try to find a suitable cover-art icon from the source path
            NSImage *icon = [[self class] boxArtForGameAtPath: [self sourcePath]];
            if (icon) [gamebox setCoverArt: icon];
            else [self generateBootlegIcon];
            
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
		//If any actual files were created, then assume the game installed.
		//IMPLEMENTATION NOTE: We'd like to be more rigorous and check for
		//executables, but some CD-ROM games only store configuration files
		//on the hard drive.
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