/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXPathEnumerator is an NSDirectoryEnumerator wrapper with a bunch of convenience methods for filtering out unwanted files.

#import <Foundation/Foundation.h>

@interface BXPathEnumerator : NSEnumerator
{
	NSDirectoryEnumerator *enumerator;
	BOOL skipHiddenFiles;
	BOOL skipSubdirectories;
	BOOL skipPackageContents;
	NSSet *fileTypes;
	NSString *basePath;
	NSString *currentPath;
}

#pragma mark -
#pragma mark Properties

//The enumerator we use internally for iterating the directory contents.
@property (readonly, retain, nonatomic) NSDirectoryEnumerator *enumerator;

//The base path we are iterating.
@property (readonly, copy, nonatomic) NSString *basePath;
//The full path of the last file returned by nextObject.
@property (readonly, copy, nonatomic) NSString *currentPath;

//Whether nextObject should ignore hidden files. Is YES by default.
@property (assign, nonatomic) BOOL skipHiddenFiles;
//Whether nextObject should only enumerate the base path, skipping all subdirectories. Is NO by default.
@property (assign, nonatomic) BOOL skipSubdirectories;
//Whether nextObject should skip over files located in packages (the packages themselves will still be returned.) Is NO by default.
@property (assign, nonatomic) BOOL skipPackageContents;

//What UTI filetypes nextObject will return. If nil, files of any type will be returned.
@property (copy, nonatomic) NSSet *fileTypes;

//Passthroughs for NSDirectoryEnumerator methods.
@property (readonly, nonatomic) NSDictionary *fileAttributes;
@property (readonly, nonatomic) NSDictionary *directoryAttributes;


#pragma mark -
#pragma mark Methods

//Return a new autoreleased enumerator for the specified file path.
+ (id) enumeratorAtPath: (NSString *)filePath;

//Passthroughs for NSDirectoryEnumerator methods.
- (void) skipDescendents;

@end