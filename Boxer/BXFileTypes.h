/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Foundation/Foundation.h>

//Constants and class methods for file type UTIs that Boxer manages.

extern NSString * const BXGameboxType;          //.boxer
extern NSString * const BXGameStateType;        //.boxerstate

extern NSString * const BXMountableFolderType;  //Base UTI for .cdrom, .floppy, .harddisk
extern NSString * const BXFloppyFolderType;     //.floppy
extern NSString * const BXHardDiskFolderType;   //.harddisk
extern NSString * const BXCDROMFolderType;      //.cdrom

extern NSString * const BXCuesheetImageType;    //.cue / .inst
extern NSString * const BXISOImageType;         //.iso / .gog
extern NSString * const BXCDRImageType;         //.cdr
extern NSString * const BXVirtualPCImageType;   //.vfd
extern NSString * const BXRawFloppyImageType;   //.ima
extern NSString * const BXNDIFImageType;        //.img

extern NSString * const BXDiskBundleType;       //Base UTI for .cdmedia
extern NSString * const BXCDROMBundleType;      //.cdmedia

extern NSString * const BXEXEProgramType;       //.exe
extern NSString * const BXCOMProgramType;       //.com
extern NSString * const BXBatchProgramType;     //.bat


@interface BXFileTypes : NSObject

+ (NSSet *) executableTypes;		//DOS executable UTIs
+ (NSSet *) macOSAppTypes;          //MacOS/OS X application UTIs
+ (NSSet *) hddVolumeTypes;			//UTIs that should be mounted as DOS hard drives
+ (NSSet *) cdVolumeTypes;			//UTIs that should be mounted as DOS CD-ROM drives
+ (NSSet *) floppyVolumeTypes;		//UTIs that should be mounted as DOS floppy drives
+ (NSSet *) mountableFolderTypes;	//All mountable folder UTIs supported by Boxer
+ (NSSet *) mountableImageTypes;	//All mountable disk-image UTIs supported by Boxer
+ (NSSet *) OSXMountableImageTypes; //All disk-image UTIs that OSX's hdiutil can mount
+ (NSSet *) mountableTypes;			//All mountable UTIs supported by Boxer

@end
