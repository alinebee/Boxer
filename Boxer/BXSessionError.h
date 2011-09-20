/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXImportError defines custom import-related errors.

#import <Foundation/Foundation.h>


//Error domains and codes
extern NSString * const BXSessionErrorDomain;
enum
{
    BXSessionCannotMountSystemFolder,       //Returned when user attempts to mount an OS X system folder as a DOS drive.
	
    BXImportNoExecutablesInSourcePath,      //Returned when the import scanner can find no executables of any kind in the source folder.
	BXImportSourcePathIsWindowsOnly,        //Returned when the import scanner can only find Windows executables in the source folder.
};

//General base class for all session errors
@interface BXSessionError : NSError
@end

//Errors specific to game importing
@interface BXImportError : BXSessionError
@end

@interface BXSessionCannotMountSystemFolderError : BXSessionError
+ (id) errorWithPath: (NSString *)systemFolderPath userInfo: (NSDictionary *)userInfo;
@end

@interface BXImportNoExecutablesError : BXImportError
+ (id) errorWithSourcePath: (NSString *)sourcePath userInfo: (NSDictionary *)userInfo;
@end

@interface BXImportWindowsOnlyError : BXImportError
+ (id) errorWithSourcePath: (NSString *)sourcePath userInfo: (NSDictionary *)userInfo;
- (NSString *) helpAnchor;
@end
