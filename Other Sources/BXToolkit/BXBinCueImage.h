/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXBinCueImage is a BXISOImage subclass for handling the minor format variations from CDRWin
//BIN/CUE binary images, as well as processing their accompanying cue sheets.


#import "BXISOImage.h"

@interface BXBinCueImage : BXISOImage
    
#pragma mark -
#pragma mark Helper class methods
    
//Returns an array of dependent file paths in the specified CUE,
//as absolute OS X filesystem paths resolved relative to the CUE.
+ (NSArray *) resourcePathsInCueAtPath: (NSString *)cuePath error: (NSError **)outError;

//Returns the path of the binary image for the specified CUE file,
//or nil if such could not be determined.
+ (NSString *) binPathInCueAtPath: (NSString *)cuePath error: (NSError **)outError;

//Returns an array of dependent file paths in the specified CUE,
//in the exact form they are written.
+ (NSArray *) rawPathsInCueAtPath: (NSString *)cuePath error: (NSError **)outError;

//Given a string representing, returns the raw paths in the exact form they are written.
+ (NSArray *) rawPathsInCueContents: (NSString *)cueContents;

//Returns YES if the specified path contains a parseable cue file, NO otherwise.
//Populates outError if there is a problem accessing the file.
+ (BOOL) isCueAtPath: (NSString *)cuePath error: (NSError **)outError;

@end
