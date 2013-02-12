/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//The BXFilePaths category extends NSURL to add a few helpful methods for dealing with file URLs
//and their paths.

#import <Foundation/Foundation.h>

@interface NSURL (BXFilePaths)

//Returns a path string for this URL relative to the specified file URL.
- (NSString *) pathRelativeToURL: (NSURL *)baseURL;

//Returns a URL constructed relative to the specified file URL.
- (NSURL *) URLRelativeToURL: (NSURL *)baseURL;

//Convert a URL to/from a local filesystem path representation.
- (const char *) fileSystemRepresentation;
+ (NSURL *) URLFromFileSystemRepresentation: (const char *)representation;

//Whether this URL has the specified file URL as an ancestor.
- (BOOL) isBasedInURL: (NSURL *)baseURL;

//An analogue for NSString pathComponents:
//Returns an array containing this URL and every parent directory leading back to the root.
- (NSArray *) componentURLs;

//An analogue for NSString stringsByAppendingPaths:
- (NSArray *) URLsByAppendingPaths: (NSArray *)paths;

@end

@interface NSURL (BXFileTypes)

//Returns the UTI of the file at this URL, or nil if this could not be determined.
@property (readonly, nonatomic) NSString *typeIdentifier;

//Returns YES if the Uniform Type Identifier for the file at this URL is equal to or inherits
//from the specified UTI, or if the URL has a path extension that would be suitable for the specified UTI.
- (BOOL) conformsToFileType: (NSString *)UTI;

//Given a set of Uniform TypeIdentifiers, returns the first one to which this URL conforms,
//or nil if it doesn't match any of them.
- (NSString *) matchingFileType: (NSSet *)UTIs;

@end

@interface NSArray (BXURLArrayExtensions)

//An analogue for NSArray pathsMatchingExtensions:
- (NSArray *) URLsMatchingExtensions: (NSArray *)extensions;

@end