/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXAppController.h"

#pragma mark -
#pragma mark Constants

/// What shelf appearance to use. Currently only used by assignGamesFolderURL:.
typedef NS_ENUM(NSInteger, BXShelfAppearance) {
	BXShelfAuto		= -1,
	BXShelfNone		= 0,
	BXShelfDefault	= 1,
	BXShelfWood		= 1,
};

/// Constants for errors concerning the games folder
extern NSErrorDomain const BXGamesFolderErrorDomain;

NS_ERROR_ENUM(BXGamesFolderErrorDomain) {
	BXGamesFolderURLInvalid	//!< A chosen path for the DOS Games folder was not appropriate.
};


#pragma mark -
#pragma mark Interface declaration

/// The \c BXGamesFolder category extends \c BXAppController with functions for setting,
/// finding and styling the games folder.
/// TODO: move this functionality off to a standalone class, as it has nothing to do
/// with the app delegate or its lifecycle.
@interface BXAppController (BXGamesFolder)

#pragma mark -
#pragma mark Properties

/// The path where we store Boxer's games, stored internally as an alias to allow the folder to be moved.
/// Will be nil if no path has been chosen, or the alias could not be resolved.
/// IMPLEMENTATION NOTE: this will detect and import an older games folder from Boxer 0.8x automatically.
@property (copy, nonatomic) NSURL *gamesFolderURL;

/// The icon of the games folder path. This is used for UIs that need to display the games folder.
@property (readonly, nonatomic) NSImage *gamesFolderIcon;

/// The game folder location stored by 0.8x versions of Boxer (stored as an alias at ~/Library/Preferences/Boxer/Default Folder).
/// Will be nil if no path was stored by an older version of Boxer or if the alias could not be resolved.
@property (readonly, nonatomic) NSURL *legacyGamesFolderURL;

/// The 'emergency' location at which to store new gameboxes, when the games folder cannot be found
/// and we don't have the chance to ask the user for a new one. This currently uses the user's Desktop.
@property (readonly, nonatomic) NSURL *fallbackGamesFolderURL;

/// Whether to apply our fancy games-shelf appearance to the games folder each time we open it.
/// Setting this to \c NO will immediately remove all effects from the games folder.
/// The value for this property is persisted in user defaults.
@property (assign, nonatomic) BOOL appliesShelfAppearanceToGamesFolder;

/// Whether we have a games folder location stored in user defaults.
/// (This does not check if the folder actually exists.)
@property (readonly, nonatomic) BOOL gamesFolderChosen;

/// The path to the shelf artwork to use for games folder backgrounds.
/// This will automatically generate the artwork the first time it is needed.
/// Will be nil if the artwork could not be found or created.
@property (readonly, nonatomic) NSURL *shelfArtworkURL;


#pragma mark -
#pragma mark Helper class methods

/// Returns an array of suitable paths for the games folder location.
/// Boxer will look in these locations for existing games folders if it has
/// no record of a specific folder (i.e. if its prefs file has been deleted.)
+ (NSArray<NSURL *> *) commonGamesFolderURLs;

/// Returns the game folder location that will be automatically created
/// when the user launches Boxer for the first time.
+ (NSURL *) preferredGamesFolderURL;

/// Reserved system paths which may not be chosen as the games folder location
/// (though subfolders within these paths may be acceptable.)
+ (NSSet<NSURL *> *) reservedURLs;


#pragma mark -
#pragma mark Games folder handling

/// Reveal our games folder in Finder.
/// This will prompt the user to locate the folder if it is missing,
/// or show the first-run panel if no games folder has been chosen yet.
- (IBAction) revealGamesFolder: (id)sender;


#pragma mark -
#pragma mark Preparing the games folder

/// Set the games folder to the specified URL, and prepare it with the selected options.
/// Returns \c YES if the folder was successfully assigned (and created, if required)
/// and all of the options applied, or \c NO otherwise.
/// If \c createIfMissing is <code>YES</code>, the folder and all its intermediate folders will be created
/// if needed; if \c createIfMissing is \c NO and the folder does not exist, then \c NO will be returned
/// and an error will be given.
- (BOOL) assignGamesFolderURL: (NSURL *)URL
              withSampleGames: (BOOL)addSampleGames
              shelfAppearance: (BXShelfAppearance)applyShelfAppearance
              createIfMissing: (BOOL)createIfMissing
                        error: (out NSError **)outError;

/// Validate and sanitise the specified games folder path.
/// This will return \c NO and populate \c outError if the chosen path was reserved
/// or not writeable by Boxer.
- (BOOL) validateGamesFolderURL: (inout NSURL **)ioValue error: (out NSError **)outError;

#pragma mark -
#pragma mark Customising the games folder

/// Apply our custom shelf appearance to the specified path,
/// and optionally all paths within it that contain gameboxes.
/// If \c switchMode is <code>YES</code>, the folder's Finder window will be switched to icon mode.
- (void) applyShelfAppearanceToURL: (NSURL *)URL
                     andSubFolders: (BOOL)applyToSubFolders
                 switchToShelfMode: (BOOL)switchMode;

/// Remove our custom shelf appearance from the specified path,
/// and optionally all paths within it that contain gameboxes.
- (void) removeShelfAppearanceFromURL: (NSURL *)URL
                        andSubFolders: (BOOL)applyToSubFolders;

/// Copy our sample games into the specified path.
- (void) addSampleGamesToURL: (NSURL *)URL;

/// Display a prompt telling the user their games folder cannot be found, and giving them
/// options to create a new one or cancel. Used by revealGamesFolder and elsewhere.
- (void) promptForMissingGamesFolderInWindow: (NSWindow *)window;
@end

