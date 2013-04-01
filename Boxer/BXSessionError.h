/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXImportError defines custom import-related errors.

#import <Foundation/Foundation.h>


//Error domains and codes
extern NSString * const BXSessionErrorDomain;
enum
{
    BXSessionCannotMountSystemFolder,   //Returned when user attempts to mount an OS X system folder as a DOS drive.
	
    BXImportNoExecutablesInSourcePath,  //Returned when the import scanner can find no executables of any kind in the source folder.
	BXImportSourcePathIsWindowsOnly,    //Returned when the import scanner can only find Windows executables in the source folder.
	BXImportSourcePathIsMacOSApp,       //Returned when the import scanner can only find Mac applications in the source folder.
	BXImportSourcePathIsHybridCD,       //Returned when the import scanner detects a hybrid Mac+PC CD.
    BXImportDriveUnavailable,           //Returned when a DOSBox configuration file was provided that defines drives with paths that cannot be found.
    
    BXGameStateUnsupported,     //Returned when the current session does not support game states. (e.g. no gamebox is present.)
    BXGameStateGameboxMismatch, //Returned when validating a boxerstate file, if it is for a different game than the current game.
};

//General base class for all session errors
@interface BXSessionError : NSError
@end

//Errors specific to game importing
@interface BXImportError : BXSessionError
@end

@interface BXSessionCannotMountSystemFolderError : BXSessionError
+ (id) errorWithPath: (NSString *)systemFolderPath userInfo: (NSDictionary *)userInfo __deprecated;
@end

@interface BXImportNoExecutablesError : BXImportError
+ (id) errorWithSourcePath: (NSString *)sourcePath userInfo: (NSDictionary *)userInfo __deprecated;
@end

@interface BXImportWindowsOnlyError : BXImportError
+ (id) errorWithSourcePath: (NSString *)sourcePath userInfo: (NSDictionary *)userInfo __deprecated;
- (NSString *) helpAnchor;
@end

@interface BXImportHybridCDError : BXImportError
+ (id) errorWithSourcePath: (NSString *)sourcePath userInfo: (NSDictionary *)userInfo;
@end

@interface BXImportMacAppError : BXImportError
+ (id) errorWithSourcePath: (NSString *)sourcePath userInfo: (NSDictionary *)userInfo;
@end

@class BXDrive;
@interface BXImportDriveUnavailableError : BXImportError
+ (id) errorWithSourcePath: (NSString *)sourcePath drive: (BXDrive *)drive userInfo: (NSDictionary *)userInfo;
@end

@class BXGamebox;
@interface BXGameStateGameboxMismatchError : BXSessionError
+ (id) errorWithStateURL: (NSURL *)stateURL gamebox: (BXGamebox *)gamebox userInfo: (NSDictionary *)userInfo;
@end