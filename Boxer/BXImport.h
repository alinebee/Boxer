/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXImport is a BXSession document subclass which manages the importing of a new game
//from start to finish.
//Besides handling the emulator session that runs the game installer, BXImport also
//prepares a new gamebox and manages the drag-drop wizard which bookends (or in many cases
//comprises) the import process.

#import "BXSession.h"


@class BXImportWindowController;

@interface BXImport : BXSession
{
	NSString *sourcePath;
	BXImportWindowController *importWindowController;
}

#pragma mark -
#pragma mark Properties

//The window controller which manages the import window, as distinct from the DOS session window.
@property (retain, nonatomic) BXImportWindowController *importWindowController;

//The source path from which we are installing the game.
@property (copy, nonatomic) NSString *sourcePath;

//The range of possible DOS installers to choose from.
//(The chosen installer is represented by targetPath.)
@property (readonly, nonatomic) NSArray *installerPaths;

@end