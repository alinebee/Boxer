/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXFileTypes.h"
#import "BXExecutableConstants.h"
#import "NSURL+ADBFilesystemHelpers.h"
#import "ADBFileHandle.h"

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

//This class is just a hanger for class methods and is not intended to be instantiated.
- (id) init
{
    [self doesNotRecognizeSelector: _cmd];
    [self release];
    return nil;
}

@end



#pragma mark - Executable type checking

NSString * const BXExecutableTypesErrorDomain = @"BXExecutableTypesErrorDomain";

@implementation BXFileTypes (BXExecutableTypes)

+ (BXExecutableType) typeOfExecutableAtURL: (NSURL *)URL error: (NSError **)outError
{
	NSAssert(URL != nil, @"No URL specified!");
    
    NSError *openError = nil;
    ADBFileHandle *handle = [ADBFileHandle handleForURL: URL mode: "r" error: &openError];
    if (handle)
    {
        NSError *readError = nil;
        BXExecutableType type = [BXFileTypes typeOfExecutableInStream: handle error: &readError];
        if (type == BXExecutableTypeUnknown)
        {
            if (outError)
            {
                NSAssert(readError != nil, @"No error returned on failure condition!");
                NSDictionary *info = @{ NSURLErrorKey: URL, NSUnderlyingErrorKey: readError };
                *outError = [NSError errorWithDomain: BXExecutableTypesErrorDomain
                                                code: readError.code
                                            userInfo: info];
            }
        }
        
        return type;
    }
    else
    {
        if (outError)
        {
            NSAssert(openError != nil, @"No error returned on failure condition!");
            NSDictionary *info = @{ NSURLErrorKey: URL, NSUnderlyingErrorKey: openError };
            *outError = [NSError errorWithDomain: BXExecutableTypesErrorDomain
                                            code: BXCouldNotReadExecutable
                                        userInfo: info];
        }
        return BXExecutableTypeUnknown;
    }
}

