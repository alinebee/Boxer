/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXExecutableTypes category extends NSWorkspace to add methods for verifying MS-DOS executables.

#import "NSWorkspace+BXFileTypes.h"

//Executable types.
enum {
	BXExecutableTypeUnknown	= 0,
	BXExecutableTypeDOS,
	BXExecutableTypeWindows,
	BXExecutableTypeOS2
};

typedef NSUInteger BXExecutableType;


//Error domains and error codes
extern NSString * const BXExecutableTypesErrorDomain;
enum
{
	BXNotAnExecutable			= 1,	//Specified file was simply not a recognised executable type
	BXCouldNotReadExecutable	= 2,	//Specified file could not be opened for reading
	BXExecutableTruncated		= 3		//Specified file was truncated or corrupted
};


@interface NSWorkspace (BXExecutableTypes)

//Returns whether the file at the specified path is an executable that can be run by DOSBox.
//Returns NO and populates outError if the executable type could not be determined.
- (BOOL) isCompatibleExecutableAtPath: (NSString *)filePath error: (NSError **)outError;

//Returns the executable type of the file at the specified path.
//If the executable type cannot be determined, outError will be populated with the reason.
- (BXExecutableType) executableTypeAtPath: (NSString *)path error: (NSError **)outError;

@end
