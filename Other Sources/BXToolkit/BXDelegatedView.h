/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXDelegatedView is a base class for views that have a delegate. Drag-drop and resize events
//are passed on to the delegate, if it implements the appropriate methods.

#import <Cocoa/Cocoa.h>

@interface BXDelegatedView : NSView
{
	id delegate;
	NSDragOperation draggingEnteredResponse;
}
@property (assign) id delegate;

#pragma mark -
#pragma mark Drag-drop handling

- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>)sender;
- (BOOL) wantsPeriodicDraggingUpdates;
- (NSDragOperation) draggingUpdated: (id <NSDraggingInfo>)sender;
- (void) draggingExited: (id <NSDraggingInfo>)sender;
- (void) draggingEnded: (id <NSDraggingInfo>)sender;

- (BOOL) prepareForDragOperation: (id <NSDraggingInfo>)sender;
- (BOOL) performDragOperation: (id <NSDraggingInfo>)sender;
- (void) concludeDragOperation: (id <NSDraggingInfo>)sender;

@end
