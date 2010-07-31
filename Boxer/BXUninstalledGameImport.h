/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXUninstalledGameImport is a BXGameImport subclass for handling games that need
//to be installed by a DOS installer before they are playable: e.g. games on a CD-ROM,
//floppy disk or disc image.

//This import process creates an empty gamebox at the destination path, copies the source
//files into it as a CD-ROM drive if desired, and then launches a specified DOS installer
//to install the game itself.

#import "BXGameImport.h"

@interface BXUninstalledGameImport : BXGameImport
{
	NSString *installerPath;
	NSArray *detectedInstallers;
	BOOL importSourceFiles;
}

#pragma mark -
#pragma mark Properties

//The path to the DOS installer program to run when installing this game.
@property (copy, nonatomic) NSString *installerPath;

//Whether the source path should be imported into the gamebox as a new drive.
@property (assign, nonatomic) BOOL importSourceFiles;

//An array of NSDictionaries representing DOS installers detected within the source path.
//These take the form {@"path": NSString, @"recommended": BOOL}, where "recommended" is
//whether this installer is likely to be the intended installer for the game.
@property (readonly, retain, nonatomic) NSArray *detectedInstallers;


#pragma mark -
#pragma mark Helper class methods

//Returns a list of installer name patterns, in order of preference.
+ (NSArray *) preferredInstallerPatterns;

//Whether the source files at the specified path should be imported into the gamebox
//as a CD-ROM drive. This decision is based on the volume type of the path and whether
//its contents are large enough to be a CD.
+ (BOOL) shouldImportSourceFilesFromPath: (NSString *)path;

@end