+ (BXExecutableType) typeOfExecutableInStream: (id<ADBReadable, ADBSeekable>)handle
                                        error: (out NSError **)outError
{
	NSAssert(handle != nil, @"No handle provided!");
    
    
    NSError *handleError = nil;
    BXDOSExecutableHeader header;
	size_t headerSize = sizeof(BXDOSExecutableHeader);
    
    NSUInteger bytesRead = headerSize;
    
    //Rewind to the start of the stream before we begin
    BOOL rewound = [handle seekToOffset: 0 relativeTo: ADBSeekFromStart error: &handleError];
    BOOL read = rewound && [handle readBytes: &header maxLength: headerSize bytesRead: &bytesRead error: &handleError];
    if (!rewound || !read)
    {
        if (outError)
        {
            NSAssert(handleError != nil, @"No error returned on failure condition!");
            *outError = [NSError errorWithDomain: BXExecutableTypesErrorDomain
                                            code: BXCouldNotReadExecutable
                                        userInfo: @{ NSUnderlyingErrorKey: handleError }];
        }
        return BXExecutableTypeUnknown;
    }
    
    if (bytesRead < headerSize)
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain: BXExecutableTypesErrorDomain
                                            code: BXExecutableTruncated
                                        userInfo: nil];
        }
        return BXExecutableTypeUnknown;
    }
	
	//Header is stored in little-endian format, so swap the bytes
    //around on PowerPC systems to ensure correct comparisons.
	unsigned short typeMarker			= NSSwapLittleShortToHost(header.typeMarker);
	unsigned short relocationAddress	= NSSwapLittleShortToHost(header.relocationTableAddress);
	unsigned long newHeaderAddress		= NSSwapLittleLongToHost(header.newHeaderAddress);
	
	//DOS headers always start with the MZ type marker:
	//if this differs, then it's not a real executable.
	if (typeMarker != BXDOSExecutableMarker)
	{
		if (outError)
		{
			*outError = [NSError errorWithDomain: BXExecutableTypesErrorDomain
											code: BXNotAnExecutable
										userInfo: nil];
		}
		return BXExecutableTypeUnknown;
	}
	
	//The header's relocation table address should always be 64 for new-style executables:
	//if it differs, then we can assume it's just random data and this is a DOS-only executable.
	if (relocationAddress != BXExtendedExecutableRelocationAddress)
        return BXExecutableTypeDOS;
	
	//If the address of the new-style executable header is zero, assume that it's just random data
    //and that this is a DOS executable.
	if (newHeaderAddress == 0)
        return BXExecutableTypeDOS;
    
	
	//Read in the 2-byte executable type marker from the start of the new-style header.
	uint16_t newTypeMarker = 0;
    NSUInteger markerLength = sizeof(uint16_t);
    
    BOOL soughtToMarker = [handle seekToOffset: newHeaderAddress
                            relativeTo: ADBSeekFromStart
                                 error: &handleError];
    
    NSUInteger markerBytesRead;
    BOOL readMarker = soughtToMarker && [handle readBytes: &newTypeMarker
                                                maxLength: markerLength
                                                bytesRead: &markerBytesRead
                                                    error: &handleError];
    
    if (!soughtToMarker || !readMarker)
    {
        if (outError)
        {
            NSAssert(handleError != nil, @"No error returned on failure condition!");
            *outError = [NSError errorWithDomain: BXExecutableTypesErrorDomain
                                            code: BXCouldNotReadExecutable
                                        userInfo: @{ NSUnderlyingErrorKey: handleError }];
        }
        return BXExecutableTypeUnknown;
    }
    
    //The executable type marker is beyond the limits of the executable, so assume that the
    //address pointing to it was just coincidental random data and that this is therefore
    //a DOS program.
    if (markerBytesRead < markerLength)
    {
        return BXExecutableTypeDOS;
    }
	
	newTypeMarker = NSSwapLittleShortToHost(newTypeMarker);
	
	switch (newTypeMarker)
	{
		case BX16BitNewExecutableMarker:
		case BX32BitPortableExecutableMarker:
			//Stub area is unusually large: assume it contains a legitimate DOS program.
			if (newHeaderAddress > BXMaxWarningStubLength)
				return BXExecutableTypeDOS;
			
			unsigned long minHeaderLength = (newTypeMarker == BX32BitPortableExecutableMarker) ? BX32BitPortableExecutableHeaderLength : BX16BitNewExecutableHeaderLength;
			
			//File is not long enough to accomodate expected header: assume what we thought was a type marker
			//was just coincidental random data, and this is actually a DOS executable.
			if (handle.maxOffset < (newHeaderAddress + minHeaderLength))
				return BXExecutableTypeDOS;
            
			//Otherwise, assume it's Windows.
			return BXExecutableTypeWindows;
            
		case BX16BitLinearExecutableMarker:
		case BX32BitLinearExecutableMarker:
			//Stub area is unusually large: assume it contains a legitimate DOS program.
			if (newHeaderAddress > BXMaxWarningStubLength)
				return BXExecutableTypeDOS;
			
			//Otherwise, assume it's OS/2.
			return BXExecutableTypeOS2;
            
		case BXW3ExecutableMarker:
		case BXW4ExecutableMarker:
			return BXExecutableTypeWindows;
			
		default:
			return BXExecutableTypeDOS;
	}
}

+ (BOOL) isCompatibleExecutableAtURL: (NSURL *)URL error: (out NSError **)outError
{
	//Automatically assume .COM and .BAT files are DOS-compatible.
    if ([URL conformsToFileType: BXCOMProgramType] || [URL conformsToFileType: BXBatchProgramType])
        return YES;
	
	//If it is an .EXE file, subject it to a more rigorous compatibility check.
    if ([URL conformsToFileType: BXEXEProgramType])
    {
        BXExecutableType exeType = [self typeOfExecutableAtURL: URL error: outError];
        return (exeType == BXExecutableTypeDOS);
    }
    
	//Otherwise, assume the file is incompatible.
	return NO;
}

@end
