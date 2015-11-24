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


//ADBDelegatedView is a base class for views that have a delegate.
//Currently drag-drop are passed on to the delegate, if it implements
//the appropriate methods.

#import <Cocoa/Cocoa.h>

@interface ADBDelegatedView : NSView <NSDraggingDestination>
{
    __unsafe_unretained id _delegate;
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
