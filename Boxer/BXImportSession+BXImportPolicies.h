/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXImportPolicies category defines class-level helper methods that Boxer uses to decide
//how to import games.

#import "BXImportSession.h"

#pragma mark -
#pragma mark Class constants


//Source paths whose filesize is larger than this in bytes will be treated
//as CD-sized by isCDROMSizedGameAtPath: and shouldImportSourceFilesFromPath:
static const NSUInteger BXCDROMSizeThreshold  = 100 * 1024 * 1024;

//The free disk space in MB to allow on drive C when installing games from CD-ROM.
static const NSUInteger BXFreeSpaceForCDROMInstall = 700 * 1024 * 1024;

@class BXGamebox;
@class BXEmulatorConfiguration;
@interface BXImportSession (BXImportPolicies)

#pragma mark -
#pragma mark Detecting installers

//Returns a set of known installer name patterns.
+ (NSSet *) installerPatterns;

//Returns a set of likely installer name patterns in order of preference.
+ (NSArray *) preferredInstallerPatterns;

//Returns whether the executable at the specified path is an installer or not.
//Uses +installerPatterns:
+ (BOOL) isInstallerAtPath: (NSString *)path;

//Returns a set of filename patterns whose matching files should be ignored
//altogether when scanning a gamebox for importing. This prevents them showing
//up in the installers list or throwing off the Windows-only game detection.
+ (NSSet *) ignoredFilePatterns;

//Whether the file at the specified path should be skipped.
+ (BOOL) isIgnoredFileAtPath: (NSString *)path;

//Whether the program at the specified path should be ignored in the event of 
//a tiebreaker when resolving whether this is a DOS or Windows game.
+ (BOOL) isInconclusiveDOSProgramAtPath: (NSString *)path;


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

//Returns YES if the game at the specified URL is large enough to be considered a CD-ROM game.
//This is used to determine the free hard disk space allocated for the game's install.
+ (BOOL) isCDROMSizedGameAtURL: (NSURL *)URL;

//Returns the recommended import point for the specified URL.
+ (NSURL *) preferredSourceURLForURL: (NSURL *)URL;

//Returns a recommended installer from the list of possible installers,
//using preferredInstallerPatterns.
+ (NSString *) preferredInstallerFromPaths: (NSArray *)paths;

//Whether we should import the specified source files into a subfolder of drive C,
//or directly into the base folder of drive C.
//This decision is based on whether the source has any executables in its base folder,
//and whether it appears to be configured as a playable game.
+ (BOOL) shouldUseSubfolderForSourceFilesAtURL: (NSURL *)sourceURL;

//Guesses a suitable gamebox name (sans .boxer extension) for the game at the specified URL.
+ (NSString *) gameboxNameForGameAtURL: (NSURL *)URL;

//Searches the specified location for an icon or image suitable to use as box art, and returns
//it as an icon-ready NSImage resource. This will strip out low-res Windows icons but otherwise
//no additional processing (i.e. Boxer's shiny box-art appearance etc.) is applied to the image.
//Returns nil if no suitable art is found.
+ (NSImage *) boxArtForGameAtURL: (NSURL *)URL;

//Returns an (attempt at an) OSX-safe filename from the provided name.
//This will replace /, \ and : characters with dashes, and remove leading dots. 
+ (NSString *) validGameboxNameFromName: (NSString *)name;

//Returns a DOSBox-safe lowercase 8.3 filename from the specified filename.
//This strips out all non-ASCII characters to prevent filename resolution problems at DOSBox's end.
+ (NSString *) validDOSNameFromName: (NSString *)name;


#pragma mark -
#pragma mark Importing pre-existing DOSBox configurations

//Returns whether the file at the specified path is a valid DOSBox configuration file.
//Currently this only checks its file extension, and does not check the contents of the file.
+ (BOOL) isConfigurationFileAtPath: (NSString *)path;

//Returns the most likely configuration file from the specified set.
//HEURISTIC: in the event that multiple configuration files are specified, this returns the one with
//the shortest name. This is intended to handle e.g. GOG games that come with client/server
//configurations as well as standalone configurations, where the former have "_client"/"_server"
//suffixes applied to the base name of the latter.
+ (NSURL *) preferredConfigurationFileFromURLs: (NSArray *)URLs;

//Returns a new DOSBox configuration cherry-picked from the specified configuration.
//This will strip out all settings that are redundant, or that will interfere with Boxer.
//The resulting configuration will have no autoexec commands.
+ (BXEmulatorConfiguration *) sanitizedVersionOfConfiguration: (BXEmulatorConfiguration *)configuration;

//Returns an array of just the mount commands in the specified configuration's autoexec.
+ (NSArray *) mountCommandsFromConfiguration: (BXEmulatorConfiguration *)configuration;

//Returns an array of the commands in the specified configuration's autoexec that are
//responsible for launching the game and that should hence be bundled into a launcher batchfile.
//This excludes mount commands and 'junk' like echo, rem, cls and exit.
+ (NSArray *) launchCommandsFromConfiguration: (BXEmulatorConfiguration *)configuration;

@end
