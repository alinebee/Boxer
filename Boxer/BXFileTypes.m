/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXFileTypes.h"
#import "BXDrive.h"

NSString * const BXGameboxType = @"net.washboardabs.boxer-package";

NSString * const BXMountableFolderType  = @"net.washboardabs.boxer-mountable-folder";
NSString * const BXFloppyFolderType     = @"net.washboardabs.boxer-floppy-folder";
NSString * const BXHardDiskFolderType   = @"net.washboardabs.boxer-harddisk-folder";
NSString * const BXCDROMFolderType      = @"net.washboardabs.boxer-cdrom-folder";

NSString * const BXCuesheetImageType    = @"com.goldenhawk.cdrwin-cuesheet";
NSString * const BXISOImageType         = @"public.iso-image";
NSString * const BXCDRImageType         = @"com.apple.disk-image-cdr";
NSString * const BXVirtualPCImageType   = @"com.microsoft.virtualpc-disk-image";
NSString * const BXRawFloppyImageType   = @"com.winimage.raw-disk-image";
NSString * const BXNDIFImageType        = @"com.apple.disk-image-ndif";

NSString * const BXDiskBundleType   = @"net.washboardabs.boxer-disk-bundle";
NSString * const BXCDROMBundleType  = @"net.washboardabs.boxer-cdrom-bundle";

NSString * const BXEXEProgramType   = @"com.microsoft.windows-executable";
NSString * const BXCOMProgramType   = @"com.microsoft.msdos-executable";
NSString * const BXBatchProgramType = @"com.microsoft.batch-file";


@implementation BXFileTypes

+ (NSSet *) hddVolumeTypes
{
	static NSSet *types = nil;
	if (!types) types = [[NSSet alloc] initWithObjects:
                         BXHardDiskFolderType,
						 nil];
	return types;
}

+ (NSSet *) cdVolumeTypes
{
	static NSSet *types = nil;
	if (!types) types = [[NSSet alloc] initWithObjects:
                         BXCuesheetImageType,
                         BXCDROMFolderType,
                         BXCDROMBundleType,
                         BXISOImageType,
                         BXCDRImageType,
						 nil];
	return types;
}

+ (NSSet *) floppyVolumeTypes
{
	static NSSet *types = nil;
	if (!types) types = [[NSSet alloc] initWithObjects:
                         BXFloppyFolderType,
                         BXRawFloppyImageType,
                         BXNDIFImageType,
                         BXVirtualPCImageType,
						 nil];
	return types;
}

+ (NSSet *) mountableFolderTypes
{
	static NSSet *types = nil;
	if (!types) types = [[NSSet alloc] initWithObjects:
                         BXMountableFolderType,
						 nil];
	return types;
}

+ (NSSet *) mountableImageTypes
{
	static NSSet *types = nil;
	if (!types) types = [[NSSet alloc] initWithObjects:
                         BXDiskBundleType,
                         BXISOImageType,
                         BXCDRImageType,
                         BXCuesheetImageType,
                         BXRawFloppyImageType,
                         BXVirtualPCImageType,
                         BXNDIFImageType,
						 nil];
	return types;
}

+ (NSSet *) OSXMountableImageTypes
{
	static NSSet *types = nil;
	if (!types) types = [[NSSet alloc] initWithObjects:
                         BXISOImageType,
                         BXCDRImageType,
                         BXRawFloppyImageType,
                         BXVirtualPCImageType,
                         BXNDIFImageType,
						 nil];
	return types;
}

+ (NSSet *) mountableTypes
{
	static NSSet *types = nil;
	if (!types) types = [[[self mountableImageTypes] setByAddingObject: (NSString *)kUTTypeDirectory] retain];
	return types;
}

+ (NSSet *) executableTypes
{
	static NSSet *types = nil;
	if (!types) types = [[NSSet alloc] initWithObjects:
                         BXEXEProgramType,
                         BXCOMProgramType,
                         BXBatchProgramType,
                         nil];
	return types;
}

+ (NSSet *) macOSAppTypes
{
	static NSSet *types = nil;
	if (!types) types = [[NSSet alloc] initWithObjects:
                         (NSString *)kUTTypeApplicationFile,
                         (NSString *)kUTTypeApplicationBundle,
                         nil];
	return types;
}

@end
