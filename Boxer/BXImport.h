/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXImport is a BXSession document subclass which manages the importing of a new game
//from start to finish.
//Besides handling the emulator session that runs the game installer, BXImport also
//prepares a new gamebox and manages the drag-drop wizard which bookends (or in many cases
//comprises) the import process.

#import "BXSession.h"
#import "BXOperation.h"
#import "BXOperationDelegate.h"

#pragma mark -
#pragma mark Class constants

//Constants returned by importStage;
enum {
	BXImportWaitingForSourcePath = 0,
	BXImportLoadingSourcePath,
	BXImportWaitingForInstaller,
	BXImportReadyToLaunchInstaller,
	BXImportRunningInstaller,
	BXImportReadyToFinalize,
	BXImportCopyingSourceFiles,
	BXImportCleaningGamebox,
	BXImportFinished
};
typedef NSUInteger BXImportStage;


@class BXImportWindowController;
@class BXFileTransfer;

@interface BXImport : BXSession <BXOperationDelegate>
{
	NSString *sourcePath;
	BXImportWindowController *importWindowController;
	NSArray *installerPaths;
	NSString *preferredInstallerPath;
	
	NSString *rootDrivePath;
	
	BXImportStage importStage;
	BXOperationProgress stageProgress;
	BXFileTransfer *transferOperation;
}

#pragma mark -
#pragma mark Properties

//The window controller which manages the import window, as distinct from the DOS session window.
@property (retain, nonatomic) BXImportWindowController *importWindowController;

//The source path from which we are installing the game.
//This can only be set from confirmSourcePath:
@property (readonly, copy, nonatomic) NSString *sourcePath;

//The range of possible DOS installers to choose from.
@property (readonly, retain, nonatomic) NSArray *installerPaths;

//The path of the installer we recommend. Autodetected whenever installerPaths is set.
@property (readonly, copy, nonatomic) NSString *preferredInstallerPath;


//What stage of the import process we are up to (as a BXImportStage constant.)
@property (readonly, assign, nonatomic) BXImportStage importStage;

//How far through the current stage we have progressed.
//Only relevant during the BXImportLoadingSourcePath and BXImportCopyingSourceFiles stages.
@property (readonly, assign, nonatomic) BXOperationProgress stageProgress;

//The current file copying operation being performed.
//Only relevant during the BXImportCopyingSourceFiles stage.
@property (readonly, retain, nonatomic) BXFileTransfer *transferOperation;


//The display filename of the gamebox, minus extension. Changing this will rename the gamebox file itself.
@property (retain, nonatomic) NSString *gameboxName;


#pragma mark -
#pragma mark Import helper methods

//The UTIs of filetypes we can accept for import.
+ (NSSet *)acceptedSourceTypes;

//Returns whether we can import from the specified path.
- (BOOL) canImportFromSourcePath: (NSString *)sourcePath;

//Whether we should run an installer for our current source path.
//Will be YES if we detected any installers for the source path, NO otherwise.
- (BOOL) gameNeedsInstalling;


#pragma mark -
#pragma mark Import steps

//Selects the specified source path, detects the game's details based on it,
//and continues to the next step of importing.
- (void) importFromSourcePath: (NSString *)path;

//Cancels a previously-specified source path and returns to the source path choice step.
- (void) cancelSourcePath;

//Selects the specified installer and launches it to continue importing.
- (void) launchInstaller: (NSString *)path;

//Skips the installer selection process and continues to the next step of importing.
- (void) skipInstaller;

//Closes the DOS installer process and continues to the next step of importing.
- (void) finishInstaller;

//Copy the source files into the gamebox.
- (void) importSourceFiles;

//Clean up the gamebox and finish the operation.
- (void) cleanGamebox;


#pragma mark -
#pragma mark UI Actions

//Called from DOS session to close down the session and move on to the next step of importing.
- (IBAction) finishImporting: (id)sender;

@end