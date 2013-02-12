/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXFileTypes category extends NSWorkspace's methods for dealing with Uniform Type Identifiers (UTIs).

#import <Cocoa/Cocoa.h>

@interface NSWorkspace (BXFileTypes)

//Returns whether the file at the specified path/URL matches any of the specified UTI filetypes:
//i.e. whether the file's UTI is equal to *or inherits from* any of those types.
- (BOOL) fileAtURL: (NSURL *)URL matchesTypes: (NSSet *)acceptedTypes;
- (BOOL) file: (NSString *)filePath matchesTypes: (NSSet *)acceptedTypes;

//Returns the nearest ancestor of the specified path/URL that matches any of the specified UTIs,
//or nil if no ancestor matched. This may return filePath, if the file itself matches the specified types.
- (NSURL *) nearestAncestorOfURL: (NSURL *)URL matchingTypes: (NSSet *)acceptedTypes;
- (NSString *) parentOfFile: (NSString *)filePath matchingTypes: (NSSet *)acceptedTypes;

@end
