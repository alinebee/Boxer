/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXDelegatedView is a base class for views that have a delegate.
//Currently drag-drop are passed on to the delegate, if it implements
//the appropriate methods.

#import <Cocoa/Cocoa.h>

@interface BXDelegatedView : NSView
{
    id _delegate;
	NSDragOperation _draggingEnteredResponse;
}
@property (assign) IBOutlet id delegate;

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
