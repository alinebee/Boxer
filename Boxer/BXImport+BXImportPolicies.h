/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXImportPolicies category defines class-level helper methods that Boxer uses to decide
//how to import games.

#import "BXImport.h"

#pragma mark -
#pragma mark Class constants


//Source paths whose filesize is larger than this in bytes will be treated
//as CD-sized by shouldImportSourceFilesFromPath:
#define BXCDROMSizeThreshold 100 * 1024 * 1024


@interface BXImport (BXImportPolicies)

#pragma mark -
#pragma mark Detecting installers

//Returns a list of known installer name patterns.
+ (NSSet *) installerPatterns;

//Returns a list of likely installer name patterns in order of preference.
+ (NSArray *) preferredInstallerPatterns;

//Returns whether the executable at the specified path is an installer or not.
//Uses +installerPatterns:
+ (BOOL) isInstallerAtPath: (NSString *)path;


#pragma mark -
#pragma mark Detecting files not to import

//A set of regex patterns matching files that should be cleaned out of an imported game.
+ (NSSet *) junkFilePatterns;

//Returns whether the file at the specified path should be discarded when importing.
//Uses +junkFilePatterns.
+ (BOOL) isJunkFileAtPath: (NSString *)path;


#pragma mark -
#pragma mark Detecting whether a game is already installed

//A set of regex patterns matching files that indicate the game is installed and playable.
+ (NSSet *) playableGameTelltalePatterns;

//A set of filename extensions whose presence indicates the game is installed and playable.
+ (NSSet *) playableGameTelltaleExtensions;

//Returns whether the file at the specified path is a telltale for an installed and playable game.
//Uses playableGameTelltaleExtensions and playableGameTelltalePatterns, in that order.
+ (BOOL) isPlayableGameTelltaleAtPath: (NSString *)path;


#pragma mark -
#pragma mark Deciding how best to import a game

//Returns a list of all executables found within the specified path.
//If scanSubdirs is NO, the search will be restricted to the base path.
+ (NSArray *) executablesAtPath: (NSString *)path recurse: (BOOL)scanSubdirs;

//Returns a recommended installer from the list of possible installers,
//using preferredInstallerPatterns.
+ (NSString *) preferredInstallerFromPaths: (NSArray *)paths;

//Whether the source files at the specified path should be made into a fake CD-ROM for the game.
//This decision is based on the size of the files and the volume type of the path.
+ (BOOL) shouldImportSourceFilesFromPath: (NSString *)path;

//Returns a suitable name (sans .boxer extension) for the game at the specified path.
//This is based on the last path component of the source path, cleaned up.
+ (NSString *) nameForGameAtPath: (NSString *)path;

//Returns any artwork found for the game at the specified path.
//No additional processing (box-art appearance etc.) is done on the image.
//Will be nil if no suitable art is found.
+ (NSImage *) boxArtForGameAtPath: (NSString *)path;

@end
