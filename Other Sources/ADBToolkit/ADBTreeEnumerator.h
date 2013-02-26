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

//ADBTreeEnumerator provides an abstract implementation of an enumerator for depth-first
//iteration of nested arrays of nodes stemming from a single root node (which is not
//included in the enumeration.)


#import <Foundation/Foundation.h>

@interface ADBTreeEnumerator : NSEnumerator
{
    NSMutableArray *_levels;
    NSUInteger *_indices;
    NSUInteger _maxLevels;
    BOOL _exhausted;
}

@property (readonly, nonatomic) NSArray *levels;
@property (assign, nonatomic, getter=isExhausted) BOOL exhausted;

//Returns a new enumerator to accommodate the specified number of nested levels,
//with the specified node at its root. This is the designated initializer.
//(Capacity is not a hard limit - the enumerator will be expanded if it goes beyond this.)
- (id) initWithRootNode: (id)rootNode capacity: (NSUInteger)capacity;

//The node at the current index, i.e. the node that was most recently enumerated
//by nextObject. Returns nil once the enumerator is exhausted.
- (id) currentNode;

//Returns the nodes along the current path ordered from root to current.
- (NSArray *) nodesAlongPath;

//Advances the index of the current level and returns the node at that index.
//If this reaches the end, it will pop the current level and return the next
//node in the level before it instead. Returns nil once the enumerator is exhausted.
- (id) nextNodeInLevel;

//Adds the specified nodes onto the level stack, making it the new current level.
//The index for that level will be set to the specified index.
- (void) pushLevel: (NSArray *)nodesInLevel initialIndex: (NSUInteger)startingIndex;

//Removes the last level from the stack, returning iteration to the previous level.
//Raises an exception if an attempt is made to pop the root node.
- (void) popLevel;

//The current level of the enumerator, where 0 is the root node.
//Returns NSNotFound if there is no root node.
- (NSUInteger) level;


#pragma mark - Methods to implement in subclasses

//Provides the value that nextObject should return for the given node.
- (id) enumerationValueForNode: (id)node;

//Returns whether the specified node should be returned by nextObject or should be skipped.
//This check applies just to that node and not to its children.
- (BOOL) shouldEnumerateNode: (id)node;

//Returns whether enumeration should continue into the specified node's children.
//This check will be made (and if successful, child nodes enumerated) even if
//shouldEnumerateNode: previously returned NO for the parent.
- (BOOL) shouldEnumerateChildrenOfNode: (id)node;

//Returns the children of the specified node. Return nil if the node is a leaf node.
- (NSArray *) childrenForNode: (id)node;

@end
