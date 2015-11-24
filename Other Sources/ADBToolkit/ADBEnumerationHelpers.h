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

//ADBEnumerationHelpers defines a set of enumeration classes for a variety
//of general applications.

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

#pragma mark - Protocols

/// Represents the interface of NSEnumerator as a protocol, for enumeration classes
/// that don't want to descend directly from NSEnumerator.
@protocol ADBStepwiseEnumeration <NSFastEnumeration>

- (NSArray *) allObjects;
- (nullable id) nextObject;

@end

//Declare that NSEnumerator already conforms to the ADBStepwiseEnumeration protocol.
@interface NSEnumerator (ADBScanningExtensions) <ADBStepwiseEnumeration>
@end


#pragma mark - ADBTreeEnumerator

/// ADBTreeEnumerator provides an abstract implementation of an enumerator for depth-first
/// iteration of nested arrays of nodes. It must be subclassed with concrete implementations
/// for node retrieval.
///
/// Subclasses must implement <code>childrenForNode:</code> but all other methods are optional.
@interface ADBTreeEnumerator : NSEnumerator
{
    NSMutableArray *_levels;
    id _currentNode;
    BOOL _exhausted;
}

/// An array of enumerators for each level of the tree being traversed.
@property (readonly, nonatomic) NSArray *levels;

/// The latest object returned by the enumeration.
@property (retain, nonatomic) id currentNode;

/// Set to \c YES when the enumeration has run out of objects, or should otherwise stop
/// iterating for any reason (for instance, encountering an error).
@property (assign, nonatomic, getter=isExhausted) BOOL exhausted;

/// Returns a new enumerator with the specified nodes as the root level. Enumeration
/// will proceed depth-first starting from the first of these nodes. If the array
/// is empty, the enumerator will return nothing.
- (instancetype) initWithRootNodes: (NSArray *)rootNodes;

/// Advances enumeration of the current level and returns the next available node.
/// Returns \c nil once it reaches the end of the current level.
/// Called by nextObject.
- (nullable id) nextNodeInLevel;

//Adds the specified nodes as a new level onto the level stack.
//Called by nextObject when traversing a node with children.
- (void) pushLevel: (NSArray *)nodesInLevel;

//Removes the last level from the stack, returning iteration to the previous level.
//Raises an NSRangeException if the enumerator is at the root level.
//Called by nextObject once the current level is exhausted.
- (void) popLevel;

//The current level of depth into the tree. The root nodes are at level 1.
- (NSUInteger) level;


#pragma mark Methods to implement in subclasses

/// Returns whether the specified node should be returned by nextObject or should be skipped.
/// This check applies just to that node and not to its children.
- (BOOL) shouldEnumerateNode: (id)node;

/// Returns whether enumeration should continue into the specified node's children.
/// This check will be made (and if successful, child nodes enumerated) even if
/// \c shouldEnumerateNode: previously returned \c NO for the parent.
- (BOOL) shouldEnumerateChildrenOfNode: (id)node;

/// Returns the children of the specified node. Return nil if the node is a leaf node.
- (nullable NSArray *) childrenForNode: (id)node;

@end


#pragma mark - ADBScanningEnumerator

/// Used by ADBScanningEnumerator's nextObject method to scan forward through each object
/// of its inner enumerator. If this block returns an object, enumeration will pause and
/// <code>ADBScanningEnumerator -nextObject</code> will return that object; if this block returns <code>nil</code>,
/// enumeration of the inner enumerator will continue.
/// \c scannedObject is the next object from the inner enumerator; stop is a boolean reference
/// which, if set to YES, will halt enumeration after the current object.
typedef id __nullable (^ADBScanCallback)(id scannedObject, BOOL *stop);


//An enumerator that scans forwards through an inner enumerator,
//passing each enumerated object to an ADBScanCallback block and returning
//an object only when the block itself produces an object. This is intended
//as a generic way to provide 'pre-filtered' enumerator objects without
//the need for NSEnumerator subclasses.
@interface ADBScanningEnumerator : NSEnumerator
{
    id <ADBStepwiseEnumeration> _innerEnumerator;
    ADBScanCallback _scanCallback;
}
@property (retain, nonatomic, nullable) id <ADBStepwiseEnumeration> innerEnumerator;
@property (copy, nonatomic, nullable) ADBScanCallback scanCallback;

+ (instancetype) enumeratorWithEnumerator: (id <ADBStepwiseEnumeration>)enumerator usingBlock: (ADBScanCallback)scanCallback;
- (instancetype) initWithEnumerator: (id <ADBStepwiseEnumeration>)enumerator usingBlock: (ADBScanCallback)scanCallback;

@end


#pragma mark - ADBEnumeratorChain

//An enumerator that chains several enumerators together, moving on to the next one once one is exhausted.
//This retains the enumerators and releases each one as it is exhausted.
//This can chain objects that conform to the ADBStepwiseEnumeration protocol themselves, or that respond
//to an objectEnumerator message.

@interface ADBEnumeratorChain : NSEnumerator
{
    NSMutableArray *_enumerators;
}

///Returns a chain of the specified enumerators.
+ (instancetype) chainWithEnumerators: (NSArray *)enumerators;
- (instancetype) initWithEnumerators: (NSArray *)enumerators;

///Adds another enumerator onto the end of the chain. This will raise an assertion if the specified object
///neither conforms to the \c ADBStepwiseEnumeration protocol nor responds to an \c objectEnumerator message.
- (void) addEnumerator: (id)enumerator;

@end

NS_ASSUME_NONNULL_END
