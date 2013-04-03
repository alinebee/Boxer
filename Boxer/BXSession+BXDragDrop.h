/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXDragDrop category extends BXSession with methods for responding to drag-drop events
//into the session's main window.

#import "BXSession.h"

@interface BXSession (BXDragDrop)

//UTI filetypes that may be dropped onto this session to mount or launch them.
- (NSSet *) droppableFileTypes;

//Returns an NSDragOperation indicating what the session would do with the files were they dropped.
- (NSDragOperation) responseToDraggedURLs: (NSArray *)draggedURLs;

- (NSDragOperation) responseToDraggedStrings: (NSArray *)draggedStrings;

//Handles an array of dropped file URLs.
- (BOOL) handleDraggedURLs: (NSArray *)URLs launchImmediately: (BOOL)launch;

- (BOOL) handleDraggedStrings: (NSArray *)strings;

@end
