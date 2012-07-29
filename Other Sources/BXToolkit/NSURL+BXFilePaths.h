/*
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//The BXFilePaths category extends NSURL to add a few helpful methods for dealing with file URLs
//and their paths.

#import <Foundation/Foundation.h>

@interface NSURL (BXPaths)

//Returns a path string for this URL relative to the specified file URL.
- (NSString *) pathRelativeToURL: (NSURL *)baseURL;

//Returns a URL constructed relative to the specified file URL.
- (NSURL *) URLRelativeToURL: (NSURL *)baseURL;

//Convert a URL to/from a local filesystem path representation.
- (const char *) fileSystemRepresentation;
+ (NSURL *) URLFromFileSystemRepresentation: (const char *)representation;

//Whether this URL has the specified file URL as an ancestor.
- (BOOL) isBasedInURL: (NSURL *)baseURL;

- (NSArray *) componentURLs;

@end
