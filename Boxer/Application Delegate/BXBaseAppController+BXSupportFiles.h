/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXApplicationModes category extends BXAppController with functions
//for managing Boxer's various Application Support files.

#import "BXBaseAppController.h"

@class BXGamebox;
@interface BXBaseAppController (BXSupportFiles)

#pragma mark -
#pragma mark Supporting directories

//Returns Boxer's default location for screenshots and other recordings.
//If createIfMissing is YES, the folder will be created if it does not exist.
- (NSString *) recordingsPathCreatingIfMissing: (BOOL)createIfMissing;

//Returns Boxer's application support path.
//If createIfMissing is YES, the folder will be created if it does not exist.
- (NSString *) supportPathCreatingIfMissing: (BOOL)createIfMissing;

//Returns the path to the application support folder where Boxer should
//store state data for the specified gamebox.
//If createIfMissing is YES, the folder will be created if it does not exist.
- (NSString *) statesPathForGamebox: (BXGamebox *)gamebox
                  creatingIfMissing: (BOOL) createIfMissing;

//Returns the path to the application support folder where Boxer keeps MT-32 ROM files.
//If createIfMissing is YES, the folder will be created if it does not exist.
- (NSString *) MT32ROMPathCreatingIfMissing: (BOOL)createIfMissing;


#pragma mark -
#pragma mark ROM management

//Returns the path to the requested ROM file, or nil if it is not present.
- (NSString *) pathToMT32ControlROM;
- (NSString *) pathToMT32PCMROM;

//Copies the specified ROM into the application support folder,
//making it accessible via the respective path method above.
//Returns YES if the ROM was imported successfully, NO and populates
//NSError if the ROM could not be imported or was invalid.
- (BOOL) importMT32ControlROM: (NSString *)ROMPath error: (NSError **)outError;
- (BOOL) importMT32PCMROM: (NSString *)ROMPath error: (NSError **)outError;

//When given an array of file paths, scans them for valid ROMs and imports
//the first pair it finds. Recurses into any folders in the list.
//Returns YES if one or more ROMs were imported, or NO and populates outError
//if there was a problem (including if the paths did not contain any MT-32 ROMs.)
- (BOOL) importMT32ROMsFromPaths: (NSArray *)paths error: (NSError **)outError;

//Validate that the ROM at the specified path is valid and suitable for use by Boxer.
- (BOOL) validateMT32ControlROM: (NSString **)ioValue error: (NSError **)outError;
- (BOOL) validateMT32PCMROM: (NSString **)ioValue error: (NSError **)outError;

@end
