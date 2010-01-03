/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXGameProfile detects and retrieves specific game configuration profiles.
//At the moment, game profiles are represented as NSDictionaries and this class only has static
//methods; in future, they may be replaced with a custom class.

#import <Cocoa/Cocoa.h>


//Constants used by eraOfGameAtPath:
enum {
	BX525DisketteEra,
	BX35DisketteEra,
	BXCDROMEra
};
typedef NSUInteger BXGameEra;


@interface BXGameProfile : NSObject
//Returns an array of generic profiles that match multiple games.
//This corresponds the contents of the BXGenericProfiles key in GameProfiles.plist.
+ (NSArray *) genericProfiles;

//Returns an array of game profiles identifying specific games.
//This corresponds the contents of the BXSpecificGameProfiles key in GameProfiles.plist.
+ (NSArray *) specificGameProfiles;

//Detects and returns an appropriate game profile for the specified path, by scanning for telltale
//files in the file heirarchy starting at basePath.

//FIXME: this approach may be too näive and could return false positives in cases where we have a more
//specific game profile that is matched earlier by a less specific one. This could be fixed by matching
//all profiles and then sorting them by 'relevance', at a cost of scanning the entire file heirarchy.
+ (NSDictionary *)detectedProfileForPath: (NSString *)basePath;


//Returns whether the contents of the specified file path look like a floppy disk game, based on
//age of files and overall size. This is used to decide which bootleg coverart style to use.
+ (BXGameEra) eraOfGameAtPath: (NSString *)basePath;
@end


//Internal methods which should not be called outside BXGameProfile.
@interface BXGameProfile (BXGameProfileInternals)

//Caches and returns the contents of GameProfiles.plist to avoid multiple hits to the filesystem.
+ (NSDictionary *) _gameProfileData;

//Generates, caches and returns a lookup table of filename->profile mappings.
//Used by detectedProfileForPath: to perform detection in a single pass of the file heirarchy.
+ (NSDictionary *) _detectionLookups;
@end