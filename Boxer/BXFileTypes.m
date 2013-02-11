/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXFileTypes.h"
#import <AppKit/AppKit.h> //for NSWorkspace

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

+ (NSSet *) _plainTextFileExtensions
{
	static NSSet *types;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        types = [[NSSet alloc] initWithObjects:
                 @"doc",
                 nil];
    });
	return types;
}

+ (NSSet *) _plaintextMishandlingAppIdentifiers
{
	static NSSet *appIdentifiers;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        appIdentifiers = [[NSSet alloc] initWithObjects:
                          @"com.apple.iwork.pages",  //Pages
                          nil];
    });
	return appIdentifiers;
}

+ (NSString *) bundleIdentifierForApplicationToOpenURL: (NSURL *)URL
                                         systemDefault: (out NSString **)defaultAppIdentifier
{
    //IMPLEMENTATION NOTE: this check used to use LSCopyDefaultRoleHandlerForContentType but this was returning
    //results inconsistent with NSWorkspace's behaviour. Instead we rely on the slower approach of asking
    //NSWorkspace for the URL of the application and then checking the application's bundle identifier from there.

    NSURL *resolvedURL = URL.URLByResolvingSymlinksInPath;
    NSURL *appURL = [[NSWorkspace sharedWorkspace] URLForApplicationToOpenURL: resolvedURL];
    NSString *preferredAppIdentifier = [NSBundle bundleWithURL: appURL].bundleIdentifier;
    
    /*
     NSString *UTI = resolvedURL.typeIdentifier;
     NSString *targetBundleIdentifier = [(NSString *)LSCopyDefaultRoleHandlerForContentType((CFStringRef)UTI, kLSRolesEditor) autorelease];
     */
    
    if (defaultAppIdentifier)
        *defaultAppIdentifier = preferredAppIdentifier;
    
    //If this is a known plaintext file and would otherwise be opened by an app that would mishandle it,
    //force it to open in TextEdit instead.
    if ([[self _plaintextMishandlingAppIdentifiers] containsObject: preferredAppIdentifier.lowercaseString] &&
        [[self _plainTextFileExtensions] containsObject: resolvedURL.pathExtension.lowercaseString])
    {
        preferredAppIdentifier = @"com.apple.TextEdit";
    }
    
    return preferredAppIdentifier;
}

+ (void) openURLsInPreferredApplications: (NSArray *)URLs
{
    //Go through each URL working out if we want to override the application for any of them.
    //We then group URLs by app so that we can open them all at once with that application
    //(which is tidier and allows e.g. Preview to group the opened documents intelligently).
    NSMutableDictionary *appIdentifiersAndURLs = [[NSMutableDictionary alloc] initWithCapacity: 1];
    
    for (NSURL *URL in URLs)
    {
        id preferredIdentifier, defaultIdentifier;
        
        preferredIdentifier = [self bundleIdentifierForApplicationToOpenURL: URL systemDefault: &defaultIdentifier];
        
        //If we'll be opening this URL with the system's default app, group it with other such URLs
        //under a null identifier so we know to use the default handler later.
        if (preferredIdentifier == nil || [preferredIdentifier isEqualToString: defaultIdentifier])
            preferredIdentifier = [NSNull null];
        
        NSMutableArray *URLsForApp = [appIdentifiersAndURLs objectForKey: preferredIdentifier];
        if (!URLsForApp)
        {
            URLsForApp = [NSMutableArray arrayWithObject: URL];
            [appIdentifiersAndURLs setObject: URLsForApp forKey: preferredIdentifier];
        }
        else
        {
            [URLsForApp addObject: URL];
        }
    }
    
    //Now that we've grouped all the URLs by the app we want to open them in, go ahead and do the opening
    for (NSString *appIdentifier in appIdentifiersAndURLs)
    {
        NSArray *URLsForApp = [appIdentifiersAndURLs objectForKey: appIdentifier];
        
        //The null identifier is special
        if ([appIdentifier isEqual: [NSNull null]])
            appIdentifier = nil;
        
        [[NSWorkspace sharedWorkspace] openURLs: URLsForApp
                        withAppBundleIdentifier: appIdentifier
                                        options: NSWorkspaceLaunchDefault
                 additionalEventParamDescriptor: nil
                              launchIdentifiers: NULL];
    }
}
@end
