/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXImport.h"
#import "BXImport+BXImportPolicies.h"
#import "BXImportWindowController.h"
#import "NSWorkspace+BXFileTypes.h"
#import "NSWorkspace+BXMountedVolumes.h"
#import "NSWorkspace+BXExecutableTypes.h"
#import "NSString+BXPaths.h"
#import "BXAppController.h"
#import "BXGameProfile.h"
#import "BXImportError.h"


#pragma mark -
#pragma mark Private method declarations

@interface BXImport ()
@property (readwrite, retain, nonatomic) NSArray *installerPaths;
@property (readwrite, copy, nonatomic) NSString *sourcePath;
@property (readwrite, copy, nonatomic) NSString *preferredInstallerPath;
@property (readwrite, assign, nonatomic) BOOL thinking;

//Initiates whatever step of the import process we're up to: displaying an import panel, launching
//an installer, finalising import etc.
//Called when the user finishes each stage of the process and we have collected enough info to continue.
- (void) _continueImport;

@end


@implementation BXImport
@synthesize importWindowController;
@synthesize sourcePath;
@synthesize installerPaths, preferredInstallerPath;
@synthesize hasCompletedInstaller, hasFinalisedGamebox;
@synthesize thinking;

#pragma mark -
#pragma mark Initialization and deallocation

- (void) dealloc
{
	[self setSourcePath: nil],				[sourcePath release];
	[self setImportWindowController: nil],	[importWindowController release];
	[self setInstallerPaths: nil],			[installerPaths release];
	[self setPreferredInstallerPath: nil],	[preferredInstallerPath release];
	[super dealloc];
}

- (void) makeWindowControllers
{
	[super makeWindowControllers];
	BXImportWindowController *controller = [[BXImportWindowController alloc] initWithWindowNibName: @"ImportWindow"];
	
	[self addWindowController:			controller];
	[self setImportWindowController:	controller];
	[controller setShouldCloseDocument: YES];
	
	[controller release];
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
	//Unlike BXSession, we do not display the DOS window nor launch the emulator when this is called.
	//Instead, we decide what to do based on what stage of the import process we're in.
	[self _continueImport];
}

//We don't want to close the entire document after the emulated session is finished;
//instead we carry on and complete the installation process
- (BOOL) closeOnEmulatorExit { return NO; }


#pragma mark -
#pragma mark Import helpers

