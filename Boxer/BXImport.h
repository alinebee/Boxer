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


@class BXImportWindowController;

@interface BXImport : BXSession
{
	NSString *sourcePath;
	BXImportWindowController *importWindowController;
	NSArray *installerPaths;
	NSString *preferredInstallerPath;
	
	BOOL hasSkippedInstaller;
	BOOL hasCompletedInstaller;
	BOOL hasFinalisedGamebox;
	
	BOOL thinking;
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

//Flags for how far through the gamebox process we are
@property (readonly, nonatomic) BOOL hasConfirmedSourcePath;
@property (readonly, nonatomic) BOOL hasConfirmedInstaller;
@property (readonly, nonatomic) BOOL hasSkippedInstaller;
@property (readonly, nonatomic) BOOL hasCompletedInstaller;
@property (readonly, nonatomic) BOOL hasFinalisedGamebox;

//Will be YES when we are engaged in a lengthy detection process.
@property (readonly, assign, nonatomic, getter=isThinking) BOOL thinking;


#pragma mark -
#pragma mark Import helper methods

//The UTIs of filetypes we can accept for import.
+ (NSSet *)acceptedSourceTypes;

//Returns whether we can import from the specified path.
- (BOOL) canImportFromSourcePath: (NSString *)sourcePath;


#pragma mark -
#pragma mark Import steps

//Selects the specified source path, detects the game's details based on it,
//and continues to the next step of importing.
- (void) importFromSourcePath: (NSString *)path;

//Cancels a previously-specified source path and returns to the source path choice step.
- (void) cancelSourcePath;

//Selects the specified installer path and launches it to continue importing.
- (void) confirmInstaller: (NSString *)path;

//Skips the installer selection process and continues to the next step of importing.
- (void) skipInstaller;

@end