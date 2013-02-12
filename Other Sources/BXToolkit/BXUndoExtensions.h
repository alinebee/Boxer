/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Cocoa/Cocoa.h>

//BXUndoDelegate declares a means for a controller to provide a model object with the undo manager
//it should use for an undoable operation. This obviates the need for every model object to store
//its own reference to an undo manager.

@protocol BXUndoable;
@protocol BXUndoDelegate <NSObject>

//Returns the undo manager that the object should use for undoing the specified operation on itself.
//Return nil instead to prevent undo for this operation.
- (NSUndoManager *) undoManagerForClient: (id <BXUndoable>)undoClient operation: (SEL)operation;

//Removes the undo/redo actions for the specified client.
//Usually called when the delegate is being deallocated.
- (void) removeAllUndoActionsForClient: (id <BXUndoable>)undoClient;

@end


@protocol BXUndoable <NSObject>

//Set/retrieve the delegate that will provide this object with an undo manager.
//The receiver should not retain the delegate.
- (void) setUndoDelegate: (id <BXUndoDelegate>)delegate;
- (id <BXUndoDelegate>) undoDelegate;

@end
