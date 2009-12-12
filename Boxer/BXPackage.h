/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXPackage represents a single Boxer gamebox and offers methods for retrieving and persisting
//bundled drives, configuration files, documentation and target programs. It is based on NSBundle
//but does not require that Boxer gameboxes use any standard OS X bundle folder structure.

#import <Cocoa/Cocoa.h>

@interface BXPackage : NSBundle
{
	NSArray *documentation;
	NSArray *executables;
}
//An array of absolute file paths to documentation files found inside the gamebox.
@property (retain) NSArray *documentation;

//An array of absolute file paths to DOS executables found inside the gamebox.
@property (retain) NSArray *executables;


+ (NSArray *) hddVolumeTypes;		//UTIs recognised as Boxer hard drive resources.
+ (NSArray *) cdVolumeTypes;		//UTIs recognised as Boxer CD-ROM drive resources.
+ (NSArray *) floppyVolumeTypes;	//UTIs recognised as Boxer floppy drive resources.
+ (NSArray *) documentationTypes;	//UTIs recognised as documentation files.

+ (NSArray *) documentationExclusions;	//Filename patterns for documentation to exclude from searches.
+ (NSArray *) executableExclusions;		//Filename patterns for executables to exclude from searches.


//The cover art image for this gamebox, or nil if the gamebox has no custom cover art.
//This is currently stored as the gamebox's OS X icon resource.
- (NSImage *) coverArt;
- (void) setCoverArt: (NSImage *)image;

//The path to the default DOS program to launch when the gamebox is opened, or nil if one has not been chosen.
//This is currently stored as a symlink in the base folder of the gamebox.
- (NSString *) targetPath;
- (void) setTargetPath: (NSString *)path;

//The path to the custom configuration file for this package, or nil if one does not exist.
//This is currently read-only.
- (NSString *) configurationPath;

//The path to the DOS game's base folder. Currently this is equal to [NSBundle bundlePath]. 
- (NSString *) gamePath;

//Arrays of paths to additional DOS drives discovered within the package.
- (NSArray *) hddVolumes;
- (NSArray *) cdVolumes;
- (NSArray *) floppyVolumes;
- (NSArray *) volumesOfTypes: (NSArray *)fileTypes;

@end

@interface BXPackage (BXPackageInternals)
//Arrays of paths to discovered files of particular types within the gamebox.
//BXPackage's documentation and executables accessors call these internal methods and cache the results.
- (NSArray *) _foundDocumentation;
- (NSArray *) _foundExecutables;
- (NSArray *) _foundResourcesOfTypes: (NSArray *)fileTypes startingIn: (NSString *)basePath;
@end