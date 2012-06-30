/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXPackage represents a single Boxer gamebox and offers methods for retrieving and persisting
//bundled drives, configuration files and documentation. It is based on NSBundle but does not
//require that Boxer gameboxes use any standard OS X bundle folder structure.
//(and indeed, gameboxes with an OS X bundle structure haven't been tested.)

//TODO: it is inappropriate to subclass NSBundle for representing a modifiable file package,
//and we should instead be using an NSFileWrapper directory wrapper.

#import <Cocoa/Cocoa.h>


#pragma mark Gamebox-related error constants

extern NSString * const BXGameboxErrorDomain;
enum {
	BXTargetPathOutsideGameboxError
};


#pragma mark -
#pragma mark Constants

//The gameInfo key under which we store the game's identifier.
//Will be an NSString.
extern NSString * const BXGameIdentifierKey;

//The gameInfo key under which we store the type of the game's identifier.
//Will be an NSNumber of BXGameIdentifierTypes.
extern NSString * const BXGameIdentifierTypeKey;

//The gameInfo key under which we store the default program path,
//relative to the base folder of the gamebox.
extern NSString * const BXTargetProgramKey;

//The gameInfo key under which we store the close-on-exit toggle flag as an NSNumber.
extern NSString * const BXCloseOnExitKey;

//The filename of the symlink pointing to the gamebox's target executable.
//No longer used.
extern NSString * const BXTargetSymlinkName;



//The filename and extension of the gamebox configuration file.
extern NSString * const BXConfigurationFileName;
extern NSString * const BXConfigurationFileExtension;

//The filename and extension of the game info manifest inside the gamebox.
extern NSString * const BXGameInfoFileName;
extern NSString * const BXGameInfoFileExtension;

//The filename of the documentation folder inside the gamebox.
extern NSString * const BXDocumentationFolderName;


//The different kinds of game identifiers we can have.
enum {
	BXGameIdentifierUserSpecified	= 0,	//Manually specified type.
	BXGameIdentifierUUID			= 1,	//Standard UUID. Generated for empty gameboxes.
	BXGameIdentifierEXEDigest		= 2,	//SHA1 digest of each EXE file in the gamebox.
};
typedef NSUInteger BXGameIdentifierType;


#pragma mark -
#pragma mark Interface

@interface BXPackage : NSBundle
{
	NSMutableDictionary *_gameInfo;
}

#pragma mark -
#pragma mark Properties

//Returns a dictionary of gamebox metadata loaded from Boxer.plist.
//Keys in this can also be retrieved with objectForInfoDictionaryKey: and set with setObjectForInfoDictionaryKey:
//(They cannot be set directly on gameInfo.)
@property (readonly, retain, nonatomic) NSDictionary *gameInfo;

//The path to the DOS game's base folder. Currently this is equal to [NSBundle bundlePath].
@property (readonly, nonatomic) NSString *gamePath;

//The name of the game, suitable for display. This is the gamebox's filename minus any ".boxer" extension.
@property (readonly, nonatomic) NSString *gameName;

//The unique identifier of this game.
@property (copy, nonatomic) NSString *gameIdentifier;


//An array of absolute file paths to documentation files found inside the gamebox.
@property (readonly, nonatomic) NSArray *documentation;

//An array of absolute file paths to DOS executables found inside the gamebox.
@property (readonly, nonatomic) NSArray *executables;

//Arrays of paths to additional DOS drives discovered within the package.
@property (readonly, nonatomic) NSArray *hddVolumes;
@property (readonly, nonatomic) NSArray *cdVolumes;
@property (readonly, nonatomic) NSArray *floppyVolumes;

//Returns the path at which the configuration file is located (or would be, if it doesn’t exist.)
@property (readonly, nonatomic) NSString *configurationFilePath;


//The path to the DOSBox configuration file for this package. Will be nil if one does not exist.
@property (readonly, nonatomic) NSString *configurationFile;

//The path to the default executable for this gamebox. Will be nil if the gamebox has no target executable.
@property (copy, nonatomic) NSString *targetPath;

//Whether the emulation should finish once the target program exits, rather than returning to the DOS prompt.
@property (assign, nonatomic) BOOL closeOnExit;

//The cover art image for this gamebox. Will be nil if the gamebox has no custom cover art.
//This is stored internally as the gamebox's OS X icon resource.
@property (copy, nonatomic) NSImage *coverArt;


#pragma mark -
#pragma mark Class methods

//Re-casts the return value as a BXPackage instead of an NSBundle
+ (BXPackage *)bundleWithPath: (NSString *)path;


+ (NSSet *) documentationTypes;			//UTIs recognised as documentation files.
+ (NSSet *) documentationExclusions;	//Filename patterns for documentation to exclude from searches.
+ (NSSet *) executableExclusions;		//Filename patterns for executables to exclude from searches.


#pragma mark -
#pragma mark Instance methods

//Returns whether the specified path is valid to be the default target of this gamebox
- (BOOL) validateTargetPath: (id *)ioValue error: (NSError **)outError;

//Retrieve all volumes matching the specified filetypes.
- (NSArray *) volumesOfTypes: (NSSet *)fileTypes;

//Get/set metadata in the gameInfo dictionary.
- (id) gameInfoForKey: (NSString *)key;
- (void) setGameInfo: (id)info forKey: (NSString *)key;

//Clear resource caches for documentation, gameInfo and executables.
- (void) refresh;

@end