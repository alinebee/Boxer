/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Foundation/Foundation.h>

//Constants and class methods for file type UTIs that Boxer manages.

NS_ASSUME_NONNULL_BEGIN

extern NSString * const BXGameboxType;          //!< .boxer
extern NSString * const BXGameStateType;        //!< .boxerstate

extern NSString * const BXMountableFolderType;  //!< Base UTI for .cdrom, .floppy, .harddisk
extern NSString * const BXFloppyFolderType;     //!< .floppy
extern NSString * const BXHardDiskFolderType;   //!< .harddisk
extern NSString * const BXCDROMFolderType;      //!< .cdrom

extern NSString * const BXCuesheetImageType;    //!< .cue / .inst
extern NSString * const BXISOImageType;         //!< .iso / .gog
extern NSString * const BXCDRImageType;         //!< .cdr
extern NSString * const BXVirtualPCImageType;   //!< .vfd
extern NSString * const BXRawFloppyImageType;   //!< .ima
extern NSString * const BXNDIFImageType;        //!< .img

extern NSString * const BXDiskBundleType;       //!< Base UTI for .cdmedia
extern NSString * const BXCDROMImageBundleType; //!< .cdmedia

extern NSString * const BXEXEProgramType;       //!< .exe
extern NSString * const BXCOMProgramType;       //!< .com
extern NSString * const BXBatchProgramType;     //!< .bat



@interface BXFileTypes : NSObject

/// DOS executable UTIs
@property (class, readonly, copy) NSSet<NSString*> *executableTypes;
/// MacOS/OS X application UTIs
@property (class, readonly, copy) NSSet<NSString*> *macOSAppTypes;
/// UTIs that should be mounted as DOS hard drives
@property (class, readonly, copy) NSSet<NSString*> *hddVolumeTypes;
/// UTIs that should be mounted as DOS CD-ROM drives
@property (class, readonly, copy) NSSet<NSString*> *cdVolumeTypes;
/// UTIs that should be mounted as DOS floppy drives
@property (class, readonly, copy) NSSet<NSString*> *floppyVolumeTypes;
/// All mountable folder UTIs supported by Boxer
@property (class, readonly, copy) NSSet<NSString*> *mountableFolderTypes;
/// All mountable disk-image UTIs supported by Boxer
@property (class, readonly, copy) NSSet<NSString*> *mountableImageTypes;
/// All disk-image UTIs that OSX's hdiutil can mount
@property (class, readonly, copy) NSSet<NSString*> *OSXMountableImageTypes;
/// All mountable UTIs supported by Boxer
@property (class, readonly, copy) NSSet<NSString*> *mountableTypes;

/// Document filetypes that Boxer will treat as game documentation.
@property (class, readonly, copy) NSSet<NSString*> *documentationTypes;

/// A dictionary of file extension->app identifier pairs for overriding OS X's default
/// choice of application for opening a particular file extension.
/// These are looked up by file extension rather than UTI because it's common for particular
/// legacy file extensions (like .DOC) to be construed by OSX as the wrong UTI, and we don't
/// want to override the handler for files with different extensions that conform to that UTI.
@property (class, readonly, copy) NSDictionary<NSString*,NSString*> *fileHandlerOverrides;

/// Returns a specific bundle identifier that we want to use to open the specified URL,
/// or \c nil if OS X's default handler should be used. This uses \c fileHandlerOverrides to
/// selectively override the default for files with particular extensions.
+ (nullable NSString *) bundleIdentifierForApplicationToOpenURL: (NSURL *)URL;

@end


#pragma mark - Executable type checking

extern NSErrorDomain const BXExecutableTypesErrorDomain;
typedef NS_ERROR_ENUM(BXExecutableTypesErrorDomain, BXExecutableTypesErrors)
{
	BXNotAnExecutable			= 1,	//!< Specified file was simply not a recognised executable type
	BXCouldNotReadExecutable	= 2,	//!< Specified file could not be opened for reading
	BXExecutableTruncated		= 3		//!< Specified file was truncated or corrupted
};

//Executable types.
typedef NS_ENUM(NSInteger, BXExecutableType) {
	BXExecutableTypeUnknown	= 0,
	BXExecutableTypeDOS,
	BXExecutableTypeWindows,
	BXExecutableTypeOS2
};

@protocol ADBReadable, ADBSeekable, ADBFilesystemPathAccess;
@interface BXFileTypes (BXExecutableTypes)

/// Returns the executable type of the file at the specified URL or in the specified stream.
/// If the executable type cannot be determined, these will return \c BXExecutableTypeUnknown
/// and populate outError with the failure reason.
+ (BXExecutableType) typeOfExecutableAtURL: (NSURL *)URL
                                     error: (out NSError **)outError;

+ (BXExecutableType) typeOfExecutableInStream: (id <ADBReadable, ADBSeekable>)handle
                                        error: (out NSError **)outError;

+ (BXExecutableType) typeOfExecutableAtPath: (NSString *)path
                                 filesystem: (id <ADBFilesystemPathAccess>)filesystem
                                      error: (out NSError **)outError;

/// Returns whether the file at the specified URL is a DOSBox-compatible executable.
/// If the file appears to be a .COM or .BAT file, this method will assume it is compatible;
/// If the file is an .EXE file, \c typeOfExecutableAtURL:error: will be used to determine the type.
+ (BOOL) isCompatibleExecutableAtURL: (NSURL *)URL error: (out NSError **)outError;

+ (BOOL) isCompatibleExecutableAtPath: (NSString *)path
                           filesystem: (id <ADBFilesystemPathAccess>)filesystem
                                error: (out NSError **)outError;

@end


#pragma mark - Filesystems

@protocol ADBFilesystemPathAccess;
@protocol ADBFilesystemLogicalURLAccess;
@interface BXFileTypes (BXFilesystemDetection)

/// Returns a filesystem suitable for traversing the specified URL. This will return an
/// image-based filesystem if it detects that the file at the target URL is a readable
/// or mountable image.
+ (nullable id <ADBFilesystemPathAccess, ADBFilesystemLogicalURLAccess>)filesystemWithContentsOfURL: (NSURL *)URL
																							  error: (out NSError **)outError;

@end

NS_ASSUME_NONNULL_END
