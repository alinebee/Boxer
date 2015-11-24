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

#import "ADBEnumerationHelpers.h"

@implementation ADBTreeEnumerator
@synthesize levels = _levels;
@synthesize exhausted = _exhausted;
@synthesize currentNode = _currentNode;

- (id) initWithRootNodes: (NSArray *)rootNodes
{
    NSAssert(rootNodes != nil, @"No root nodes specified for this enumerator.");
    
    self = [self init];
    if (self)
    {
        _levels = [[NSMutableArray alloc] init];
        [self pushLevel: rootNodes];
    }
    return self;
}

- (NSUInteger) level
{
    return self.levels.count;
}

- (id) nextObject
{
    if (self.exhausted)
        return nil;
    
    while (YES)
    {
        NSArray *children = nil;
        
        //If the current node has enumerable children, pop those onto the stack and start traversing them now.
        //Otherwise we'll continue enumerating the current level.
        if (self.currentNode && [self shouldEnumerateChildrenOfNode: self.currentNode])
        {
            children = [self childrenForNode: self.currentNode];
            if (children.count)
            {
                [self pushLevel: children];
            }
        }
        
        //Pull out the next node from the current level.
        while ((self.currentNode = self.nextNodeInLevel) == nil)
        {
            //Once we exhaust the current level, drop back to the previous level and advance again.
            if (self.level > 0)
            {
                [self popLevel];
                continue;
            }
            //When we run out of levels, we've reached the end of the enumeration.
            else
            {
                self.exhausted = YES;
                return nil;
            }
        }
        
        if ([self shouldEnumerateNode: self.currentNode])
        {
            return self.currentNode;
        }
        
        //If we're skipping this node, continue processing until we reach a node we *do* want
        //to return. (Note that even if we decide not to enumerate a directory, we may still
        //enumerate its contents.)
        else
        {
            continue;
        }
    }
}

- (id) nextNodeInLevel
{
    NSEnumerator *levelEnumerator = self.levels.lastObject;
    return levelEnumerator.nextObject;
}

- (void) pushLevel: (NSArray *)nodesInLevel
{
    NSAssert(nodesInLevel != nil, @"No nodes provided for new level.");
    [_levels addObject: nodesInLevel.objectEnumerator];
}

- (void) popLevel
{
    //This will raise an NSRangeException error if no levels were available.
    [_levels removeLastObject];
}


#pragma mark - Subclass methods

- (NSArray *) childrenForNode: (id)node
{
    NSAssert(NO, @"Method must be implemented in subclasses.");
    return nil;
}

- (BOOL) shouldEnumerateNode: (id)node
{
    return YES;
}

- (BOOL) shouldEnumerateChildrenOfNode: (id)node
{
    return YES;
}

@end




@implementation ADBScanningEnumerator
@synthesize scanCallback = _scanCallback;
@synthesize innerEnumerator = _innerEnumerator;

- (id) nextObject
{
    id innerObject;
    while ((innerObject = self.innerEnumerator.nextObject) != nil)
    {
        BOOL stop;
        id matchedObject = self.scanCallback(innerObject, &stop);
        if (stop)
        {
            self.innerEnumerator = nil;
            self.scanCallback = nil;
        }
        
        if (matchedObject)
        {
            return matchedObject;
        }
    }
    return nil;
}

- (id) initWithEnumerator: (id <ADBStepwiseEnumeration>)enumerator
               usingBlock: (ADBScanCallback)scanCallback
{
    self = [self init];
    if (self)
    {
        self.innerEnumerator = enumerator;
        self.scanCallback = scanCallback;
    }
    return self;
}

+ (id) enumeratorWithEnumerator: (id <ADBStepwiseEnumeration>)enumerator usingBlock: (ADBScanCallback)scanCallback
{
    return [[self alloc] initWithEnumerator: enumerator usingBlock: scanCallback];
}

@end


#pragma mark - ADBEnumeratorChain

@interface ADBEnumeratorChain ()

@property (retain, nonatomic) NSMutableArray *enumerators;

@end


@implementation ADBEnumeratorChain
@synthesize enumerators = _enumerators;

+ (id) chainWithEnumerators: (NSArray *)enumerators
{
    return [[self alloc] initWithEnumerators: enumerators];
}

- (id) initWithEnumerators: (NSArray *)enumerators
{
    self = [self init];
    if (self)
    {
        self.enumerators = [NSMutableArray arrayWithCapacity: enumerators.count];
        for (id enumerator in enumerators)
        {
            [self addEnumerator: enumerator];
        }
    }
    return self;
}

- (id) nextObject
{
    while (self.enumerators.count > 0)
    {
        id innerObject = [[self.enumerators objectAtIndex: 0] nextObject];
        if (innerObject != nil)
        {
            return innerObject;
        }
        else
        {
            //Proceed to the next enumerator in the chain
            [self.enumerators removeObjectAtIndex: 0];
        }
    }
    //If we get this far, all enumerators are exhausted.
    return nil;
}

- (void) addEnumerator: (id)enumerator
{
    if ([enumerator respondsToSelector: @selector(nextObject)])
    {
        [self.enumerators addObject: enumerator];
    }
    //Special handling for NSArray, NSDictionary et. al.
    else if ([enumerator respondsToSelector: @selector(objectEnumerator)])
    {
        id proxyEnumerator = [enumerator objectEnumerator];
        
        NSAssert1([proxyEnumerator respondsToSelector: @selector(nextObject)],
                  @"%@'s objectEnumerator does not respond to nextObject.", enumerator);
        
        [self.enumerators addObject: proxyEnumerator];
    }
    else
    {
        NSAssert1(NO, @"%@ does not respond to nextObject or objectEnumerator.", enumerator);
    }
}

@end
