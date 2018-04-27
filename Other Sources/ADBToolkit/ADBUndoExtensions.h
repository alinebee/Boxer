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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ADBUndoable;
/// @c ADBUndoDelegate declares a means for a controller to provide a model object with the undo manager
/// it should use for an undoable operation. This obviates the need for every model object to store
/// its own reference to an undo manager.
@protocol ADBUndoDelegate <NSObject>

/// Returns the undo manager that the object should use for undoing the specified operation on itself.
/// Return @c nil instead to prevent undo for this operation.
- (nullable NSUndoManager *) undoManagerForClient: (id <ADBUndoable>)undoClient operation: (SEL)operation;

/// Removes the undo/redo actions for the specified client.
/// Usually called when the delegate is being deallocated.
- (void) removeAllUndoActionsForClient: (id <ADBUndoable>)undoClient;

@end


@protocol ADBUndoable <NSObject>

/// Set/retrieve the delegate that will provide this object with an undo manager.
/// The receiver should not retain the delegate.
@property (readwrite, assign, nullable) id <ADBUndoDelegate> undoDelegate;

@end

NS_ASSUME_NONNULL_END
