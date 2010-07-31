/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXPlayableGameImport is a BXGameImport subclass for handling games that are
//already installed and ready-to-play: e.g. most downloaded games.

//This import process copies the files from the source path into a new gamebox at the
//destination path. It will also sanitise the files to remove typical 'leftovers'
//from prepared game folders: such as DOSBox files and configurations.

#import "BXGameImport.h"

@interface BXPlayableGameImport : BXGameImport
{
	NSString *containingFolderPath;
}

#pragma mark -
#pragma mark Properties

//The path, relative to the gamebox's C drive, into which to copy the source path.
//If empty or nil, the files will be placed in the root of the C drive.
@property (copy, nonatomic) NSString *containingFolderPath;


#pragma mark -
#pragma mark Helper class methods

//A set of regex patterns matching files that should be cleaned out of an imported game.
+ (NSSet *) junkFilePatterns;

//Detects the appropriate containing folder path (relative to drive C) in which
//the game's source files should be stored. This will be @"" if the source path
//should be copied to the root of C drive.
+ (NSString *) containingFolderPathForGameAtPath: (NSString *)path;

@end