/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <AppKit/AppKit.h>

//BXImportSourceScan scans a specified source folder for DOS executables.
//It is used by BXImportSession readURL:error: for determining available installers.
//This is moved to an operation so that it can be done without blocking the main thread.


@interface BXImportSourceScan : NSOperation
{
	NSString *sourcePath;
	
	NSMutableArray *executables;
	NSMutableArray *windowsExecutables;
	NSMutableArray *installers;
	
	NSFileManager *manager;
	NSWorkspace *workspace;
	
	BOOL preInstalledGame;
}
@property (copy) NSString *sourcePath;

//Executables of various types located by the operation.
//Populated as the operation continues, but for thread safety
//should only be checked once the operation finishes.
@property (readonly) NSArray *executables;
@property (readonly) NSArray *windowsExecutables;
@property (readonly) NSArray *installers;

//Whether the specified path represents a game or application recognisable by Boxer.
//Only valid once the operation has finished.
@property (readonly) BOOL compatibleWithBoxer;

//Whether the specified path represents a pre-installed game.
@property (readonly, getter=isPreInstalledGame) BOOL preInstalledGame;

//Whether the specified source path represents a Windows-only game or application.
//Only valid once the operation has finished.
@property (readonly, getter=isWindowsOnly) BOOL windowsOnly;


//Create a new scan operation for the specified path.
- (id) initWithSourcePath: (NSString *)sourcePath;

@end
