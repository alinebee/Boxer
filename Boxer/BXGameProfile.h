/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXGameProfile represents a detected game profile, which describes the game for gamebox creation
//and specifies custom DOSBox configuration and emulation behaviour.
//It has helper class methods for detecting a game profile from a filesystem path, and for
//determining the 'era' of a particular game at a filesystem path.


#import <Foundation/Foundation.h>

@class BXDrive;

#pragma mark -
#pragma mark Constants

//Constants used by eraOfGameAtPath:
enum {
	BXUnknownEra = 0,
	BX525DisketteEra,
	BX35DisketteEra,
	BXCDROMEra
};
typedef NSUInteger BXGameEra;


@interface BXGameProfile : NSObject
{
	NSString *gameName;
	NSString *confName;
	NSString *profileDescription;
	NSDictionary *driveLabelMappings;
	NSArray *installerPatterns;
	
	BOOL installsFromFloppyDrive;
}

#pragma mark -
#pragma mark Properties

//The human-readable name of the game this profile represents.
//Will be nil for shared profiles (in which case profileDescription will be available.) 
@property (copy) NSString *gameName;

//The configuration file for this game (sans .conf extension), as stored in Resources/Configurations
@property (copy) NSString *confName;

//The description of what kind of games this game profile covers.
//Will be nil for game-specific profiles (in which case gameName will be available.)
@property (copy) NSString *profileDescription;

//Whether this game needs to be installed from floppy disks.
//When YES, the import process will mount the game’s source files as a floppy drive instead of a CD-ROM.
@property (assign) BOOL installsFromFloppyDrive;


#pragma mark -
#pragma mark Helper class methods

//Returns an array of generic profiles that match multiple games.
//This corresponds the contents of the BXGenericProfiles key in GameProfiles.plist.
+ (NSArray *) genericProfiles;

//Returns an array of game profiles identifying specific games.
//This corresponds the contents of the BXSpecificGameProfiles key in GameProfiles.plist.
+ (NSArray *) specificGameProfiles;

//Returns the game era that the contents of the specified file path look like, based on filesize
//and age of files. This is used by BXDockTileController to decide which bootleg coverart style to use.
+ (BXGameEra) eraOfGameAtPath: (NSString *)basePath;


#pragma mark -
#pragma mark Initializers

//Detects and returns an appropriate game profile for the specified path,
//by scanning for telltale files in the file heirarchy starting at basePath.
//If searchSubfolders is false, only the base path will be scanned without
//recursing into subfolders.
+ (BXGameProfile *) detectedProfileForPath: (NSString *)basePath searchSubfolders: (BOOL) searchSubfolders;

//Creates a new profile from the specified GameProfiles.plist-format dictionary.
- (id) initWithDictionary: (NSDictionary *)profileDictionary;

#pragma mark -
#pragma mark Methods affecting emulation behaviour

//Returns an customised drive label for the specified drive.
- (NSString *) labelForDrive: (BXDrive *)drive;

//Returns whether the file at the specified path is the designated installer for this game.
- (BOOL) isDesignatedInstallerAtPath: (NSString *)path;

@end
