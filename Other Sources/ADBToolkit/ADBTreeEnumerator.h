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
//iteration of nested arrays of nodes. It is designed to be subclassed with concrete
//implementations for node retrieval.

//Subclasses must implement childrenForNode: but all other methods are optional.


#import <Foundation/Foundation.h>

@interface ADBTreeEnumerator : NSEnumerator
{
    NSMutableArray *_levels;
    id _currentNode;
    BOOL _exhausted;
}

@property (readonly, nonatomic) NSArray *levels;

//The latest object returned by the enumeration.
@property (retain, nonatomic) id currentNode;

@property (assign, nonatomic, getter=isExhausted) BOOL exhausted;

//Returns a new enumerator with the specified node(s) at the root level. Enumeration
//will proceed depth-first starting from the first of these nodes.
- (id) initWithRootNodes: (NSArray *)rootNodes;

//Advances enumeration of the current level and returns the next available node.
//Returns nil once it reaches the end of the current level.
//Called by nextObject.
- (id) nextNodeInLevel;

//Adds the specified nodes onto the level stack.
//Called by nextObject when traversing a node with children.
- (void) pushLevel: (NSArray *)nodesInLevel;

//Removes the last level from the stack, returning iteration to the previous level.
//Raises an NSRangeException if the enumerator is at the root level.
//Called by nextObject once the current level is exhausted.
- (void) popLevel;

//The current level of depth into the tree. The root nodes are at level 1.
- (NSUInteger) level;


#pragma mark - Methods to implement in subclasses

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
