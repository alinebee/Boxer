/*
 *  Copyright (c) 2013, Alun Bestor (alun.bestor@gmail.com)
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *		Redistributions of source code must retain the above copyright notice, this
 *	    list of conditions and the following disclaimer.
 *
 *		Redistributions in binary form must reproduce the above copyright notice,
 *	    this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 *	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 */


#import "ADBDelegatedView.h"


@implementation ADBDelegatedView
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
