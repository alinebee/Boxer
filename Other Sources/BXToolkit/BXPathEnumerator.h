/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXPathEnumerator is an NSDirectoryEnumerator wrapper with a bunch of convenience methods
//for filtering out unwanted files.

#import <AppKit/AppKit.h>

@interface BXPathEnumerator : NSEnumerator
{
	NSDirectoryEnumerator *_enumerator;
	BOOL _skipHiddenFiles;
	BOOL _skipSubdirectories;
	BOOL _skipPackageContents;
	NSSet *_fileTypes;
    NSPredicate *_predicate;
    
	NSString *_basePath;
	NSString *_currentPath;
	NSString *_relativePath;
	
	NSFileManager *_manager;
	NSWorkspace *_workspace;
}

#pragma mark -
#pragma mark Properties

//The enumerator we use internally for iterating the directory contents.
@property (readonly, retain, nonatomic) NSDirectoryEnumerator *enumerator;

//The base path to iterate. Should not be modified during iteration.
@property (copy, nonatomic) NSString *basePath;

//The full path of the last file returned by nextObject.
@property (readonly, copy, nonatomic) NSString *currentPath;

//The path of the last file returned by nextObject, relative to basePath.
@property (readonly, copy, nonatomic) NSString *relativePath;

//Whether nextObject should ignore hidden files. Is YES by default.
@property (assign, nonatomic) BOOL skipHiddenFiles;

//Whether nextObject should only enumerate the base path, skipping all subdirectories. Is NO by default.
@property (assign, nonatomic) BOOL skipSubdirectories;

//Whether nextObject should skip over files located in packages (the packages themselves will still be returned.) Is NO by default.
@property (assign, nonatomic) BOOL skipPackageContents;

//What UTI filetypes nextObject will return. If nil, files of any type will be returned.
@property (copy, nonatomic) NSSet *fileTypes;

//If specified, only files whose paths match this predicate will be returned.
@property (copy, nonatomic) NSPredicate *predicate;


//Passthroughs for NSDirectoryEnumerator methods.
@property (readonly, nonatomic) NSDictionary *fileAttributes;
@property (readonly, nonatomic) NSDictionary *directoryAttributes;


#pragma mark -
#pragma mark Methods

//Return a new autoreleased enumerator for the specified file path.
+ (id) enumeratorAtPath: (NSString *)filePath;

//Initialise a new emulator for the specified file path.
- (id) initWithPath: (NSString *)filePath;

//Passthroughs for NSDirectoryEnumerator methods.
- (void) skipDescendents;
- (void) skipDescendants;

@end