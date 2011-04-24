/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDelegatedView.h"


@implementation BXDelegatedView
@synthesize delegate;

#pragma mark -
#pragma mark Supporting drag-drop

- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>)sender
{
	draggingEnteredResponse = NSDragOperationNone;
	if ([[self delegate] respondsToSelector: @selector(draggingEntered:)])
		draggingEnteredResponse = [[self delegate] draggingEntered: sender];
	
	return draggingEnteredResponse;
}

- (BOOL) wantsPeriodicDraggingUpdates
{
	if ([[self delegate] respondsToSelector: @selector(wantsPeriodicDraggingUpdates)])
		return [[self delegate] wantsPeriodicDraggingUpdates];
	else return YES;
}

- (NSDragOperation) draggingUpdated: (id <NSDraggingInfo>)sender
{
	if ([[self delegate] respondsToSelector: @selector(draggingUpdated:)])
		return [[self delegate] draggingUpdated: sender];
	else return draggingEnteredResponse;
}

- (void) draggingExited: (id <NSDraggingInfo>)sender
{
	if ([[self delegate] respondsToSelector: @selector(draggingExited:)])
		[[self delegate] draggingExited: sender];
}

- (void) draggingEnded: (id <NSDraggingInfo>)sender
{
	if ([[self delegate] respondsToSelector: @selector(draggingEnded:)])
		[[self delegate] draggingEnded: sender];	
}



- (BOOL) prepareForDragOperation: (id <NSDraggingInfo>)sender
{
	if ([[self delegate] respondsToSelector: @selector(prepareForDragOperation:)])
		return [[self delegate] prepareForDragOperation: sender];
	else return YES;	
}

- (BOOL) performDragOperation: (id <NSDraggingInfo>)sender
{
	if ([[self delegate] respondsToSelector: @selector(performDragOperation:)])
		return [[self delegate] performDragOperation: sender];
	else return NO;
}

- (void) concludeDragOperation: (id <NSDraggingInfo>)sender
{
	if ([[self delegate] respondsToSelector: @selector(concludeDragOperation:)])
		[[self delegate] concludeDragOperation: sender];	
}
@end
