/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXFileScan is a BXOperation subclass class for performing asynchronous filesystem
//scans for files matching certain criteria.
//This is essentially a reimplementation of BXPathEnumerator as a standalone operation.

#import "BXOperation.h"
#import <AppKit/AppKit.h>

#pragma mark -
#pragma mark Constants

//Included in in-progress notification dictionary to mark the last matching path found.
extern NSString * const BXFileScanLastMatchKey;


#pragma mark -
#pragma mark Interface declaration

@class BXPathEnumerator;
@interface BXFileScan : BXOperation
{
	NSString *basePath;
    
    NSMutableArray *matchingPaths;
    NSUInteger maxMatches;
    
    BOOL skipHiddenFiles;
	BOOL skipSubdirectories;
	BOOL skipPackageContents;
	NSSet *fileTypes;
    NSPredicate *predicate;
    
	NSFileManager *manager;
	NSWorkspace *workspace;
}

#pragma mark -
#pragma mark Properties

//The base filesystem path whose files and subfolders Boxer will scan.
//Should not be modified while the scan is in progress.
@property (copy, nonatomic) NSString *basePath;

//The array of matched files, which will be gradually populated throughout the scan.
@property (readonly, nonatomic) NSArray *matchingPaths;

//Optional: the maximum number of matches to return. Defaults to 0, which means no limit.
@property (assign, nonatomic) NSUInteger maxMatches;

//The last path that was matched by the scan.
@property (readonly, nonatomic) NSString *lastMatch;


//Optional: only files whose paths (relative to basePath) match the specified predicate will be returned.
@property (copy, nonatomic) NSPredicate *predicate;

//Optional: only files which match the specified UTI filetypes will be returned.
@property (copy, nonatomic) NSSet *fileTypes;

//Whether the scan should ignore hidden files. Is YES by default.
@property (assign, nonatomic) BOOL skipHiddenFiles;

//Whether the scan should only enumerate the base path, skipping all subdirectories.
//Is NO by default.
@property (assign, nonatomic) BOOL skipSubdirectories;

//Whether the scan should skip over files located in packages.
//The packages themselves will still be returned, if they match the search criteria.
//Is NO by default.
@property (assign, nonatomic) BOOL skipPackageContents;


#pragma mark -
#pragma mark Methods

//Returns an autoreleased file scan operation with the specified base path.
+ (id) scanWithBasePath: (NSString *)basePath;


//Returns whether the specified file path (relative to basePath) matches
//our search criteria.
//Returns YES if filePath matches fileTypes and predicate, NO otherwise.
//Can be overridden by subclasses to implement custom filtering.
- (BOOL) isMatchingPath: (NSString *)relativePath;


//Returns whether the contents of the specified subpath (relative to basePath)
//should be scanned.
//Returns NO if skipSubdirectories is enabled, or if skipPackageContents is enabled
//and the path represents a file package. Can be overridden by subclasses to perform
//custom subfolder filtering.
- (BOOL) shouldScanSubpath: (NSString *)relativePath;

//Adds the specified path (relative to basePath) into the set of matched paths.
//Called whenever a match is found. Can be overridden by subclasses
//to perform custom logic, such as rewriting the path or adding
//it to additional collections.
- (void) addMatchingPath: (NSString *)relativePath;

@end
