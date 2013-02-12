/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXIcons is an NSWorkspace category to add methods for handling file and folder icons.

#import <Cocoa/Cocoa.h>

@interface NSWorkspace (BXIcons)

//Returns whether the file or folder at the specified path has a custom icon resource.
- (BOOL) fileHasCustomIcon: (NSString *)path;

@end
