/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXGameImport is an abstract base class for a collection of import operations that stage-manage
//the conversion of a source folder into a gamebox.

//There are several alternative ways to import a game, each represented by a BXGameImport subclass;
//The initialization of a BXGameImport instance will detect the appropriate import operation for the
//specified source path and return the corresponding subclass, rather than an instance of the base class.


#import "BXOperation.h"

#pragma mark -
#pragma mark Class constants

//BXImportStage constants. Returned by @importStage and supplied by
//beginImportWithDelegate: in its progress callbacks.
enum {
	BXImportReady				= 0,
	BXImportPreflight			= 1,
	BXImportPreparingGamebox	= 2,
	BXImportCopyingSourceFiles	= 3,
	BXImportCleaningSourceFiles	= 4,
	BXImportRunningInstaller	= 5,
	BXImportFinished			= 6,
};
typedef NSUInteger BXImportStage;

//BXInstallStatus constants. Returned by statusOfGameAtPath:
enum {
	BXGameStatusUninstallable			= -1,
	BXInstallStatusUnknown				= 0,
	BXInstallStatusNotInstalled			= 1,
	BXInstallStatusProbablyNotInstalled	= 2,
	BXInstallStatusProbablyInstalled	= 3,
	BXInstallStatusInstalled			= 4
};
typedef NSUInteger BXInstallStatus;


#pragma mark -
#pragma mark Interface declaration

@class BXGameProfile;
@class NSImage;

@interface BXGameImport : BXOperation
{
	NSString *sourcePath;
	NSString *destinationPath;
	BXGameProfile *gameProfile;
	NSImage *gameIcon;
	BXImportStage stage;
}

#pragma mark -
#pragma mark Properties

//The full path to the source folder to install. This cannot be modified,
//only set at initialization time, since the source files determine what
//kind of importer class should be created.
@property (readonly, copy, nonatomic) NSString *sourcePath;

//The full destination path of the gamebox to create,
//including the gamebox name and extension.
@property (copy, nonatomic) NSString *destinationPath;

//The auto-detected game profile for this source path.
@property (retain, nonatomic) BXGameProfile *gameProfile;

//The file icon to apply to the created gamebox.
//If nil, the default gamebox icon will be used.
@property (copy, nonatomic) NSImage *gameIcon;

//The current stage of the import operation.
//Will be BXImportReady if the import has not been started yet.
@property (readonly, nonatomic) BXImportStage stage;


#pragma mark -
#pragma mark Helper class methods

//Returns a BXInstallStatus value, indicating how sure we are about the
//installation status of the game at the specified path.
+ (BXInstallStatus) installStatusOfGameAtPath: (NSString *)path;

//Returns a suitable name (sans .boxer extension) for the game at the specified path.
//This is based on the last path component of the source path.
+ (NSString *) nameForGameAtPath: (NSString *)path;

//Returns a suitable gamebox icon for the game at the specified path.
//Will be nil if no suitable icon is found.
+ (NSImage *) iconForGameAtPath: (NSString *)path;


#pragma mark -
#pragma mark Initializers

//Returns a new game importer from the specified source path. This will return
//a BXGameImport subclass, not an instance of BXGameImport itself.
//The destination path will be set automatically to the default Boxer game folder,
//plus the detected gamebox name. (See + nameForGameAtPath:withProfile:)
+ (id) importerWithSourcePath: (NSString *)path;
- (id) initWithSourcePath: (NSString *)path;

//Same as above, but with a specific destination path.
+ (id) importerWithSourcePath: (NSString *)path destinationPath: (NSString *)path;
- (id) initWithSourcePath: (NSString *)path destinationPath: (NSString *)path;

@end