/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXGamesFolder category extends BXAppController with functions for setting, finding and 
//styling the games folder.

#import "BXAppController.h"


//What shelf appearance to use. Currently only used by assignGamesFolderPath.
enum BXShelfTypes {
	BXShelfAuto		= -1,
	BXShelfNone		= 0,
	BXShelfDefault	= 1,
	BXShelfWood		= 1
};

typedef NSInteger BXShelfAppearance;


@interface BXAppController (BXGamesFolder)

#pragma mark -
#pragma mark Properties

//The path where we store Boxer's games, stored internally as an alias to allow the folder to be moved.
//Will be nil if no path has been chosen, or the alias could not be resolved.
//IMPLEMENTATION NOTE: this will detect and import an older games folder from Boxer 0.8x automatically.
@property (copy, nonatomic) NSString *gamesFolderPath;

//The icon of the games folder path. This is used for UIs that need to display the games folder.
@property (readonly, nonatomic) NSImage *gamesFolderIcon;

//The game folder path from 0.8x versions of Boxer (stored as an alias at ~/Library/Preferences/Boxer/Default Folder).
//Will be nil if no path was stored by an older version of Boxer, or if the alias could not be resolved.
@property (readonly, nonatomic) NSString *oldGamesFolderPath;

//The 'emergency' path at which to store new gameboxes, used when the games folder cannot be found
//and we don't have the chance to ask the user for a new one. This is currently set to the user's Desktop.
@property (readonly, nonatomic) NSString *fallbackGamesFolderPath;

//Whether to apply our fancy games-shelf appearance to the games folder each time we open it.
//Setting this to NO will immediately remove all effects from the games folder.
//The value for this property is persisted in user defaults.
@property (assign, nonatomic) BOOL appliesShelfAppearanceToGamesFolder;

//Returns whether we have a games folder preference.
//This does not check if the folder actually exists.
@property (readonly, nonatomic) BOOL gamesFolderChosen;


#pragma mark -
#pragma mark Helper class methods

//Returns an array of suggested default paths for the games folder location
//(which may or may not already exist) for selection when Boxer is first launched.
+ (NSArray *) defaultGamesFolderPaths;

#pragma mark -
#pragma mark Games folder handling

//Reveal our games folder in Finder.
//This will prompt the user to locate the folder if it is missing,
//or show the first-run panel if no games folder has been chosen yet.
- (IBAction) revealGamesFolder: (id)sender;


#pragma mark -
#pragma mark Preparing the games folder

//Imports a games folder from a previous version of Boxer.
//This freshens the folder and autodetects the presence of old
//background art, enabling the shelf background if it is found.
//Returns YES if successful, NO if the folder could not be found.
- (BOOL) importOldGamesFolderFromPath: (NSString *)path;

//Set the games folder and prepare it with the selected options.
//This is the main point from which the rest of Boxer can set the folder path.
- (void) assignGamesFolderPath: (NSString *)newPath
			   withSampleGames: (BOOL)addSampleGames
			   importerDroplet: (BOOL)addImporterDroplet
			   shelfAppearance: (BXShelfAppearance)applyShelfAppearance;


#pragma mark -
#pragma mark Customising the games folder

//Apply our custom shelf appearance to the specified path.
//If switchMode is YES, the folder's Finder window will be switched to icon mode.
- (void) applyShelfAppearanceToPath: (NSString *)path switchToShelfMode: (BOOL)switchMode;

//Remove our custom shelf appearance from the specified path.
- (void) removeShelfAppearanceFromPath: (NSString *)path;

//Copy our sample games into the specified path.
- (void) addSampleGamesToPath: (NSString *)path;

//Adds an Drop Games to Import droplet to the specified folder, replacing any
//older version if one is found.
- (void) addImporterDropletToPath: (NSString *)folderPath;

//Check for the existence of the game importer droplet in the specified folder,
//replacing any outdated versions. If addIfMissing is true, a new droplet will
//be added if one is not found.
- (void) freshenImporterDropletAtPath: (NSString *)folderPath addIfMissing: (BOOL)addIfMissing;

//Display a prompt telling the user their games folder cannot be found, and giving them
//options to create a new one or cancel. Used by revealGamesFolder and elsewhere.
- (void) promptForMissingGamesFolderInWindow: (NSWindow *)window;
@end


//Add sample games to the specified path, as a fire-and-forget copy.
//Used by BXAppController+BXGamesFolder addSampleGamesToPath:
@interface BXSampleGamesCopy : NSOperation
{
	NSString *targetPath;
	NSString *sourcePath;
	NSFileManager *manager;
	NSWorkspace *workspace;
}
@property (copy) NSString *targetPath;
@property (copy) NSString *sourcePath;

//Create a new copy operation from the specified source path to the specified path.
- (id) initFromPath: (NSString *)source toPath: (NSString *)target;
@end


//Checks if one of our helper apps is present and up-to-date at the specified path.
//Used by BXAppController+BXGamesFolder freshenImporterDroplet:addIfMissing:.
@interface BXHelperAppCheck : NSOperation
{
	NSString *targetPath;
	NSString *appPath;
	NSFileManager *manager;
	BOOL addIfMissing;
}
@property (copy) NSString *targetPath;
@property (copy) NSString *appPath;
@property (assign) BOOL addIfMissing;

//Create a new app check for the specified path using the specified droplet.
- (id) initWithTargetPath: (NSString *)pathToCheck forAppAtPath: (NSString *)pathToApp;
@end