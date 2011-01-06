/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXWelcomeButtonDraggingDelegate is a basic protocol to let us pass the work of handling
//welcome button drag-drop events off to an arbitrary delegate (in practice, the window controller.)
//These methods take an additional button: parameter to let the delegate know which button is
//receiving the drag operation (since the NSDraggingInfo protocol offers no way to determine this.)

@class BXWelcomeButton;

@protocol BXWelcomeButtonDraggingDelegate

- (NSDragOperation) button: (BXWelcomeButton *)button draggingEntered: (id <NSDraggingInfo>)sender;
- (void) button: (BXWelcomeButton *)button draggingExited: (id <NSDraggingInfo>)sender;
- (BOOL) button: (BXWelcomeButton *)button performDragOperation: (id <NSDraggingInfo>)sender;

@end
