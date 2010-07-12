/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXPackage represents a single Boxer gamebox and offers methods for retrieving and persisting
//bundled drives, configuration files, documentation and target programs. It is based on NSBundle
//but does not require that Boxer gameboxes use any standard OS X bundle folder structure.
//(and indeed, gameboxes with a standard OS X bundle structure haven't been tested.)

//TODO: it is inappropriate to subclass NSBundle for representing a modifiable file package,
//and we should instead be using an NSFileWrapper directory wrapper.

#import <Cocoa/Cocoa.h>

@interface BXPackage : NSBundle
{
	NSArray *documentation;
	NSArray *executables;
	NSString *targetPath;
	NSMutableDictionary *generatedDict;
	BOOL checkedForPlist;
}

#pragma mark -
#pragma mark Properties

//Re-casts the return value as a BXPackage instead of an NSBundle
+ (BXPackage *)bundleWithPath: (NSString *)path;

//An array of absolute file paths to documentation files found inside the gamebox.
@property (retain) NSArray *documentation;

//An array of absolute file paths to DOS executables found inside the gamebox.
@property (retain) NSArray *executables;

//The path to the default executable for this gamebox.
@property (copy) NSString *targetPath;

//The cover art image for this gamebox. Will be nil if the gamebox has no custom cover art.
//This is currently stored as the gamebox's OS X icon resource.
@property (copy) NSImage *coverArt;


+ (NSArray *) documentationTypes;		//UTIs recognised as documentation files.
+ (NSArray *) documentationExclusions;	//Filename patterns for documentation to exclude from searches.
+ (NSArray *) executableExclusions;		//Filename patterns for executables to exclude from searches.

//The path to the DOS game's base folder. Currently this is equal to [NSBundle bundlePath].
//TODO: if there is a separately-bundled drive C, this should be returned instead!
- (NSString *) gamePath;


//Set/get the custom DOSBox configuration file for this package. configurationFile will be nil if one does not
//exist yet, and any existing configuration file can be deleted by passing nil to setConfigurationFile:.
- (NSString *) configurationFile;
- (void) setConfigurationFile: (NSString *)filePath;

//Returns the path at which the configuration file is located - or would be, if it doesn’t exist.
- (NSString *) configurationFilePath;


//Arrays of paths to additional DOS drives discovered within the package.
- (NSArray *) hddVolumes;
- (NSArray *) cdVolumes;
- (NSArray *) floppyVolumes;
- (NSArray *) volumesOfTypes: (NSArray *)fileTypes;

@end
