/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXDragDrop category extends BXSession with methods for responding to drag-drop events
//into the session's main window.

#import <Cocoa/Cocoa.h>
#import "BXSession.h"

@interface BXSession (BXDragDrop)

//UTI filetypes that may be dropped onto a session to mount or launch them.
+ (NSArray *) droppableFileTypes;

//Returns an NSDragOperation indicating what the session would do with the files were they dropped.
- (NSDragOperation) responseToDroppedFiles: (NSArray *)filePaths;

//Handles an array of dropped files.
- (BOOL) handleDroppedFiles: (NSArray *)filePaths withLaunching: (BOOL)launch;

@end


//The methods in this category are not intended to be called outside of BXSession
@interface BXSession (BXDragDropInternals)

- (NSDragOperation) _responseToDroppedFile: (NSString *)filePath;
- (BOOL) _handleDroppedFile: (NSString *)filePath withLaunching: (BOOL)launch;

@end