/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXDragDrop category extends BXSession with methods for responding to drag-drop events
//into the session's main window.

#import "BXSession.h"

@interface BXSession (BXDragDrop)

//UTI filetypes that may be dropped onto this session to mount or launch them.
- (NSSet *) droppableFileTypes;

//Returns an NSDragOperation indicating what the session would do with the files were they dropped.
- (NSDragOperation) responseToDroppedFiles: (NSArray *)filePaths;

- (NSDragOperation) responseToDroppedString: (NSString *)droppedString;

//Handles an array of dropped files.
- (BOOL) handleDroppedFiles: (NSArray *)filePaths withLaunching: (BOOL)launch;

- (BOOL) handleDroppedString: (NSString *)droppedString;

@end
