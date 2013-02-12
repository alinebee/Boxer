/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDelegatedView.h"


@implementation BXDelegatedView
@synthesize delegate = _delegate;

#pragma mark -
#pragma mark Delegating drag-drop

- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>)sender
{
	_draggingEnteredResponse = NSDragOperationNone;
	if ([self.delegate respondsToSelector: _cmd])
		_draggingEnteredResponse = [self.delegate draggingEntered: sender];
	
	return _draggingEnteredResponse;
}

- (BOOL) wantsPeriodicDraggingUpdates
{
	if ([self.delegate respondsToSelector: _cmd])
		return [self.delegate wantsPeriodicDraggingUpdates];
	else return YES;
}

- (NSDragOperation) draggingUpdated: (id <NSDraggingInfo>)sender
{
	if ([self.delegate respondsToSelector: _cmd])
		return [self.delegate draggingUpdated: sender];
	else return _draggingEnteredResponse;
}

- (void) draggingExited: (id <NSDraggingInfo>)sender
{
	if ([self.delegate respondsToSelector: _cmd])
		[self.delegate draggingExited: sender];
}

- (void) draggingEnded: (id <NSDraggingInfo>)sender
{
	if ([self.delegate respondsToSelector: _cmd])
		[self.delegate draggingEnded: sender];
}



- (BOOL) prepareForDragOperation: (id <NSDraggingInfo>)sender
{
	if ([self.delegate respondsToSelector: _cmd])
		return [self.delegate prepareForDragOperation: sender];
	else return YES;	
}

- (BOOL) performDragOperation: (id <NSDraggingInfo>)sender
{
	if ([self.delegate respondsToSelector: _cmd])
		return [self.delegate performDragOperation: sender];
	else return NO;
}

- (void) concludeDragOperation: (id <NSDraggingInfo>)sender
{
	if ([self.delegate respondsToSelector: _cmd])
		[self.delegate concludeDragOperation: sender];
}

@end