+ (NSSet *)acceptedSourceTypes
{
	static NSSet *acceptedTypes = nil;
	if (!acceptedTypes)
	{
		//A subset of our mountable types: we only accept regular folders and disk image formats
		//which can be mounted by hdiutil (so that we can inspect their filesystems)
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


#pragma mark -
#pragma mark Import steps

- (void) importFromSourcePath: (NSString *)path
{
	if (path)
	{
		[self setThinking: YES];
		
		NSError *error = nil;
		NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
		BXGameProfile *detectedProfile = nil;
		
		NSMutableArray *detectedInstallers = nil;
		NSArray *executables = nil;
		NSString *preferredInstaller = nil;
		
		//If the chosen path was a disk image, mount it and use the mounted volume as our source
		if ([workspace file: path matchesTypes: [NSSet setWithObject: @"public.disk-image"]])
		{
			NSString *mountedVolumePath = [workspace mountImageAtPath: path error: &error];
			if (mountedVolumePath) path = mountedVolumePath;
		}
		//If the chosen path was an audio CD, check if it has a corresponding data path		
		else if ([[workspace volumeTypeForPath: path] isEqualToString: audioCDVolumeType])
		{
			NSString *dataVolumePath = [workspace dataVolumeOfAudioCD: path];
			if (dataVolumePath) path = dataVolumePath;
		}
		
		//Now, autodetect the game and installers from the selected path
		if (!error)
		{
			detectedProfile	= [BXGameProfile detectedProfileForPath: path searchSubfolders: YES];
			executables		= [[self class] executablesAtPath: path recurse: YES];
			
			if ([executables count])
			{
				//Scan for installers
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
					
					//If this is the designated installer for this game,
					//add it to the list and use it as the preferred default
					if (!preferredInstaller && [detectedProfile isDesignatedInstallerAtPath: executablePath])
					{
						[detectedInstallers addObject: executablePath];
						preferredInstaller = executablePath;
					}
					
					//If it looks like an installer, go for it
					else if ([[self class] isInstallerAtPath: executablePath])
					{
						[detectedInstallers addObject: executablePath];
					}
				}
				
				if ([detectedInstallers count])
				{
					//Sort the installers by depth, and determine the preferred one
					[detectedInstallers sortUsingSelector: @selector(pathDepthCompare:)];
					
					//If we didn't find the game profile's own preferred installer, detect one from the list now
					if (!preferredInstaller)
						preferredInstaller = [[self class] preferredInstallerFromPaths: detectedInstallers];
				}
				
				//If no installers were found, check if this was a windows-only game
				else if (numWindowsExecutables == [executables count])
				{
					error = [BXImportWindowsOnlyError errorWithSourcePath: path userInfo: nil];
				}
			}
			else
			{
				//No executables were found - this indicates that the folder contained something other than a DOS game
				error = [BXImportNoExecutablesError errorWithSourcePath: path userInfo: nil];
			}
		}
		
		//If we encountered an error, bail out and display it
		if (error)
		{
			[self setThinking: NO];
			[self showWindows];
			
			[self presentError: error
				modalForWindow: [[self importWindowController] window]
					  delegate: nil
			didPresentSelector: NULL
				   contextInfo: NULL];
			
			return;
		}
				
		[self setSourcePath: path];
		[self setGameProfile: detectedProfile];
		
		//FIXME: we have to set the preferred installer first because BXInstallerPanelController is listening
		//for when we set the installer paths, and relies on knowing the preferred installer in advance
		//TODO: move the preferred installer detection off to BXInstallerPanelController instead?
		[self setPreferredInstallerPath: preferredInstaller];
		[self setInstallerPaths: detectedInstallers];
		
		[self setThinking: NO];
		
		//Now that we know the source path, we can continue to the next import step
		[self _continueImport];
		
	}
}

- (void) cancelSourcePath
{
	[self setSourcePath: nil];
	[self _continueImport];
}

- (void) confirmInstaller: (NSString *)path
{
	if (path)
	{
		[self setTargetPath: path];
		hasSkippedInstaller = NO;
		hasCompletedInstaller = NO;
		
		//Now that we have an installer, we can continue to launch it
		[self _continueImport];
	}
}

- (void) skipInstaller
{
	[self setTargetPath: nil];
	hasSkippedInstaller = YES;
	hasCompletedInstaller = NO;
	
	[self _continueImport];
}


- (BOOL) hasConfirmedSourcePath
{
	return [self sourcePath] != nil;
}

- (BOOL) hasConfirmedInstaller
{
	return [self targetPath] != nil;
}

- (BOOL) hasSkippedInstaller
{
	return hasSkippedInstaller || ![[self installerPaths] count];
}


- (void) _continueImport
{
	//We don't have a source path yet: display the dropzone panel for the user to provide one.
	if (![self hasConfirmedSourcePath])
	{
		[[self importWindowController] showDropzonePanel];
	}
	
	//We haven't yet confirmed an installer to run: display the choose-thine-installer panel.
	//(If there are no installers, then hasSkippedInstaller will be YES and this will be skipped.)
	else if (![self hasConfirmedInstaller] && ![self hasSkippedInstaller])
	{
		[[self importWindowController] showInstallerPanel];
	}
	
	//We haven't yet run the chosen installer after confirming it: launch it now.
	else if ([self hasConfirmedInstaller] && ![self hasCompletedInstaller])
	{
		[self start];
	}
	
	//We haven't yet finalised the gamebox after completing/skipping installation
	else if (![self hasFinalisedGamebox] && ([self hasSkippedInstaller] || [self hasCompletedInstaller]))
	{
		//TODO: finalise the gamebox here
	}
	
	//All done! Show the final import panel
	else if ([self hasFinalisedGamebox])
	{
		//TODO: show import complete panel here
	}
	[[self importWindowController] synchronizeWindowTitleWithDocumentName];
}
@end