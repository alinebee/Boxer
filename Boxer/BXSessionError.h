/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXImportError defines custom import-related errors.

#import <Foundation/Foundation.h>
#import "NSError+ADBErrorHelpers.h"

//Error domains and codes
extern NSErrorDomain const BXSessionErrorDomain;
typedef NS_ERROR_ENUM(BXSessionErrorDomain, BXSessionErrorValue)
{
    BXSessionCannotMountSystemFolder,   //!< Returned when user attempts to mount an OS X system folder as a DOS drive.
	
    BXImportNoExecutablesInSource,      //!< Returned when the import scanner can find no executables of any kind in the source folder.
	BXImportSourceIsWindowsOnly,        //!< Returned when the import scanner can only find Windows executables in the source folder.
	BXImportSourceIsMacOSApp,           //!< Returned when the import scanner can only find Mac applications in the source folder.
	BXImportSourceIsHybridCD,           //!< Returned when the import scanner detects a hybrid Mac+PC CD.
    BXImportDriveUnavailable,           //!< Returned when a DOSBox configuration file was provided that defines drives with paths that cannot be found.
    
    BXGameStateUnsupported,     //!< Returned when the current session does not support game states. (e.g. no gamebox is present.)
    BXGameStateGameboxMismatch, //!< Returned when validating a boxerstate file, if it is for a different game than the current game.
    
    BXSessionNotReady,          //!< Returned when \c openURLInDOS:error: is not ready to open a program.
    BXURLNotReachableInDOS,     //!< Returned when \c openURLInDOS:error: is passed a URL that cannot be mapped to a DOS path.
};

//! General base class for all session errors
@interface BXSessionError : NSError
@end

//! Errors specific to game importing
@interface BXImportError : BXSessionError
@end

@interface BXSessionCannotMountSystemFolderError : BXSessionError
+ (id) errorWithFolderURL: (NSURL *)folderURL userInfo: (NSDictionary *)userInfo;
@end

@interface BXImportNoExecutablesError : BXImportError
+ (id) errorWithSourceURL: (NSURL *)sourceURL userInfo: (NSDictionary *)userInfo;
@end

@interface BXImportWindowsOnlyError : BXImportError
+ (id) errorWithSourceURL: (NSURL *)sourceURL userInfo: (NSDictionary *)userInfo;
- (NSString *) helpAnchor;
@end

@interface BXImportHybridCDError : BXImportError
+ (id) errorWithSourceURL: (NSURL *)sourceURL userInfo: (NSDictionary *)userInfo;
@end

@interface BXImportMacAppError : BXImportError
+ (id) errorWithSourceURL: (NSURL *)sourceURL userInfo: (NSDictionary *)userInfo;
@end

@class BXDrive;
@interface BXImportDriveUnavailableError : BXImportError
+ (id) errorWithSourceURL: (NSURL *)sourceURL drive: (BXDrive *)drive userInfo: (NSDictionary *)userInfo;
@end

@class BXGamebox;
@interface BXGameStateGameboxMismatchError : BXSessionError
+ (id) errorWithStateURL: (NSURL *)stateURL gamebox: (BXGamebox *)gamebox userInfo: (NSDictionary *)userInfo;
@end

@interface BXSessionNotReadyError : BXSessionError

+ (id) errorWithUserInfo: (NSDictionary *)userInfo;

@end

@interface BXSessionURLNotReachableError : BXSessionError
+ (id) errorWithURL: (NSURL *)URL userInfo: (NSDictionary *)userInfo;
@end
