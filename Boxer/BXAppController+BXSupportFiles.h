/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXApplicationModes category extends BXAppController with functions
//for managing Boxer's various Application Support files.

#import "BXAppController.h"


@interface BXAppController (BXSupportFiles)

#pragma mark -
#pragma mark Supporting directories

//Returns Boxer's application support path.
//If createIfMissing is YES, the folder will be created if it does not exist.
+ (NSString *) supportPathCreatingIfMissing: (BOOL)createIfMissing;

//Returns Boxer's temporary folder path.
//This will be automatically deleted when all Boxer processes exit.
//If createIfMissing is YES, the folder will be created if it does not exist.
+ (NSString *) temporaryPathCreatingIfMissing: (BOOL)createIfMissing;

//Returns the path to the application support folder where Boxer keeps MT-32 ROM files.
//If createIfMissing is YES, the folder will be created if it does not exist.
+ (NSString *) MT32ROMPathCreatingIfMissing: (BOOL)createIfMissing;


#pragma mark -
#pragma mark ROM management

//Returns the path to the requested ROM file, or nil if it is not present.
+ (NSString *) pathToMT32ControlROM;
+ (NSString *) pathToMT32PCMROM;

//Copies the specified ROM into the application support folder,
//making it accessible via the respective path method above.
+ (BOOL) importMT32ControlROM: (NSString *)ROMPath error: (NSError **)outError;
+ (BOOL ) importMT32PCMROM: (NSString *)ROMPath error: (NSError **)outError;

@end
