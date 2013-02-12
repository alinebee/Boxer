/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXFileTypes.h"

NSString * const BXGameboxType      = @"net.washboardabs.boxer-game-package";
NSString * const BXGameStateType    = @"net.washboardabs.boxer-game-state";

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

NSString * const BXDOCFileType      = @"com.microsoft.word.doc";


@implementation BXFileTypes

+ (NSSet *) hddVolumeTypes
{
	static NSSet *types;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        types = [[NSSet alloc] initWithObjects:
                 BXHardDiskFolderType,
                 nil];
    });
	return types;
}

+ (NSSet *) cdVolumeTypes
{
	static NSSet *types;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        types = [[NSSet alloc] initWithObjects:
                 BXCuesheetImageType,
                 BXCDROMFolderType,
                 BXCDROMBundleType,
                 BXISOImageType,
                 BXCDRImageType,
                 nil];
    });
	return types;
}

+ (NSSet *) floppyVolumeTypes
{
	static NSSet *types;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        types = [[NSSet alloc] initWithObjects:
                 BXFloppyFolderType,
                 BXRawFloppyImageType,
                 BXNDIFImageType,
                 BXVirtualPCImageType,
                 nil];
    });
	return types;
}

+ (NSSet *) mountableFolderTypes
{
	static NSSet *types;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        types = [[NSSet alloc] initWithObjects:
                 BXMountableFolderType,
                 nil];
    });
	return types;
}

+ (NSSet *) mountableImageTypes
{
	static NSSet *types;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        types = [[NSSet alloc] initWithObjects:
                 BXDiskBundleType,
                 BXISOImageType,
                 BXCDRImageType,
                 BXCuesheetImageType,
                 BXRawFloppyImageType,
                 BXVirtualPCImageType,
                 BXNDIFImageType,
                 nil];
    });
	return types;
}

+ (NSSet *) OSXMountableImageTypes
{
	static NSSet *types;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        types = [[NSSet alloc] initWithObjects:
                 BXISOImageType,
                 BXCDRImageType,
                 BXRawFloppyImageType,
                 BXVirtualPCImageType,
                 BXNDIFImageType,
                 nil];
    });
	return types;
}

+ (NSSet *) mountableTypes
{
	static NSSet *types;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        types = [[[self mountableImageTypes] setByAddingObject: (NSString *)kUTTypeDirectory] retain];
    });
    
	return types;
}

+ (NSSet *) executableTypes
{
	static NSSet *types;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        types = [[NSSet alloc] initWithObjects:
                 BXEXEProgramType,
                 BXCOMProgramType,
                 BXBatchProgramType,
                 nil];
    });
	return types;
}

+ (NSSet *) macOSAppTypes
{
	static NSSet *types;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        types = [[NSSet alloc] initWithObjects:
                 (NSString *)kUTTypeApplicationFile,
                 (NSString *)kUTTypeApplicationBundle,
                 nil];
    });
	return types;
}

+ (NSSet *) documentationTypes
{
	static NSSet *types = nil;
	if (!types) types = [[NSSet alloc] initWithObjects:
                         @"public.jpeg",
                         @"public.plain-text",
                         @"public.png",
                         @"com.compuserve.gif",
                         @"com.adobe.pdf",
                         @"public.rtf",
                         @"com.microsoft.bmp",
                         @"com.microsoft.word.doc",
                         @"public.html",
                         nil];
	return types;
}

+ (NSDictionary *) fileHandlerOverrides
{
	static NSDictionary *handlers;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        handlers = @{
            //Open .docs in TextEdit, because most DOS-era .docs are plaintext files
            //and Pages (maybe other rich-text editors too?) will choke on them
            @"doc": @"com.apple.TextEdit",
        };
        [handlers retain];
    });
	return handlers;
}

+ (NSString *) bundleIdentifierForApplicationToOpenURL: (NSURL *)URL
{
    NSURL *resolvedURL = URL.URLByResolvingSymlinksInPath;
    
    NSDictionary *directoryFlags = [resolvedURL resourceValuesForKeys: @[NSURLIsDirectoryKey, NSURLIsPackageKey] error: NULL];
    BOOL isDirectory    = [[directoryFlags objectForKey: NSURLIsDirectoryKey] boolValue];
    BOOL isPackage      = [[directoryFlags objectForKey: NSURLIsPackageKey] boolValue];
    
    if (!isDirectory || isPackage)
    {
        NSString *fileExtension = URL.pathExtension.lowercaseString;
        return [[self fileHandlerOverrides] objectForKey: fileExtension];
    }
    else return nil;
}

@end
