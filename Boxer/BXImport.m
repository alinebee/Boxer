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
#import "BXAppController.h"
#import "BXGameProfile.h"


#pragma mark -
#pragma mark Private method declarations

@interface BXImport ()
@property (readwrite, retain, nonatomic) NSArray *installerPaths;
@property (readwrite, copy, nonatomic) NSString *sourcePath;
@property (readwrite, copy, nonatomic) NSString *preferredInstallerPath;
@property (readwrite, assign, nonatomic) BOOL thinking;

//Populates game profile, available installers and preferred installer based on game at specified path.
//Called in setSourcePath: to autodetect game properties after choosing a new path.
- (void) _detectGameFromPath: (NSString *)path;

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
		acceptedTypes = [[BXAppController mountableTypes] retain];
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

- (void) confirmSourcePath: (NSString *)path
{
	if (path)
	{
		[self setSourcePath: path];
		
		//Upon choosing a source path: detect its game profile, available installers and preferred installer
		[self _detectGameFromPath: path];
		
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
}

- (void) _detectGameFromPath: (NSString *)path
{
	[self setThinking: YES];
	
	BXGameProfile *detectedProfile	= nil;
	NSArray *detectedInstallers		= nil;
	
	if (path)
	{
		detectedProfile		= [BXGameProfile detectedProfileForPath: path searchSubfolders: YES];
		detectedInstallers	= [[self class] installersAtPath: path recurse: YES];
	}

	[self setGameProfile: detectedProfile];
	[self setInstallerPaths: detectedInstallers];
	
	[self setThinking: NO];
}

- (void) setInstallerPaths: (NSArray *)paths
{
	if (paths != installerPaths)
	{
		[installerPaths release];
		installerPaths = [paths retain];
		
		//Detect a new preferred installer from among these paths
		[self setPreferredInstallerPath: [[self class] preferredInstallerFromPaths: installerPaths]];
	}
}
@end